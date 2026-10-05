// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
import 'sync_last_sync_for_creator.dart';

// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_config.dart';

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';
import '/backend/sqlite/situacao_soft_delete.dart';
import '/auth/membership_access.dart';
import 'download_obra_foto_local.dart';
import 'sync_uuid_upsert.dart';

/// Preferência legada (one-shot). Recovery contínuo = full resync diário.
const String _kObrasFullResyncV2 = 'obras_full_resync_v2';
const String _kDailyScope = 'obras';

// ===== FUNÇÕES UTILITÁRIAS (já existentes - copie da action anterior) =====

Future<void> _salvarMapeamento(
    String tabela, int idServidor, String uuid) async {
  final db = await SQLiteManager.instance.database;
  try {
    await db.insert('sync_id_mapping', {
      'tabela': tabela,
      'id_servidor': idServidor,
      'uuid': uuid,
      'created_at': DateTime.now().toIso8601String(),
    });

    print('mapeamento salvo');
  } catch (e) {
    if (!e.toString().contains('UNIQUE constraint')) {
      print('❌ Erro ao salvar mapeamento: $e');
    }
  }
}

Future<int?> _getIdLocalPorIdServidor(String tabela, int idServidor) async {
  final db = await SQLiteManager.instance.database;
  try {
    final mapeamento = await db.query(
      'sync_id_mapping',
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: [tabela, idServidor],
    );
    if (mapeamento.isEmpty) return null;
    final uuid = mapeamento.first['uuid'] as String;
    final registro =
        await db.query(tabela, where: 'uuid = ?', whereArgs: [uuid]);
    return registro.isNotEmpty ? registro.first['id'] as int : null;
  } catch (e) {
    print('❌ Erro ao buscar mapeamento: $e');
    return null;
  }
}

Future<int?> _getIdLocalPorUuid(String tabela, String uuid) async {
  final db = await SQLiteManager.instance.database;
  final registro = await db.query(tabela, where: 'uuid = ?', whereArgs: [uuid]);
  return registro.isNotEmpty ? registro.first['id'] as int : null;
}

Future<String> _getUltimaSync(String tabela) async {
  return lastSyncDateForCurrentCreator(tabela);
}

String _generateUuid() {
  final random = Random();
  final hexDigits = '0123456789abcdef';
  String generatePart(int length) {
    return List.generate(length, (index) => hexDigits[random.nextInt(16)])
        .join();
  }

  return '${generatePart(8)}-${generatePart(4)}-4${generatePart(3)}-${generatePart(4)}-${generatePart(12)}';
}

String _nonEmptyStr(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  return s;
}

/// SQLite `created_by` TEXT: prefere UUID do criador vindo da API.
String _createdByLocal(Map<String, dynamic> obraServer) {
  final u = obraServer['created_by_uuid'];
  if (u != null && u.toString().isNotEmpty) return u.toString();
  final legacy = obraServer['created_by'];
  if (legacy == null) return '';
  return legacy.toString();
}

int? _serverId(Map<String, dynamic> row) {
  final v = row['id'];
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

int _parseSituacao(dynamic v) {
  if (v == null) return kSituacaoAtivo;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? kSituacaoAtivo;
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncObras() async {
  try {
    final db = await SQLiteManager.instance.database;
    final token = await _getAuthToken();

    if (token.isEmpty) {
      _updateSyncStatus(false, 'Usuário não autenticado', 0, 0);
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    int uploadedCount = 0;
    int downloadedCount = 0;

    // ===== 1. UPLOAD - Enviar dados locais =====
    try {
      final obrasNaoSincronizadas = await db.query(
        'obras',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (obrasNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA OBRAS SEM UUID
        for (var obra in obrasNaoSincronizadas) {
          if (obra['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'obras',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [obra['id']],
            );
            print('✅ Gerado UUID para obra: ${obra['nome']} -> $newUuid');
          }
        }

        // BUSCAR OBRAS ATUALIZADAS
        final obrasComUuid = await db.query(
          'obras',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final obrasParaEnviar = obrasComUuid.map((obra) {
          return {
            'uuid': obra['uuid'],
            'uuid_pai': obra['uuid_pai'],
            'user_id': obra['user_id'],
            'user_uuid': obra['user_uuid'],
            'cliente_id': obra['cliente_id'],
            'cliente_uuid': obra['cliente_uuid'],
            'grupo_id': obra['grupo_id'],
            'grupo_uuid': obra['grupo_uuid'],
            'nome': obra['nome'],
            'rua': obra['rua'],
            'numero': obra['numero'],
            'complemento': obra['complemento'],
            'bairro': obra['bairro'],
            'cidade': obra['cidade'],
            'estado': obra['estado'],
            'engenheiro': obra['engenheiro'],
            'data_inicio': obra['data_inicio'],
            'data_final': obra['data_final'],
            'contrato': obra['contrato'],
            'foto': obra['foto'],
            'created_by': obra['created_by'],
            'situacao_id': obra['situacao_id'],
            'situacao': _parseSituacao(obra['situacao']),
            'created_at': obra['created_at'],
            'updated_at': obra['updated_at'],
          };
        }).toList();

        print('📤 Enviando ${obrasParaEnviar.length} obras...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse('$kApiBaseUrl/api/v1/sync/obras/upload'),
          headers: headers,
          body: json.encode({'dados': obrasParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          // MARCAR OBRAS COMO SINCRONIZADAS
          for (var obra in uploadResult['sincronizados']) {
            await db.update(
              'obras',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [obra['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount obras');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var obra in obrasComUuid) {
            final currentCount = obra['sync_try_count'] as int? ?? 0;
            await db.update(
              'obras',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [obra['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhuma obra para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      // Full sync: uma vez (watermark antigo) OU se obra_travada e faltam obras.
      final prefs = await SharedPreferences.getInstance();
      final alreadyRepaired = prefs.getBool(_kObrasFullResyncV2) ?? false;
      final needsDaily = await shouldForceDailyFullResync(_kDailyScope);
      var forceFull = !alreadyRepaired || needsDaily;
      if (MembershipAccess.obraTravada) {
        final allowed = FFAppState().allowedObraIds;
        if (allowed.isNotEmpty) {
          for (final sid in allowed) {
            final maps = await db.query(
              'sync_id_mapping',
              columns: ['uuid'],
              where: 'tabela = ? AND id_servidor = ?',
              whereArgs: ['obras', sid],
              limit: 1,
            );
            if (maps.isEmpty) {
              forceFull = true;
              break;
            }
            final uuid = (maps.first['uuid']?.toString() ?? '').trim();
            if (uuid.isEmpty) {
              forceFull = true;
              break;
            }
            final local = await db.query(
              'obras',
              columns: ['id'],
              where: 'uuid = ?',
              whereArgs: [uuid],
              limit: 1,
            );
            if (local.isEmpty) {
              forceFull = true;
              break;
            }
          }
        }
      }
      final lastSync = forceFull
          ? kSyncEpoch
          : await _getUltimaSync('obras');
      print(
          '📥 Buscando obras desde: $lastSync${forceFull ? ' (resync completo)' : ''}');

      final downloadResponse = await http.post(
        Uri.parse('$kApiBaseUrl/api/v1/sync/obras/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final obrasDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${obrasDoServidor.length} obras');

        for (var obraServer in obrasDoServidor) {
          await _processarObra(obraServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (obrasDoServidor.isNotEmpty) {
          await db.update(
            'obras',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        if (forceFull) {
          await prefs.setBool(_kObrasFullResyncV2, true);
          await markDailyFullResyncDone(_kDailyScope);
        }
        print('✅ Download concluído: $downloadedCount obras');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync obras concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync obras concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync obras: $e');
    _updateSyncStatus(false, 'Erro geral sync obras: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE OBRA =====

Future<void> _processarObra(
    Map<String, dynamic> obraServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuid = normalizeSyncUuid(obraServer['uuid']);
  if (uuid == null) {
    print('⚠️ download skip: uuid ausente');
    return;
  }

  final sid = _serverId(obraServer);
  if (sid != null) {
    await _salvarMapeamento('obras', sid, uuid);
  }

  final userUuid = _nonEmptyStr(obraServer['user_uuid']);
  final clienteUuid = _nonEmptyStr(obraServer['cliente_uuid']);
  final grupoUuid = _nonEmptyStr(obraServer['grupo_uuid']);

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'obras',
    where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
    whereArgs: [uuid],
  );

  final fotoLocalAtual = existe.isNotEmpty
      ? existe.first['foto_local']?.toString()
      : null;

  final rowComum = <String, dynamic>{
    'uuid_pai': obraServer['uuid_pai'],
    'user_id': obraServer['user_id'],
    'user_uuid': userUuid,
    'cliente_id': obraServer['cliente_id'],
    'cliente_uuid': clienteUuid,
    'grupo_id': obraServer['grupo_id'] ?? 0,
    'grupo_uuid': grupoUuid,
    'nome': obraServer['nome'],
    'rua': obraServer['rua'],
    'numero': obraServer['numero'],
    'complemento': obraServer['complemento'],
    'bairro': obraServer['bairro'],
    'cidade': obraServer['cidade'],
    'estado': obraServer['estado'],
    'engenheiro': obraServer['engenheiro'],
    'data_inicio': obraServer['data_inicio'],
    'data_final': obraServer['data_final'],
    'contrato': obraServer['contrato'],
    // Path relativo do S3 — não sobrescrever com caminho local.
    'foto': obraServer['foto'],
    'created_by': _createdByLocal(obraServer),
    'situacao_id': obraServer['situacao_id'],
    'situacao': _parseSituacao(obraServer['situacao']),
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': obraServer['created_at'],
    'updated_at': obraServer['updated_at'],
  };

  if (existe.isNotEmpty) {
    await db.update(
      'obras',
      rowComum,
      where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
      whereArgs: [uuid],
    );
  } else {
    try {
      await db.insert(
        'obras',
        {
          'uuid': uuid,
          ...rowComum,
        },
      );
    } catch (_) {
      // UNIQUE uuid: outra linha já existe (race) — atualiza.
      await db.update(
        'obras',
        rowComum,
        where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
        whereArgs: [uuid],
      );
    }
  }

  // Baixa o arquivo da foto para uso offline (foto_local).
  await downloadObraFotoLocal(
    obraUuid: uuid,
    fotoServidor: obraServer['foto']?.toString(),
    fotoUrl: obraServer['foto_url']?.toString(),
    fotoLocalAtual: fotoLocalAtual,
  );
}

// ===== FUNÇÕES RESTANTES =====

void _updateSyncStatus(
    bool success, String message, int uploaded, int downloaded) {
  try {
    FFAppState().update(() {
      FFAppState().syncSuccess = success;
      FFAppState().syncMessage = message;
      FFAppState().syncUploadedCount = uploaded;
      FFAppState().syncDownloadedCount = downloaded;
      FFAppState().lastSyncTime = DateTime.now().toIso8601String();
    });
  } catch (e) {
    print('❌ Erro ao atualizar AppState: $e');
  }
}

Future<String> _getAuthToken() async {
  try {
    return FFAppState().UserToken ?? '';
  } catch (e) {
    return '';
  }
}

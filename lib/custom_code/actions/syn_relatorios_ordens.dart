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
import 'dart:convert';
import 'dart:math';

import 'sync_relatorio_download_merge_guard.dart';
import 'sync_uuid_upsert.dart';

const String _kUrlUploadRelatorioOrdens =
    '$kApiBaseUrl/api/v1/sync/relatorios/ordens/upload';
const String _kUrlDownloadRelatorioOrdens =
    '$kApiBaseUrl/api/v1/sync/relatorios/ordens/download';

Uri _uriRelatorioOrdensUpload() =>
    Uri.parse(_kUrlUploadRelatorioOrdens.trim());

Uri _uriRelatorioOrdensDownload() =>
    Uri.parse(_kUrlDownloadRelatorioOrdens.trim());

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

String? _nonEmptyStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _createdByLocal(Map<String, dynamic> row) {
  // No SQLite (`nova.sql`), `created_by` é TEXT (uuid).
  return _nonEmptyStr(row['created_by_uuid']) ??
      _nonEmptyStr(row['created_by']) ??
      '';
}

// ===== FUNÇÃO PRINCIPAL =====

Future synRelatoriosOrdens() async {
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
    bool hadError = false;

    // ===== 1. UPLOAD — só [relatorio_ordem_servico]: created_by = tenant, sem JOIN =====
    try {
      await stampPendingRelatorioOrdemServicoCreatedByTenantFallback(db);

      var relatorioOrdensNaoSincronizadas =
          await pendingRelatorioOrdemServicoForTenantSimple(db);

      if (relatorioOrdensNaoSincronizadas.isNotEmpty) {
        for (final relatorioOrdem in relatorioOrdensNaoSincronizadas) {
          if (relatorioOrdem['uuid'] == null ||
              (relatorioOrdem['uuid'] as String?)?.trim().isEmpty == true) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_ordem_servico',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorioOrdem['id']],
            );
            print(
                '✅ Gerado UUID para relatorio ordem: ${relatorioOrdem['id']} -> $newUuid');
          }
        }

        final relatorioOrdensComUuid =
            await pendingRelatorioOrdemServicoForTenantSimple(db);

        final relatorioOrdensParaEnviar = <Map<String, dynamic>>[];
        for (final rowRos in relatorioOrdensComUuid) {
          final linha = Map<String, dynamic>.from(rowRos);
          await backfillRelatorioUuidForPayloadRow(db, linha);
          relatorioOrdensParaEnviar.add({
            'uuid': linha['uuid'],
            'relatorio_id': linha['relatorio_id'],
            'relatorio_uuid': linha['relatorio_uuid'],
            'ordem_servico_id': linha['ordem_servico_id'],
            'ordem_servico_uuid': linha['ordem_servico_uuid'],
            'observacao': linha['observacao'],
            'created_by_uuid': linha['created_by'],
            'created_at': linha['created_at'],
            'updated_at': linha['updated_at'],
          });
        }

        print(
            '📤 Enviando ${relatorioOrdensParaEnviar.length} relatorios ordens...');
        print('📤 POST ${_uriRelatorioOrdensUpload()}');

        final uploadResponse = await http.post(
          _uriRelatorioOrdensUpload(),
          headers: headers,
          body: json.encode({'dados': relatorioOrdensParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadBody =
              mapaRespostaSyncJson(json.decode(uploadResponse.body));
          final stUpload = serverTimeDoJsonResposta(uploadBody);

          for (final rowSrv in servidorVenceuLwwDoJson(uploadBody)) {
            await _processarOrdemTarefa(rowSrv, stUpload,
                prioridadeServidor: true);
          }

          // MARCAR RELATORIOS TAREFAS COMO SINCRONIZADAS
          final sinc = uploadBody['sincronizados'];
          for (var relatorioOrdem in (sinc is List ? sinc : const [])) {
            if (relatorioOrdem is! Map) continue;
            final u = relatorioOrdem['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_ordem_servico',
              {
                'synced': 1,
                'last_sync_date': stUpload,
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [u],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount relatorios ordens');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioOrdem in relatorioOrdensComUuid) {
            final currentCount = relatorioOrdem['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_ordem_servico',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioOrdem['uuid']],
            );
          }
          print(
              '❌ Erro no upload: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhuma relatorio ordem para enviar');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_ordem_servico');
      print('📥 Buscando relatorios ordens desde: $lastSync');
      print('📥 POST ${_uriRelatorioOrdensDownload()}');

      final downloadResponse = await http.post(
        _uriRelatorioOrdensDownload(),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatorioOrdensDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${relatorioOrdensDoServidor.length} ordens');

        for (var relatorioOrdemServer in relatorioOrdensDoServidor) {
          if (relatorioOrdemServer is! Map) continue;
          await _processarOrdemTarefa(
            Map<String, dynamic>.from(relatorioOrdemServer),
            downloadResult['server_time']?.toString() ??
                DateTime.now().toIso8601String(),
          );
          downloadedCount++;
        }

        if (relatorioOrdensDoServidor.isNotEmpty) {
          await updateLastSyncRelatorioOrdemServicoSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print('✅ Download concluído: $downloadedCount relatorios ordens');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print(
            '❌ Erro no download: ${downloadResponse.statusCode} — ${downloadResponse.body}');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no download: $e');
    }

    if (hadError) {
      throw Exception('Falha parcial no sync de relatorio_ordem_servico');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync ordens concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios ordens concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios  ordens: $e');
    _updateSyncStatus(false, 'Erro geral sync relatorios ordens: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioOrdemServer, String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  final uuid = normalizeSyncUuid(relatorioOrdemServer['uuid']);
  if (uuid == null) {
    print('⚠️ download skip: uuid ausente');
    return;
  }

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioOrdemServer['id'] != null) {
    await _salvarMapeamento(
        'relatorio_ordem_servico', relatorioOrdemServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorio_ordem_servico',
    where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: relatorioOrdemServer,
          tabela: 'relatorio_ordem_servico',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    // UPDATE
    await db.update(
      'relatorio_ordem_servico',
      {
        'relatorio_id': relatorioOrdemServer['relatorio_id'],
        'relatorio_uuid': _nonEmptyStr(relatorioOrdemServer['relatorio_uuid']),
        'ordem_servico_id': relatorioOrdemServer['ordem_servico_id'],
        'ordem_servico_uuid':
            _nonEmptyStr(relatorioOrdemServer['ordem_servico_uuid']),
        'observacao': relatorioOrdemServer['observacao'],
        'created_by': _createdByLocal(relatorioOrdemServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': relatorioOrdemServer['created_at'],
        'updated_at': relatorioOrdemServer['updated_at']
      },
      where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert('relatorio_ordem_servico', {
      'uuid': uuid,
      'relatorio_id': relatorioOrdemServer['relatorio_id'],
      'relatorio_uuid': _nonEmptyStr(relatorioOrdemServer['relatorio_uuid']),
      'ordem_servico_id': relatorioOrdemServer['ordem_servico_id'],
      'ordem_servico_uuid':
          _nonEmptyStr(relatorioOrdemServer['ordem_servico_uuid']),
      'observacao': relatorioOrdemServer['observacao'],
      'created_by': _createdByLocal(relatorioOrdemServer),
      'synced': 1,
      'last_sync_date': serverTime,
      'created_at': relatorioOrdemServer['created_at'],
      'updated_at': relatorioOrdemServer['updated_at']
    });
  }
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

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

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'sync_uuid_upsert.dart';

// ===== FUNÇÕES UTILITÁRIAS =====

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
  } catch (e) {
    if (!e.toString().contains('UNIQUE constraint')) {
      print('❌ Erro ao salvar mapeamento: $e');
    }
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

Future<int?> _idServidorPorUuid(String tabela, String? uuid) async {
  final u = (uuid ?? '').trim();
  if (u.isEmpty) return null;
  final db = await SQLiteManager.instance.database;
  final rows = await db.query(
    'sync_id_mapping',
    columns: ['id_servidor'],
    where: 'tabela = ? AND uuid = ?',
    whereArgs: [tabela, u],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return _asInt(rows.first['id_servidor']);
}

Future<int?> _idLocalPorIdServidor(String tabela, int idServidor) async {
  final db = await SQLiteManager.instance.database;
  final mapeamento = await db.query(
    'sync_id_mapping',
    where: 'tabela = ? AND id_servidor = ?',
    whereArgs: [tabela, idServidor],
    limit: 1,
  );
  if (mapeamento.isEmpty) return null;
  final uuid = (mapeamento.first['uuid'] ?? '').toString();
  if (uuid.isEmpty) return null;
  final registro =
      await db.query(tabela, where: 'uuid = ?', whereArgs: [uuid], limit: 1);
  return registro.isNotEmpty ? _asInt(registro.first['id']) : null;
}

Future<String?> _uuidPorIdLocal(String tabela, int? localId) async {
  if (localId == null || localId < 1) return null;
  final db = await SQLiteManager.instance.database;
  final rows = await db.query(
    tabela,
    columns: ['uuid'],
    where: 'id = ?',
    whereArgs: [localId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  final u = (rows.first['uuid'] ?? '').toString().trim();
  return u.isEmpty ? null : u;
}

/// Resolve o PK do servidor a partir de uuid e/ou id local SQLite.
Future<int?> _resolverIdServidor({
  required String tabela,
  String? uuid,
  int? idLocalOuServidor,
}) async {
  final viaUuid = await _idServidorPorUuid(tabela, uuid);
  if (viaUuid != null) return viaUuid;

  final localUuid = await _uuidPorIdLocal(tabela, idLocalOuServidor);
  final viaLocal = await _idServidorPorUuid(tabela, localUuid);
  if (viaLocal != null) return viaLocal;

  // Legado: o valor já pode ser o id do servidor.
  final candidate = idLocalOuServidor;
  if (candidate != null && candidate > 0) {
    final db = await SQLiteManager.instance.database;
    final map = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: [tabela, candidate],
      limit: 1,
    );
    if (map.isNotEmpty) return candidate;
  }
  return null;
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

String _converterJsonParaString(dynamic jsonConfig) {
  if (jsonConfig == null) return '';
  if (jsonConfig is String) return jsonConfig;
  return json.encode(jsonConfig);
}

// ===== FUNÇÃO PRINCIPAL - CHECKLISTS_PREENCHIDOS =====

Future syncChecklistsPreenchidos() async {
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
      final checklistsNaoSincronizados = await db.query(
        'checklists_preenchidos',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (checklistsNaoSincronizados.isNotEmpty) {
        // GERAR UUIDs PARA CHECKLISTS SEM UUID
        for (var checklist in checklistsNaoSincronizados) {
          if (checklist['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'checklists_preenchidos',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [checklist['id']],
            );
            print('✅ Gerado UUID para checklist: $newUuid');
          }
        }

        // BUSCAR CHECKLISTS ATUALIZADOS
        final checklistsComUuid = await db.query(
          'checklists_preenchidos',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO (IDs do servidor, não os locais do SQLite)
        final checklistsParaEnviar = <Map<String, dynamic>>[];
        for (final checklist in checklistsComUuid) {
          // TRATAR JSON_RESPOSTAS - garantir que é um Map válido
          dynamic jsonRespostas = checklist['json_respostas'];
          if (jsonRespostas is String) {
            try {
              jsonRespostas = json.decode(jsonRespostas);
            } catch (e) {
              jsonRespostas = {};
            }
          } else if (jsonRespostas == null) {
            jsonRespostas = {};
          }

          final templateUuid =
              (checklist['checklist_template_uuid'] ?? '').toString().trim();
          final obraUuid = (checklist['obra_uuid'] ?? '').toString().trim();
          final templateServerId = await _resolverIdServidor(
            tabela: 'checklists_templates',
            uuid: templateUuid.isEmpty ? null : templateUuid,
            idLocalOuServidor: _asInt(checklist['checklist_template_id']),
          );
          final obraServerId = await _resolverIdServidor(
            tabela: 'obras',
            uuid: obraUuid.isEmpty ? null : obraUuid,
            idLocalOuServidor: _asInt(checklist['obra_id']),
          );
          final usuarioServerId = _asInt(checklist['usuario_id']) ??
              (FFAppState().UserID > 0 ? FFAppState().UserID : null);

          if (templateServerId == null ||
              obraServerId == null ||
              usuarioServerId == null ||
              usuarioServerId < 1) {
            print(
              '⚠️ Checklist ${checklist['uuid']} sem mapeamento '
              '(template=$templateServerId obra=$obraServerId usuario=$usuarioServerId) — pulando upload',
            );
            continue;
          }

          checklistsParaEnviar.add({
            'uuid': checklist['uuid'],
            'checklist_template_id': templateServerId,
            'obra_id': obraServerId,
            'usuario_id': usuarioServerId,
            'json_respostas': jsonRespostas,
            'nota_final': checklist['nota_final']?.toString(),
            'situacao': checklist['situacao'] ?? 'pendente',
            'created_by': checklist['created_by'],
            'created_at': checklist['created_at'],
            'updated_at': checklist['updated_at'],
          });
        }

        if (checklistsParaEnviar.isEmpty) {
          print('ℹ️ Nenhum checklist com IDs de servidor resolvidos para enviar');
        } else {
        print('📤 Enviando ${checklistsParaEnviar.length} checklists...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              '$kApiBaseUrl/api/v1/sync/checklists-preenchidos/upload'),
          headers: headers,
          body: json.encode({'dados': checklistsParaEnviar}),
        );

        print('📡 Status upload: ${uploadResponse.statusCode}');
        print('📡 Body upload: ${uploadResponse.body}');

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          if (uploadResult['status'] == 'ok') {
            // MARCAR CHECKLISTS COMO SINCRONIZADOS + mapear id servidor
            for (var checklist in uploadResult['sincronizados'] ?? []) {
              final uuid = (checklist['uuid'] ?? '').toString();
              if (uuid.isEmpty) continue;
              final serverId = _asInt(checklist['id']);
              if (serverId != null) {
                await _salvarMapeamento(
                    'checklists_preenchidos', serverId, uuid);
              }
              await db.update(
                'checklists_preenchidos',
                {
                  'synced': 1,
                  'last_sync_date': DateTime.now().toIso8601String(),
                  'sync_try_count': 0,
                },
                where: 'uuid = ?',
                whereArgs: [uuid],
              );
              uploadedCount++;
            }
            print('✅ Upload concluído: $uploadedCount checklists');
          } else {
            print('❌ Erro no servidor: ${uploadResult['mensagem']}');
          }
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var checklist in checklistsComUuid) {
            final currentCount = checklist['sync_try_count'] as int? ?? 0;
            await db.update(
              'checklists_preenchidos',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [checklist['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
          print('❌ Body do erro: ${uploadResponse.body}');
        }
        }
      } else {
        print('ℹ️ Nenhum checklist para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('checklists_preenchidos');
      print('📥 Buscando checklists desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/checklists-preenchidos/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      print('📡 Status download: ${downloadResponse.statusCode}');

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final checklistsDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${checklistsDoServidor.length} checklists');

        for (var checklistServer in checklistsDoServidor) {
          await _processarChecklistPreenchido(
              checklistServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (checklistsDoServidor.isNotEmpty) {
          await db.update(
            'checklists_preenchidos',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount checklists');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
        print('❌ Body do erro: ${downloadResponse.body}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync checklists concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync checklists preenchidos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync checklists: $e');
    _updateSyncStatus(false, 'Erro geral sync checklists: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE CHECKLIST PREENCHIDO =====

Future<void> _processarChecklistPreenchido(
    Map<String, dynamic> checklistServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuid = normalizeSyncUuid(checklistServer['uuid']);
  if (uuid == null) {
    print('⚠️ download skip: uuid ausente');
    return;
  }

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (checklistServer['id'] != null) {
    await _salvarMapeamento(
        'checklists_preenchidos', checklistServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'checklists_preenchidos',
    where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
    whereArgs: [uuid],
  );

  // TRATAR JSON_RESPOSTAS
  dynamic jsonRespostas = checklistServer['json_respostas'];
  if (jsonRespostas != null && jsonRespostas is! String) {
    jsonRespostas = json.encode(jsonRespostas);
  }

  // VALORES PADRÃO
  final notaFinal = checklistServer['nota_final']?.toString();
  final situacao = checklistServer['situacao'] ?? 'pendente';

  final templateServerId = _asInt(checklistServer['checklist_template_id']);
  final obraServerId = _asInt(checklistServer['obra_id']);
  final templateLocalId = templateServerId == null
      ? null
      : (await _idLocalPorIdServidor(
              'checklists_templates', templateServerId) ??
          templateServerId);
  final obraLocalId = obraServerId == null
      ? null
      : (await _idLocalPorIdServidor('obras', obraServerId) ?? obraServerId);

  String? templateUuid = checklistServer['checklist_template_uuid']?.toString();
  if ((templateUuid == null || templateUuid.isEmpty) &&
      templateServerId != null) {
    final map = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: ['checklists_templates', templateServerId],
      limit: 1,
    );
    if (map.isNotEmpty) {
      templateUuid = map.first['uuid']?.toString();
    }
  }

  String? obraUuid = checklistServer['obra_uuid']?.toString();
  if ((obraUuid == null || obraUuid.isEmpty) && obraServerId != null) {
    final map = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: ['obras', obraServerId],
      limit: 1,
    );
    if (map.isNotEmpty) {
      obraUuid = map.first['uuid']?.toString();
    }
  }

  final payload = {
    'checklist_template_id': templateLocalId,
    'checklist_template_uuid': templateUuid,
    'obra_id': obraLocalId,
    'obra_uuid': obraUuid,
    'usuario_id': checklistServer['usuario_id'],
    'json_respostas': jsonRespostas,
    'nota_final': notaFinal,
    'situacao': situacao,
    'created_by': checklistServer['created_by'],
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': checklistServer['created_at'],
    'updated_at': checklistServer['updated_at'],
  };

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'checklists_preenchidos',
      payload,
      where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
      whereArgs: [uuid],
    );
    print('🔄 Checklist atualizado: $uuid');
  } else {
    // INSERT
    await db.insert(
      'checklists_preenchidos',
      {
        'uuid': uuid,
        ...payload,
      },
    );
    print('✅ Novo checklist inserido: $uuid');
  }
}

// ===== FUNÇÕES AUXILIARES =====

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

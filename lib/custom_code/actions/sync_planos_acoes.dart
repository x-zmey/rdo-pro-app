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

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import 'checklist_anexo_upload.dart';
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

Future<String?> _uuidChecklistPreenchido(Map<String, dynamic> plano) async {
  final direct = (plano['checklist_preenchido_uuid'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;
  final localId = _asInt(plano['checklist_preenchido_id']);
  if (localId == null || localId < 1) return null;
  final db = await SQLiteManager.instance.database;
  final rows = await db.query(
    'checklists_preenchidos',
    columns: ['uuid'],
    where: 'id = ?',
    whereArgs: [localId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  final u = (rows.first['uuid'] ?? '').toString().trim();
  return u.isEmpty ? null : u;
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

// ===== FUNÇÃO PRINCIPAL - PLANOS_ACOES =====

Future syncPlanosAcoes() async {
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
      final planosNaoSincronizados = await db.query(
        'planos_acoes',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (planosNaoSincronizados.isNotEmpty) {
        // GERAR UUIDs PARA PLANOS SEM UUID
        for (var plano in planosNaoSincronizados) {
          if (plano['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'planos_acoes',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [plano['id']],
            );
            print('✅ Gerado UUID para plano: $newUuid');
          }
        }

        // BUSCAR PLANOS ATUALIZADOS
        final planosComUuid = await db.query(
          'planos_acoes',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO (checklist_preenchido_id = PK do servidor)
        final planosParaEnviar = <Map<String, dynamic>>[];
        for (final plano in planosComUuid) {
          dynamic anexos = plano['anexos'];
          if (anexos is String) {
            try {
              anexos = json.decode(anexos);
            } catch (e) {
              anexos = [];
            }
          }
          if (anexos is List) {
            try {
              final uploaded = await uploadListaAnexosLocais(
                anexos: anexos
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(),
                token: token,
                destino: 'planos-acoes',
              );
              anexos = uploaded;
              await db.update(
                'planos_acoes',
                {
                  'anexos': json.encode(uploaded),
                  'updated_at': DateTime.now().toIso8601String(),
                },
                where: 'id = ?',
                whereArgs: [plano['id']],
              );
            } catch (e) {
              print('⚠️ Falha ao subir anexos do plano ${plano['uuid']}: $e');
            }
          }

          dynamic historico = plano['historico'];
          if (historico is String) {
            try {
              historico = json.decode(historico);
            } catch (e) {
              historico = [];
            }
          }

          final checklistUuid = await _uuidChecklistPreenchido(plano);
          final checklistServerId =
              await _idServidorPorUuid('checklists_preenchidos', checklistUuid);
          if (checklistServerId == null) {
            print(
              '⚠️ Plano ${plano['uuid']} sem checklist no servidor '
              '(uuid=$checklistUuid) — pulando upload',
            );
            continue;
          }

          planosParaEnviar.add({
            'uuid': plano['uuid'],
            'checklist_preenchido_id': checklistServerId,
            'checklist_preenchido_uuid': checklistUuid,
            'area_id': plano['area_id'],
            'item_id': plano['item_id'],
            'descricao': plano['descricao'],
            'area': plano['area'],
            'pergunta': plano['pergunta'],
            'resposta': plano['resposta'],
            'prazo': plano['prazo'],
            'prioridade': plano['prioridade'],
            'anexos': anexos ?? [],
            'responsavel_id': plano['responsavel_id'],
            'created_by': plano['created_by'],
            'status': plano['status'],
            'historico': historico ?? [],
            'created_at': plano['created_at'],
            'updated_at': plano['updated_at'],
          });
        }

        if (planosParaEnviar.isEmpty) {
          print('ℹ️ Nenhum plano com checklist no servidor para enviar');
        } else {
        print('📤 Enviando ${planosParaEnviar.length} planos de ação...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              '$kApiBaseUrl/api/v1/sync/planos-acoes/upload'),
          headers: headers,
          body: json.encode({'dados': planosParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          if (uploadResult['status'] == 'ok') {
            final sincronizados = uploadResult['sincronizados'];
            if (sincronizados is List && sincronizados.isNotEmpty) {
              for (var plano in sincronizados) {
                final uuid = (plano['uuid'] ?? '').toString();
                if (uuid.isEmpty) continue;
                final serverId = _asInt(plano['id']);
                if (serverId != null) {
                  await _salvarMapeamento('planos_acoes', serverId, uuid);
                }
                await db.update(
                  'planos_acoes',
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
            } else {
              // API legada devolve só {status: ok} — marca o lote enviado.
              for (final plano in planosParaEnviar) {
                final uuid = (plano['uuid'] ?? '').toString();
                if (uuid.isEmpty) continue;
                await db.update(
                  'planos_acoes',
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
            }
            print('✅ Upload concluído: $uploadedCount planos');
          } else {
            print('❌ Erro no servidor: ${uploadResult['mensagem']}');
          }
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var plano in planosComUuid) {
            final currentCount = plano['sync_try_count'] as int? ?? 0;
            await db.update(
              'planos_acoes',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [plano['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
        }
      } else {
        print('ℹ️ Nenhum plano de ação para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('planos_acoes');
      print('📥 Buscando planos de ação desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/planos-acoes/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final planosDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${planosDoServidor.length} planos de ação');

        for (var planoServer in planosDoServidor) {
          await _processarPlanoAcao(planoServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (planosDoServidor.isNotEmpty) {
          await db.update(
            'planos_acoes',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount planos');
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
      'Sync planos ação concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync planos de ação concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync planos: $e');
    _updateSyncStatus(false, 'Erro geral sync planos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE PLANO AÇÃO =====

Future<void> _processarPlanoAcao(
    Map<String, dynamic> planoServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuid = normalizeSyncUuid(planoServer['uuid']);
  if (uuid == null) {
    print('⚠️ download skip: uuid ausente');
    return;
  }

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (planoServer['id'] != null) {
    await _salvarMapeamento('planos_acoes', planoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'planos_acoes',
    where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
    whereArgs: [uuid],
  );

  // TRATAR CAMPOS JSON - converter para string antes de salvar no SQLite
  dynamic anexos = planoServer['anexos'];
  if (anexos != null && anexos is! String) {
    anexos = json.encode(anexos);
  }

  dynamic historico = planoServer['historico'];
  if (historico != null && historico is! String) {
    historico = json.encode(historico);
  }

  // VALORES PADRÃO
  final status = planoServer['status'] ?? 'Em andamento';

  // TRATAR CAMPOS NUMÉRICOS - garantir que são int
  final checklistServerId = _toInt(planoServer['checklist_preenchido_id']);
  final checklistLocalId =
      await _idLocalPorIdServidor('checklists_preenchidos', checklistServerId) ??
          checklistServerId;
  String checklistUuid =
      (planoServer['checklist_preenchido_uuid'] ?? '').toString().trim();
  if (checklistUuid.isEmpty && checklistServerId > 0) {
    final map = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: ['checklists_preenchidos', checklistServerId],
      limit: 1,
    );
    if (map.isNotEmpty) {
      checklistUuid = map.first['uuid']?.toString() ?? '';
    }
  }
  final areaId = _toInt(planoServer['area_id']);
  final itemId = _toInt(planoServer['item_id']);
  final responsavelId = _toInt(planoServer['responsavel_id']);
  final createdBy = _toInt(planoServer['created_by']);

  final payload = {
    'checklist_preenchido_id': checklistLocalId,
    'checklist_preenchido_uuid':
        checklistUuid.isEmpty ? null : checklistUuid,
    'area_id': areaId,
    'item_id': itemId,
    'descricao': planoServer['descricao'],
    'area': planoServer['area'],
    'pergunta': planoServer['pergunta'],
    'resposta': planoServer['resposta'],
    'prazo': planoServer['prazo'],
    'prioridade': planoServer['prioridade'],
    'anexos': anexos,
    'responsavel_id': responsavelId,
    'created_by': createdBy,
    'status': status,
    'historico': historico,
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': planoServer['created_at'],
    'updated_at': planoServer['updated_at'],
  };

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'planos_acoes',
      payload,
      where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
      whereArgs: [uuid],
    );
    print('🔄 Plano ação atualizado: ${planoServer['descricao']}');
  } else {
    // INSERT
    await db.insert(
      'planos_acoes',
      {
        'uuid': uuid,
        ...payload,
      },
    );
    print('✅ Novo plano ação inserido: ${planoServer['descricao']}');
  }
}

// ===== FUNÇÃO AUXILIAR PARA CONVERTER PARA INT =====
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is String) return int.tryParse(value) ?? 0;
  if (value is double) return value.toInt();
  return 0;
}

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

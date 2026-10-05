// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/init.dart';
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
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:math';

import 'sync_relatorio_download_merge_guard.dart';
import 'sync_relatorios.dart' show syncRelatorios;
import 'sync_uuid_upsert.dart';

/// Trim evita newline final na URL (405 MethodNotAllowed com `%0A`).
const String _kUrlUploadRelatorioAtividades =
    '$kApiBaseUrl/api/v1/sync/relatorios/atividades/upload';
const String _kUrlDownloadRelatorioAtividades =
    '$kApiBaseUrl/api/v1/sync/relatorios/atividades/download';

Uri _uriRelatorioAtividadesUpload() =>
    Uri.parse(_kUrlUploadRelatorioAtividades.trim());

Uri _uriRelatorioAtividadesDownload() =>
    Uri.parse(_kUrlDownloadRelatorioAtividades.trim());

int? _situacaoIntFromServer(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

/// Download: atividade veio como excluída (`-2`) → alinha fotos/itens locais (IDs SQLite).
Future<void> _cascadeSoftDeleteFilhosAtividadeNoSqlite(
  Database db,
  int relatorioAtividadeLocalId,
  String serverTime,
) async {
  if (relatorioAtividadeLocalId < 1) return;
  final ex = kSituacaoExcluidoLogico;
  await db.rawUpdate(
    '''
UPDATE relatorio_atividades_itens
SET situacao = ?, synced = 1, last_sync_date = ?, updated_at = ?
WHERE relatorio_atividade_id = ?
  AND (situacao IS NULL OR situacao != ?)
''',
    [ex, serverTime, serverTime, relatorioAtividadeLocalId, ex],
  );
  await db.rawUpdate(
    '''
UPDATE relatorio_atividade_fotos
SET situacao = ?, synced = 1, last_sync_date = ?, updated_at = ?
WHERE relatorio_atividade_id = ?
  AND (situacao IS NULL OR situacao != ?)
''',
    [ex, serverTime, serverTime, relatorioAtividadeLocalId, ex],
  );
}

// ===== FUNÇÕES UTILITÁRIAS (já existentes - copie da action anterior) =====

Future<void> _salvarMapeamento(
    String tabela, int idServidor, String uuid) async {
  final db = await SQLiteManager.instance.database;
  await upsertSyncIdMapping(
    db,
    tabela: tabela,
    idServidor: idServidor,
    uuid: uuid,
  );
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
  // SQLite (`nova.sql`): `created_by` é TEXT com UUID.
  return _nonEmptyStr(row['created_by_uuid']) ??
      _nonEmptyStr(row['created_by']) ??
      '';
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncRelatoriosAtividades() async {
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

    // ===== 1. UPLOAD - Enviar dados locais =====
    try {
      // Garante que relatórios (e seus UUIDs) existam no servidor antes das atividades.
      await syncRelatorios();
      await normalizeRelatorioAtividadesForUpload(db);
      final stampedRa =
          await stampPendingRelatorioAtividadesCreatedByTenantFallback(db);
      if (stampedRa > 0) {
        print(
            '✅ relatorio_atividades: stamp created_by (tenant) em $stampedRa pendente(s)',
        );
      }

      final relatoriosAtividadesNaoSincronizadas =
          await pendingRelatorioAtividadesForTenantSimple(db);

      if (relatoriosAtividadesNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA RELATORIOS SEM UUID
        for (var relatorioAtividade in relatoriosAtividadesNaoSincronizadas) {
          final u = relatorioAtividade['uuid']?.toString().trim() ?? '';
          if (u.isEmpty) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_atividades',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorioAtividade['id']],
            );
            print(
                '✅ Gerado UUID para relatorio atividade: ${relatorioAtividade['id']} -> $newUuid');
          }
        }

        final rawPendentes =
            await pendingRelatorioAtividadesForTenantSimple(db);
        final relatoriosAtividadesComUuid = <Map<String, dynamic>>[];
        for (final raw in rawPendentes) {
          final m = Map<String, dynamic>.from(raw);
          await backfillRelatorioUuidForPayloadRow(db, m);
          relatoriosAtividadesComUuid.add(m);
        }

        // Resolver UUIDs (tarefas/users/ordens) quando vierem nulos no mobile.
        final tarefaIds = <int>{};
        final userIds = <int>{};
        for (final r in relatoriosAtividadesComUuid) {
          final tid = _asInt(r['tarefa_id']);
          if (tid != null) tarefaIds.add(tid);
          final uid = _asInt(r['user_id']);
          if (uid != null) userIds.add(uid);
        }
        final tarefaIdList = tarefaIds.toList();
        final userIdList = userIds.toList();

        final Map<int, String> tarefaUuidById = {};
        if (tarefaIdList.isNotEmpty) {
          final placeholders = List.filled(tarefaIdList.length, '?').join(',');
          final rows = await db.rawQuery(
            'SELECT id, uuid FROM obra_etapa_tarefas WHERE id IN ($placeholders)',
            tarefaIdList,
          );
          for (final row in rows) {
            final idVal = _asInt(row['id']);
            final uuidVal = _nonEmptyStr(row['uuid']);
            if (idVal != null && uuidVal != null) {
              tarefaUuidById[idVal] = uuidVal;
            }
          }
        }

        final Map<int, String> userUuidById = {};
        if (userIdList.isNotEmpty) {
          final placeholders = List.filled(userIdList.length, '?').join(',');
          final rows = await db.rawQuery(
            'SELECT id, uuid FROM users WHERE id IN ($placeholders)',
            userIdList,
          );
          for (final row in rows) {
            final idVal = _asInt(row['id']);
            final uuidVal = _nonEmptyStr(row['uuid']);
            if (idVal != null && uuidVal != null) {
              userUuidById[idVal] = uuidVal;
            }
          }
        }

        final ordemIds = <int>{};
        for (final r in relatoriosAtividadesComUuid) {
          final oid = _asInt(r['ordem_id']);
          if (oid != null) ordemIds.add(oid);
        }
        final ordemIdList = ordemIds.toList();

        final Map<int, String> ordemUuidById = {};
        if (ordemIdList.isNotEmpty) {
          final placeholders = List.filled(ordemIdList.length, '?').join(',');
          final rows = await db.rawQuery(
            'SELECT id, uuid FROM ordens_servico WHERE id IN ($placeholders)',
            ordemIdList,
          );
          for (final row in rows) {
            final idVal = _asInt(row['id']);
            final uuidVal = _nonEmptyStr(row['uuid']);
            if (idVal != null && uuidVal != null) {
              ordemUuidById[idVal] = uuidVal;
            }
          }
        }

        // PREPARAR DADOS PARA ENVIO
        final relatoriosAtividadesParaEnviar = relatoriosAtividadesComUuid
            .map((relatorioAtividade) {
              final tarefaId = _asInt(relatorioAtividade['tarefa_id']);
              final userId = _asInt(relatorioAtividade['user_id']);

              final relatorioUuid =
                  _nonEmptyStr(relatorioAtividade['relatorio_uuid']);
              final tarefaUuid =
                  _nonEmptyStr(relatorioAtividade['tarefa_uuid']) ??
                      (tarefaId != null ? tarefaUuidById[tarefaId] : null);
              final userUuid = _nonEmptyStr(relatorioAtividade['user_uuid']) ??
                  (userId != null ? userUuidById[userId] : null);

              final ordemIdVal = _asInt(relatorioAtividade['ordem_id']);
              final ordemUuid = _nonEmptyStr(relatorioAtividade['ordem_uuid']) ??
                  (ordemIdVal != null ? ordemUuidById[ordemIdVal] : null);

              // Server resolve pelo UUID; se faltar relatorio_uuid, melhor pular.
              if (relatorioUuid == null || relatorioUuid.isEmpty) return null;
              // Atividade avulsa: sem tarefa_id → tarefa_uuid pode ficar vazia.
              if (tarefaId != null &&
                  (tarefaUuid == null || tarefaUuid.isEmpty)) {
                return null;
              }

              return {
                'uuid': relatorioAtividade['uuid'],
                'user_id': relatorioAtividade['user_id'],
                'relatorio_id': relatorioAtividade['relatorio_id'],
                'ordem_id': relatorioAtividade['ordem_id'],
                'ordem_uuid': ordemUuid ?? '',
                'tarefa_id': relatorioAtividade['tarefa_id'],
                'user_uuid': userUuid ?? '',
                'relatorio_uuid': relatorioUuid,
                'tarefa_uuid': tarefaUuid ?? '',
                'item': relatorioAtividade['item'],
                'local': relatorioAtividade['local'],
                'descricao': relatorioAtividade['descricao'],
                'quantidade': relatorioAtividade['quantidade'],
                'unidade': relatorioAtividade['unidade'],
                'qtd_realizada': relatorioAtividade['qtd_realizada'],
                'created_by_uuid': _createdByLocal(relatorioAtividade),
                'situacao': relatorioAtividade['situacao'],
                'created_at': relatorioAtividade['created_at'],
                'updated_at': relatorioAtividade['updated_at']
              };
            })
            .whereType<Map<String, dynamic>>()
            .toList();

        final pendentes = relatoriosAtividadesComUuid.length;
        final enviando = relatoriosAtividadesParaEnviar.length;
        if (pendentes > enviando) {
          print(
              '⚠️ relatorio_atividades: $pendentes pendente(s) local(is), só $enviando no payload '
              '(falta relatorio_uuid/user_uuid/ordem_uuid quando há vínculo, ou tarefa_uuid quando há tarefa_id — '
              'atividade avulsa pode ter tarefa_uuid vazio).');
        }
        final uploadUri = _uriRelatorioAtividadesUpload();
        print('📤 POST $uploadUri');
        print(
            '📤 Enviando ${relatoriosAtividadesParaEnviar.length} relatorios atividades...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          uploadUri,
          headers: headers,
          body: json.encode({'dados': relatoriosAtividadesParaEnviar}),
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
          for (var relatorioAtividade in (sinc is List ? sinc : const [])) {
            if (relatorioAtividade is! Map) continue;
            final u = relatorioAtividade['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_atividades',
              {
                'synced': 1,
                // Não usar relógio do aparelho: vira cursor de download e esconde updates.
                'last_sync_date': stUpload,
                'sync_try_count': 0,
              },
              where: 'LOWER(TRIM(COALESCE(uuid, \'\'))) = ?',
              whereArgs: [normalizeSyncUuid(u) ?? u],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount relatorios atividades');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioAtividade in relatoriosAtividadesComUuid) {
            final currentCount =
                relatorioAtividade['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_atividades',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioAtividade['uuid']],
            );
          }
          hadError = true;
          final bodyPreview = uploadResponse.body.length > 900
              ? '${uploadResponse.body.substring(0, 900)}...'
              : uploadResponse.body;
          print(
              '❌ Erro no upload atividades: ${uploadResponse.statusCode} — $bodyPreview');
        }
      } else {
        print('ℹ️ Nenhuma relatorio atividade para enviar');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_atividades');
      print('📥 Buscando relatorios atividades desde: $lastSync');

      final downloadUri = _uriRelatorioAtividadesDownload();
      print('📥 POST $downloadUri');
      final downloadResponse = await http.post(
        downloadUri,
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosAtividadesDoServidor = downloadResult['dados'] as List;

        print(
            '📥 Recebidas ${relatoriosAtividadesDoServidor.length} atividades');

        for (var relatorioAtividadeServer in relatoriosAtividadesDoServidor) {
          await _processarOrdemTarefa(
              relatorioAtividadeServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE (só deste tenant)
        if (relatoriosAtividadesDoServidor.isNotEmpty) {
          await updateLastSyncRelatorioAtividadesSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print('✅ Download concluído: $downloadedCount relatorios atividades');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        hadError = true;
        final bodyPreview = downloadResponse.body.length > 900
            ? '${downloadResponse.body.substring(0, 900)}...'
            : downloadResponse.body;
        print(
            '❌ Erro no download atividades: ${downloadResponse.statusCode} — $bodyPreview');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no download: $e');
    }

    if (hadError) {
      _updateSyncStatus(
        false,
        'Falha no sync de atividades do relatório (↑$uploadedCount ↓$downloadedCount)',
        uploadedCount,
        downloadedCount,
      );
      throw Exception('Falha parcial no sync de relatorio_atividades');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync atividades concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios atividades concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios atividades: $e');
    _updateSyncStatus(false, 'Erro geral sync relatorios atividades: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioAtividadeServer, String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  final uuid = normalizeSyncUuid(relatorioAtividadeServer['uuid']);
  if (uuid == null) {
    print(
      '⚠️ relatorio_atividades download: uuid ausente — skip (não gera UUID no pull)',
    );
    return;
  }

  final serverId = syncServerId(relatorioAtividadeServer['id']);
  if (serverId != null) {
    await _salvarMapeamento('relatorio_atividades', serverId, uuid);
  }

  final existente = await resolveLocalRowForSyncDownload(
    db,
    tabela: 'relatorio_atividades',
    uuid: uuid,
    serverId: serverId,
  );

  final rowData = <String, dynamic>{
    'uuid': uuid,
    'user_id': relatorioAtividadeServer['user_id'],
    'user_uuid': _nonEmptyStr(relatorioAtividadeServer['user_uuid']),
    'relatorio_id': relatorioAtividadeServer['relatorio_id'],
    'relatorio_uuid': _nonEmptyStr(relatorioAtividadeServer['relatorio_uuid']),
    'ordem_id': relatorioAtividadeServer['ordem_id'],
    'ordem_uuid': _nonEmptyStr(relatorioAtividadeServer['ordem_uuid']),
    'tarefa_id': relatorioAtividadeServer['tarefa_id'],
    'tarefa_uuid': _nonEmptyStr(relatorioAtividadeServer['tarefa_uuid']),
    'item': relatorioAtividadeServer['item'],
    'local': relatorioAtividadeServer['local'],
    'descricao': relatorioAtividadeServer['descricao'],
    'quantidade': relatorioAtividadeServer['quantidade'],
    'unidade': relatorioAtividadeServer['unidade'],
    'qtd_realizada': relatorioAtividadeServer['qtd_realizada'],
    'created_by': _createdByLocal(relatorioAtividadeServer),
    'situacao': relatorioAtividadeServer['situacao'],
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': relatorioAtividadeServer['created_at'],
    'updated_at': relatorioAtividadeServer['updated_at'],
  };

  if (existente != null) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: existente,
          serverRow: relatorioAtividadeServer,
          tabela: 'relatorio_atividades',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    final localId = existente['id'] as int;
    await alignLocalUuidIfNeeded(
      db,
      tabela: 'relatorio_atividades',
      localId: localId,
      canonicalUuid: uuid,
      localRow: existente,
    );
    await db.update(
      'relatorio_atividades',
      rowData,
      where: 'id = ?',
      whereArgs: [localId],
    );
    if (_situacaoIntFromServer(relatorioAtividadeServer['situacao']) ==
        kSituacaoExcluidoLogico) {
      await _cascadeSoftDeleteFilhosAtividadeNoSqlite(db, localId, serverTime);
    }
  } else {
    final localId = await db.insert(
      'relatorio_atividades',
      rowData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    // ignore = já existia (race/unique); tenta update pelo uuid.
    if (localId == 0) {
      await db.update(
        'relatorio_atividades',
        rowData,
        where: 'LOWER(TRIM(COALESCE(uuid, \'\'))) = ?',
        whereArgs: [uuid],
      );
    }
    final idForCascade = localId > 0
        ? localId
        : (await resolveLocalRowForSyncDownload(
              db,
              tabela: 'relatorio_atividades',
              uuid: uuid,
              serverId: serverId,
            ))?['id'] as int?;
    if (idForCascade != null &&
        _situacaoIntFromServer(relatorioAtividadeServer['situacao']) ==
            kSituacaoExcluidoLogico) {
      await _cascadeSoftDeleteFilhosAtividadeNoSqlite(
          db, idForCascade, serverTime);
    }
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
    return FFAppState().UserToken;
  } catch (e) {
    return '';
  }
}

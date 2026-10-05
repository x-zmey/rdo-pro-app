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
import 'dart:convert';
import 'dart:math';

import 'package:sqflite/sqflite.dart';

import 'sync_relatorio_download_merge_guard.dart';
import 'sync_relatorios_atividades.dart' show syncRelatoriosAtividades;
import 'sync_uuid_upsert.dart';

/// Trim evita newline final na URL (405 MethodNotAllowed com `%0A`).
const String _kUrlUploadRelatorioAtividadesItens =
    '$kApiBaseUrl/api/v1/sync/relatorios/atividades-itens/upload';
const String _kUrlDownloadRelatorioAtividadesItens =
    '$kApiBaseUrl/api/v1/sync/relatorios/atividades-itens/download';

Uri _uriRelatorioAtividadesItensUpload() =>
    Uri.parse(_kUrlUploadRelatorioAtividadesItens.trim());

Uri _uriRelatorioAtividadesItensDownload() =>
    Uri.parse(_kUrlDownloadRelatorioAtividadesItens.trim());

// ===== FUNÇÕES UTILITÁRIAS (já existentes - copie da action anterior) =====

Future<void> _salvarMapeamento(
    String tabela, int idServidor, String uuid) async {
  final db = await SQLiteManager.instance.database;
  try {
    await upsertSyncIdMapping(
      db,
      tabela: tabela,
      idServidor: idServidor,
      uuid: uuid,
    );
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

// ===== FUNÇÃO PRINCIPAL =====

Future syncRelatoriosAtividadesItens() async {
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
      await syncRelatoriosAtividades();
      await normalizeRelatorioAtividadesItensForUpload(db);
      final stamped =
          await stampPendingRelatorioAtividadesItensCreatedByTenantFallback(db);
      if (stamped > 0) {
        print(
            '✅ relatorio_atividades_itens: stamp created_by (tenant) em $stamped pendente(s)',
        );
      }

      final relatoriosAtividadesItensNaoSincronizadas =
          await pendingRelatorioAtividadesItensForTenantSimple(db);

      if (relatoriosAtividadesItensNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA RELATORIOS SEM UUID
        for (var relatorioAtividadeItem
            in relatoriosAtividadesItensNaoSincronizadas) {
          final u = relatorioAtividadeItem['uuid']?.toString().trim() ?? '';
          if (u.isEmpty) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_atividades_itens',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorioAtividadeItem['id']],
            );
            print(
                '✅ Gerado UUID para relatorio atividade item: ${relatorioAtividadeItem['id']} -> $newUuid');
          }
        }

        final rawPendentes =
            await pendingRelatorioAtividadesItensForTenantSimple(db);
        final relatoriosAtividadesItensComUuid = <Map<String, dynamic>>[];
        for (final raw in rawPendentes) {
          final m = Map<String, dynamic>.from(raw);
          await backfillRelatorioAtividadeUuidForPayloadRow(db, m);
          await backfillObraItemUuidForPayloadRow(db, m);
          relatoriosAtividadesItensComUuid.add(m);
        }

        // PREPARAR DADOS PARA ENVIO
        final relatoriosAtividadesItensParaEnviar =
            relatoriosAtividadesItensComUuid
                .map((relatorioAtividadeItem) {
                  final relatorioAtividadeUuid = _nonEmptyStr(
                      relatorioAtividadeItem['relatorio_atividade_uuid']);

                  final obraItemUuid =
                      _nonEmptyStr(relatorioAtividadeItem['obra_item_uuid']);

                  if (relatorioAtividadeUuid == null || obraItemUuid == null) {
                    // Se não tem UUID, o servidor não consegue resolver os ids.
                    return null;
                  }

                  return {
                    'uuid': relatorioAtividadeItem['uuid'],
                    'relatorio_atividade_id':
                        relatorioAtividadeItem['relatorio_atividade_id'],
                    'relatorio_atividade_uuid': relatorioAtividadeUuid,
                    'tipo': relatorioAtividadeItem['tipo'],
                    'obra_item_id': relatorioAtividadeItem['obra_item_id'],
                    'obra_item_uuid': obraItemUuid,
                    'qtd_utilizada': relatorioAtividadeItem['qtd_utilizada'],
                    'qtd_realizada': relatorioAtividadeItem['qtd_realizada'],
                    'qtd_produzida':
                        relatorioAtividadeItem['qtd_produzida'] ?? 0,
                    'situacao': relatorioAtividadeItem['situacao'],
                    'created_at': relatorioAtividadeItem['created_at'],
                    'updated_at': relatorioAtividadeItem['updated_at']
                  };
                })
                .whereType<Map<String, dynamic>>()
                .toList();

        final pendentesLocais = relatoriosAtividadesItensComUuid.length;
        final noPayload = relatoriosAtividadesItensParaEnviar.length;
        if (pendentesLocais > noPayload) {
          print(
            '⚠️ relatorio_atividades_itens: $pendentesLocais pendente(s) local(is), só $noPayload no payload '
            '(falta UUID da atividade ou do obra_item — verifique obra_itens.uuid e relatorio_atividades.uuid).',
          );
        }

        final uploadUri = _uriRelatorioAtividadesItensUpload();
        print('📤 POST $uploadUri');
        print(
            '📤 Enviando ${relatoriosAtividadesItensParaEnviar.length} relatorios atividades itens...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          uploadUri,
          headers: headers,
          body: json.encode({'dados': relatoriosAtividadesItensParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadBody =
              mapaRespostaSyncJson(json.decode(uploadResponse.body));
          final stUpload = serverTimeDoJsonResposta(uploadBody);

          for (final rowSrv in servidorVenceuLwwDoJson(uploadBody)) {
            await _processarOrdemTarefa(rowSrv, stUpload,
                prioridadeServidor: true);
          }

          // MARCAR RELATORIOS RELATORIOS ATIVIDADES COMO SINCRONIZADAS
          final sinc = uploadBody['sincronizados'];
          for (var relatorioAtividadeItem in (sinc is List ? sinc : const [])) {
            if (relatorioAtividadeItem is! Map) continue;
            final u = relatorioAtividadeItem['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_atividades_itens',
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
          print(
              '✅ Upload concluído: $uploadedCount relatorios atividades itens');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioAtividadeItem in relatoriosAtividadesItensComUuid) {
            final currentCount =
                relatorioAtividadeItem['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_atividades_itens',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioAtividadeItem['uuid']],
            );
          }
          hadError = true;
          final bodyPreview = uploadResponse.body.length > 900
              ? '${uploadResponse.body.substring(0, 900)}...'
              : uploadResponse.body;
          print(
              '❌ Erro no upload atividades itens: ${uploadResponse.statusCode} — $bodyPreview');
        }
      } else {
        print('ℹ️ Nenhuma relatorio atividade itens para enviar');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_atividades_itens');
      print('📥 Buscando relatorios atividades itens desde: $lastSync');

      final downloadUri = _uriRelatorioAtividadesItensDownload();
      print('📥 POST $downloadUri');
      final downloadResponse = await http.post(
        downloadUri,
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosAtividadesItensDoServidor =
            downloadResult['dados'] as List;

        print(
            '📥 Recebidas ${relatoriosAtividadesItensDoServidor.length} atividades itens');

        for (var relatorioAtividadeItemServer
            in relatoriosAtividadesItensDoServidor) {
          await _processarOrdemTarefa(
              relatorioAtividadeItemServer, downloadResult['server_time']);
          downloadedCount++;
        }

        if (relatoriosAtividadesItensDoServidor.isNotEmpty) {
          await updateLastSyncRelatorioAtividadesItensSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print(
            '✅ Download concluído: $downloadedCount relatorios atividades itens');
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
            '❌ Erro no download atividades itens: ${downloadResponse.statusCode} — $bodyPreview');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no download: $e');
    }

    if (hadError) {
      _updateSyncStatus(
        false,
        'Falha no sync de itens de atividade (↑$uploadedCount ↓$downloadedCount)',
        uploadedCount,
        downloadedCount,
      );
      throw Exception('Falha parcial no sync de relatorio_atividades_itens');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync atividades itens concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios atividades itens concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios atividades itens: $e');
    _updateSyncStatus(
        false, 'Erro geral sync relatorios atividades itens: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioAtividadeItemServer,
    String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  final uuid = normalizeSyncUuid(relatorioAtividadeItemServer['uuid']);
  if (uuid == null) {
    print(
      '⚠️ relatorio_atividades_itens download: uuid ausente — skip',
    );
    return;
  }

  final serverId = syncServerId(relatorioAtividadeItemServer['id']);
  if (serverId != null) {
    await _salvarMapeamento('relatorio_atividades_itens', serverId, uuid);
  }

  final existente = await resolveLocalRowForSyncDownload(
    db,
    tabela: 'relatorio_atividades_itens',
    uuid: uuid,
    serverId: serverId,
  );

  final rowData = <String, dynamic>{
    'uuid': uuid,
    'relatorio_atividade_id':
        relatorioAtividadeItemServer['relatorio_atividade_id'],
    'relatorio_atividade_uuid': _nonEmptyStr(
        relatorioAtividadeItemServer['relatorio_atividade_uuid']),
    'tipo': relatorioAtividadeItemServer['tipo'],
    'obra_item_id': relatorioAtividadeItemServer['obra_item_id'],
    'obra_item_uuid':
        _nonEmptyStr(relatorioAtividadeItemServer['obra_item_uuid']),
    'qtd_utilizada': relatorioAtividadeItemServer['qtd_utilizada'],
    'qtd_realizada': relatorioAtividadeItemServer['qtd_realizada'],
    'qtd_produzida': relatorioAtividadeItemServer['qtd_produzida'] ?? 0,
    'situacao': relatorioAtividadeItemServer['situacao'],
    'created_by': FFAppState().creatorUuid.trim(),
    'synced': 1,
    'last_sync_date': serverTime,
    'updated_at': relatorioAtividadeItemServer['updated_at'],
  };

  if (existente != null) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: existente,
          serverRow: relatorioAtividadeItemServer,
          tabela: 'relatorio_atividades_itens',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    final localId = existente['id'] as int;
    await alignLocalUuidIfNeeded(
      db,
      tabela: 'relatorio_atividades_itens',
      localId: localId,
      canonicalUuid: uuid,
      localRow: existente,
    );
    await db.update(
      'relatorio_atividades_itens',
      rowData,
      where: 'id = ?',
      whereArgs: [localId],
    );
  } else {
    final inserted = await db.insert(
      'relatorio_atividades_itens',
      rowData,
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    if (inserted == 0) {
      await db.update(
        'relatorio_atividades_itens',
        rowData,
        where: 'LOWER(TRIM(COALESCE(uuid, \'\'))) = ?',
        whereArgs: [uuid],
      );
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

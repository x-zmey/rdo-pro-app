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

const String _kUrlUploadRelatorioComentarios =
    '$kApiBaseUrl/api/v1/sync/relatorios/comentarios/upload';
const String _kUrlDownloadRelatorioComentarios =
    '$kApiBaseUrl/api/v1/sync/relatorios/comentarios/download';

Uri _uriRelatorioComentariosUpload() =>
    Uri.parse(_kUrlUploadRelatorioComentarios.trim());

Uri _uriRelatorioComentariosDownload() =>
    Uri.parse(_kUrlDownloadRelatorioComentarios.trim());

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
  // No SQLite (`nova.sql`), `created_by` é TEXT com UUID.
  return _nonEmptyStr(row['created_by_uuid']) ??
      _nonEmptyStr(row['created_by']) ??
      '';
}

// ===== FUNÇÃO PRINCIPAL =====

Future synRelatoriosComentarios() async {
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

    // ===== 1. UPLOAD — só [relatorio_comentarios]: created_by = tenant, sem JOIN =====
    try {
      await stampPendingRelatorioComentariosCreatedByTenantFallback(db);

      var relatoriosComentariosNaoSincronizadas =
          await pendingRelatorioComentariosForTenantSimple(db);

      if (relatoriosComentariosNaoSincronizadas.isNotEmpty) {
        for (final row in relatoriosComentariosNaoSincronizadas) {
          if (row['uuid'] == null ||
              (row['uuid'] as String?)?.trim().isEmpty == true) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_comentarios',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            print(
                '✅ Gerado UUID para relatorio comentario: ${row['id']} -> $newUuid');
          }
        }

        final relatoriosComentariosComUuid =
            await pendingRelatorioComentariosForTenantSimple(db);

        final relatoriosComentariosParaEnviar = <Map<String, dynamic>>[];
        for (final rowCm in relatoriosComentariosComUuid) {
          final linha = Map<String, dynamic>.from(rowCm);
          await backfillRelatorioUuidForPayloadRow(db, linha);
          relatoriosComentariosParaEnviar.add({
            'uuid': linha['uuid'],
            'relatorio_id': linha['relatorio_id'],
            'relatorio_uuid': linha['relatorio_uuid'],
            'texto': linha['texto'],
            'created_by_uuid': linha['created_by'],
            'situacao': linha['situacao'],
            'created_at': linha['created_at'],
            'updated_at': linha['updated_at'],
          });
        }

        print(
            '📤 Enviando ${relatoriosComentariosParaEnviar.length} relatorios comentarios...');
        print('📤 POST ${_uriRelatorioComentariosUpload()}');

        final uploadResponse = await http.post(
          _uriRelatorioComentariosUpload(),
          headers: headers,
          body: json.encode({'dados': relatoriosComentariosParaEnviar}),
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
          for (var relatorioComentario in (sinc is List ? sinc : const [])) {
            if (relatorioComentario is! Map) continue;
            final u = relatorioComentario['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_comentarios',
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
          print('✅ Upload concluído: $uploadedCount relatorios  comentarios');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioComentario in relatoriosComentariosComUuid) {
            final currentCount =
                relatorioComentario['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_comentarios',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioComentario['uuid']],
            );
          }
          print(
              '❌ Erro no upload: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhuma relatorio comentario para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_comentarios');
      print('📥 Buscando relatorios comentarios desde: $lastSync');
      print('📥 POST ${_uriRelatorioComentariosDownload()}');

      final downloadResponse = await http.post(
        _uriRelatorioComentariosDownload(),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosComentariosDoServidor = downloadResult['dados'] as List;

        print(
            '📥 Recebidas ${relatoriosComentariosDoServidor.length} comentarios');

        for (var relatorioComentarioServer in relatoriosComentariosDoServidor) {
          await _processarOrdemTarefa(
              relatorioComentarioServer, downloadResult['server_time']);
          downloadedCount++;
        }

        if (relatoriosComentariosDoServidor.isNotEmpty) {
          await updateLastSyncRelatorioComentariosSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print('✅ Download concluído: $downloadedCount relatorios comentarios');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print(
            '❌ Erro no download: ${downloadResponse.statusCode} — ${downloadResponse.body}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync comentarios concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios comentarios concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios  comentarios: $e');
    _updateSyncStatus(
        false, 'Erro geral sync relatorios comentarios: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioComentarioServer, String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  final uuid = normalizeSyncUuid(relatorioComentarioServer['uuid']);
  if (uuid == null) {
    print('⚠️ download skip: uuid ausente');
    return;
  }

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioComentarioServer['id'] != null) {
    await _salvarMapeamento(
        'relatorio_comentarios', relatorioComentarioServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorio_comentarios',
    where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: relatorioComentarioServer,
          tabela: 'relatorio_comentarios',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    // UPDATE
    await db.update(
      'relatorio_comentarios',
      {
        'relatorio_id': relatorioComentarioServer['relatorio_id'],
        'relatorio_uuid':
            _nonEmptyStr(relatorioComentarioServer['relatorio_uuid']),
        'texto': relatorioComentarioServer['texto'],
        'created_by': _createdByLocal(relatorioComentarioServer),
        'situacao': relatorioComentarioServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': relatorioComentarioServer['created_at'],
        'updated_at': relatorioComentarioServer['updated_at']
      },
      where: "LOWER(TRIM(COALESCE(uuid, ''))) = ?",
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert(
      'relatorio_comentarios',
      {
        'uuid': uuid,
        'relatorio_id': relatorioComentarioServer['relatorio_id'],
        'relatorio_uuid':
            _nonEmptyStr(relatorioComentarioServer['relatorio_uuid']),
        'texto': relatorioComentarioServer['texto'],
        'created_by': _createdByLocal(relatorioComentarioServer),
        'situacao': relatorioComentarioServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': relatorioComentarioServer['created_at'],
        'updated_at': relatorioComentarioServer['updated_at']
      },
    );
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

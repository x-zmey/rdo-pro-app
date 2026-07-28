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

import 'index.dart'; // Imports other custom actions

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';

import '/backend/sqlite/situacao_soft_delete.dart';

import 'sync_relatorio_download_merge_guard.dart';
import 'sync_relatorios_atividades.dart' show syncRelatoriosAtividades;

/// Trim evita newline final na URL (405 MethodNotAllowed com `%0A`).
const String _kUrlUploadRelatorioAtividadeFotos =
    'https://api.rdopro.com.br/api/v1/sync/relatorios/atividade-fotos/upload';
const String _kUrlDownloadRelatorioAtividadeFotos =
    'https://api.rdopro.com.br/api/v1/sync/relatorios/atividade-fotos/download';

Uri _uriRelatorioAtividadeFotosUpload() =>
    Uri.parse(_kUrlUploadRelatorioAtividadeFotos.trim());

Uri _uriRelatorioAtividadeFotosDownload() =>
    Uri.parse(_kUrlDownloadRelatorioAtividadeFotos.trim());

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
  // SQLite (`nova.sql`): `created_by` é TEXT com UUID.
  // Preferimos `created_by_uuid` quando vier do servidor; fallback para `created_by`.
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

bool _isHttpUrl(String value) {
  final v = value.toLowerCase();
  return v.startsWith('http://') || v.startsWith('https://');
}

String _resolvedLocalPath(String raw) {
  var p = raw.trim();
  if (p.startsWith('file://')) {
    p = p.replaceFirst(RegExp(r'^file://'), '');
  }
  return p;
}

Future<bool> _arquivoLocalExiste(String raw) async {
  final p = _resolvedLocalPath(raw);
  if (p.isEmpty) return false;
  try {
    return await File(p).exists();
  } catch (_) {
    return false;
  }
}

/// Após upload: grava a URL do S3 em [arquivo_servidor] e mantém [arquivo] como caminho local se o arquivo ainda existir.
Future<void> _marcarFotoSincronizada(
  Database db,
  String uuid, {
  String? novoArquivoHttp,
}) async {
  final rows = await db.query(
    'relatorio_atividade_fotos',
    where: 'uuid = ?',
    whereArgs: [uuid],
    limit: 1,
  );
  if (rows.isEmpty) return;

  final u = novoArquivoHttp?.toString().trim();
  if (u != null && u.isNotEmpty && _isHttpUrl(u)) {
    final cur = rows.first['arquivo']?.toString().trim() ?? '';
    final patch = <String, dynamic>{
      'synced': 1,
      'last_sync_date': DateTime.now().toIso8601String(),
      'sync_try_count': 0,
      'arquivo_servidor': u,
    };
    final keepLocal = cur.isNotEmpty && !_isHttpUrl(cur);
    if (keepLocal) {
      try {
        if (await File(cur).exists()) {
          await db.update(
            'relatorio_atividade_fotos',
            patch,
            where: 'uuid = ?',
            whereArgs: [uuid],
          );
          return;
        }
      } catch (_) {}
    }
    patch['arquivo'] = u;
    await db.update(
      'relatorio_atividade_fotos',
      patch,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return;
  }

  await db.update(
    'relatorio_atividade_fotos',
    {
      'synced': 1,
      'last_sync_date': DateTime.now().toIso8601String(),
      'sync_try_count': 0,
    },
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
}

/// Merge download servidor ↔ SQLite: preserva caminho local utilizável; URL remota em [arquivo_servidor].
Future<Map<String, String?>> _mergeArquivoFotoCampos({
  required Map<String, dynamic>? existingRow,
  required String? serverArquivoRaw,
}) async {
  final serverArquivo = serverArquivoRaw?.toString().trim() ?? '';
  final serverIsHttp =
      serverArquivo.isNotEmpty && _isHttpUrl(serverArquivo);

  if (existingRow == null) {
    return {
      'arquivo': serverArquivo.isNotEmpty ? serverArquivo : null,
      'arquivo_servidor': serverIsHttp ? serverArquivo : null,
    };
  }

  final localArquivo = existingRow['arquivo']?.toString().trim() ?? '';
  final localIsHttp = localArquivo.isNotEmpty && _isHttpUrl(localArquivo);
  final existingServidor =
      existingRow['arquivo_servidor']?.toString().trim() ?? '';
  final servidorPrev =
      existingServidor.isNotEmpty && _isHttpUrl(existingServidor);

  String? arquivoServidor =
      serverIsHttp ? serverArquivo : (servidorPrev ? existingServidor : null);

  if (!localIsHttp && localArquivo.isNotEmpty) {
    try {
      if (await File(localArquivo).exists()) {
        return {
          'arquivo': localArquivo,
          'arquivo_servidor': arquivoServidor,
        };
      }
    } catch (_) {}
  }

  final arquivoFinal = serverArquivo.isNotEmpty
      ? serverArquivo
      : (localArquivo.isNotEmpty ? localArquivo : null);
  if (arquivoServidor == null &&
      arquivoFinal != null &&
      _isHttpUrl(arquivoFinal)) {
    arquivoServidor = arquivoFinal;
  }
  return {
    'arquivo': arquivoFinal,
    'arquivo_servidor': arquivoServidor,
  };
}

/// A API manda `relatorio_atividade_id` do MySQL; no SQLite cada aparelho tem outro PK em [relatorio_atividades].
Future<int?> _localRelatorioAtividadeIdParaFoto(
  Database db,
  Map<String, dynamic> serverRow, {
  int? existingLocalFk,
}) async {
  final auuid = _nonEmptyStr(serverRow['relatorio_atividade_uuid']);
  if (auuid != null && auuid.isNotEmpty) {
    final rows = await db.query(
      'relatorio_atividades',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [auuid],
      limit: 1,
    );
    if (rows.isNotEmpty) return rows.first['id'] as int?;
  }
  final sid = _asInt(serverRow['relatorio_atividade_id']);
  if (sid != null) {
    final mapRows = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: ['relatorio_atividades', sid],
      limit: 1,
    );
    if (mapRows.isNotEmpty) {
      final u = mapRows.first['uuid'] as String?;
      if (u != null && u.isNotEmpty) {
        final rows = await db.query(
          'relatorio_atividades',
          columns: ['id'],
          where: 'uuid = ?',
          whereArgs: [u],
          limit: 1,
        );
        if (rows.isNotEmpty) return rows.first['id'] as int?;
      }
    }
  }
  if (existingLocalFk != null) {
    final check = await db.query(
      'relatorio_atividades',
      columns: ['id'],
      where: 'id = ?',
      whereArgs: [existingLocalFk],
      limit: 1,
    );
    if (check.isNotEmpty) return existingLocalFk;
  }
  return null;
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncRelatorioAtividadesFotos() async {
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
      await normalizeRelatorioAtividadeFotosForUpload(db);
      final stampedF =
          await stampPendingRelatorioAtividadeFotosCreatedByTenantFallback(db);
      if (stampedF > 0) {
        print(
            '✅ relatorio_atividade_fotos: stamp created_by (tenant) em $stampedF pendente(s)',
        );
      }

      final relatoriosAtividadesFotosNaoSincronizadas =
          await pendingRelatorioAtividadeFotosForTenantSimple(db);

      if (relatoriosAtividadesFotosNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA RELATORIOS SEM UUID
        for (var relatorioAtividadeFoto
            in relatoriosAtividadesFotosNaoSincronizadas) {
          final u = relatorioAtividadeFoto['uuid']?.toString().trim() ?? '';
          if (u.isEmpty) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_atividade_fotos',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorioAtividadeFoto['id']],
            );
            print(
                '✅ Gerado UUID para relatorio atividade foto: ${relatorioAtividadeFoto['id']} -> $newUuid');
          }
        }

        final relatoriosAtividadesFotosComUuidRaw =
            await pendingRelatorioAtividadeFotosForTenantSimple(db);

        // Não enviar fotos com exclusão lógica local (mesmo valor que no servidor).
        final filtradas = relatoriosAtividadesFotosComUuidRaw.where((r) {
          final s = r['situacao'];
          if (s == null) return true;
          if (s is int) return s != kSituacaoExcluidoLogico;
          return int.tryParse(s.toString()) != kSituacaoExcluidoLogico;
        }).toList();

        final relatoriosAtividadesFotosComUuid = <Map<String, dynamic>>[];
        for (final raw in filtradas) {
          final m = Map<String, dynamic>.from(raw);
          await backfillRelatorioAtividadeUuidForPayloadRow(db, m);
          relatoriosAtividadesFotosComUuid.add(m);
        }

        final relatoriosAtividadesFotosParaEnviar = <Map<String, dynamic>>[];
        final relatoriosComArquivoLocal = <Map<String, dynamic>>[];

        for (final relatorioAtividadeFoto in relatoriosAtividadesFotosComUuid) {
          final arquivo = _nonEmptyStr(relatorioAtividadeFoto['arquivo']) ?? '';
          final raUuidRaw =
              _nonEmptyStr(relatorioAtividadeFoto['relatorio_atividade_uuid']);
          final raUuid = (raUuidRaw ?? '').trim();
          final payload = {
            'uuid': relatorioAtividadeFoto['uuid'],
            'relatorio_atividade_id':
                relatorioAtividadeFoto['relatorio_atividade_id'],
            'relatorio_atividade_uuid': raUuid,
            'nome': relatorioAtividadeFoto['nome'],
            'arquivo': arquivo,
            'created_by': relatorioAtividadeFoto['created_by'] ?? '',
            'created_by_uuid':
                (relatorioAtividadeFoto['created_by'] is String &&
                        (relatorioAtividadeFoto['created_by'] as String)
                            .contains('-'))
                    ? relatorioAtividadeFoto['created_by']
                    : null,
            'created_at': relatorioAtividadeFoto['created_at'],
            'updated_at': relatorioAtividadeFoto['updated_at'],
            'data_hora': _nonEmptyStr(relatorioAtividadeFoto['data_hora']),
            'latitude': _nonEmptyStr(relatorioAtividadeFoto['latitude']),
            'longitude': _nonEmptyStr(relatorioAtividadeFoto['longitude']),
          };

          if (raUuid.isEmpty) {
            print(
                '⚠️ Foto ${relatorioAtividadeFoto['uuid']}: sem relatorio_atividade_uuid; sincronize as atividades do relatório antes.',
            );
            continue;
          }

          if (arquivo.isNotEmpty &&
              !_isHttpUrl(arquivo) &&
              await _arquivoLocalExiste(arquivo)) {
            payload['arquivo'] = _resolvedLocalPath(arquivo);
            relatoriosComArquivoLocal.add(payload);
          } else {
            relatoriosAtividadesFotosParaEnviar.add(payload);
          }
        }

        if (relatoriosAtividadesFotosComUuid.isNotEmpty &&
            relatoriosAtividadesFotosParaEnviar.isEmpty &&
            relatoriosComArquivoLocal.isEmpty) {
          print(
            '⚠️ relatorio_atividade_fotos: ${relatoriosAtividadesFotosComUuid.length} pendente(s) '
            'sem upload — falta relatorio_atividade_uuid ou arquivo local inexistente / só caminho inválido.',
          );
        }

        final uploadUri = _uriRelatorioAtividadeFotosUpload();
        print('📤 POST $uploadUri');

        // 1) Upload em lote (JSON) para fotos que já possuem URL remota.
        if (relatoriosAtividadesFotosParaEnviar.isNotEmpty) {
          print(
              '📤 Enviando ${relatoriosAtividadesFotosParaEnviar.length} fotos (JSON)...');

          final uploadResponse = await http.post(
            uploadUri,
            headers: headers,
            body: json.encode({'dados': relatoriosAtividadesFotosParaEnviar}),
          );

          if (uploadResponse.statusCode == 200) {
            final uploadBody =
                mapaRespostaSyncJson(json.decode(uploadResponse.body));
            final stUpload = serverTimeDoJsonResposta(uploadBody);

            for (final rowSrv in servidorVenceuLwwDoJson(uploadBody)) {
              await _processarOrdemTarefa(rowSrv, stUpload,
                  prioridadeServidor: true);
            }

            final sinc = uploadBody['sincronizados'];
            for (var relatorioAtividadeFoto in (sinc is List ? sinc : const [])) {
              if (relatorioAtividadeFoto is! Map) continue;
              final row = Map<String, dynamic>.from(relatorioAtividadeFoto);
              final uuidVal = row['uuid']?.toString();
              if (uuidVal == null || uuidVal.isEmpty) continue;
              final novoArquivo = row['arquivo']?.toString().trim();
              final url =
                  (novoArquivo != null && novoArquivo.isNotEmpty && _isHttpUrl(novoArquivo))
                      ? novoArquivo
                      : null;
              await _marcarFotoSincronizada(db, uuidVal, novoArquivoHttp: url);
              uploadedCount++;
            }
          } else if (uploadResponse.statusCode == 401) {
            _updateSyncStatus(
                false, 'Token expirado. Faça login novamente.', 0, 0);
            return;
          } else {
            print(
                '❌ Erro no upload JSON: ${uploadResponse.statusCode} - ${uploadResponse.body}');
            hadError = true;
          }
        }

        // 2) Upload multipart para fotos com arquivo local.
        for (final foto in relatoriosComArquivoLocal) {
          try {
            final req = http.MultipartRequest('POST', uploadUri);
            req.headers['Authorization'] = 'Bearer $token';
            req.fields['uuid'] = (foto['uuid'] ?? '').toString().trim();
            req.fields['nome'] = (foto['nome'] ?? '').toString();
            req.fields['updated_at'] = (foto['updated_at'] ?? '').toString();
            req.fields['created_at'] = (foto['created_at'] ?? '').toString();
            req.fields['relatorio_atividade_uuid'] =
                (foto['relatorio_atividade_uuid'] ?? '').toString().trim();
            req.fields['relatorio_atividade_id'] =
                (foto['relatorio_atividade_id'] ?? '').toString();
            final createdByUuid = _nonEmptyStr(foto['created_by_uuid']);
            if (createdByUuid != null) {
              req.fields['created_by_uuid'] = createdByUuid;
            }
            final dh = _nonEmptyStr(foto['data_hora']);
            if (dh != null) {
              req.fields['data_hora'] = dh;
            }
            final la = _nonEmptyStr(foto['latitude']);
            if (la != null) {
              req.fields['latitude'] = la;
            }
            final lo = _nonEmptyStr(foto['longitude']);
            if (lo != null) {
              req.fields['longitude'] = lo;
            }

            req.files.add(await http.MultipartFile.fromPath(
              'arquivo',
              foto['arquivo'].toString(),
              filename: (foto['nome'] ?? 'foto.jpg').toString(),
            ));

            final streamed = await req.send();
            final resp = await http.Response.fromStream(streamed);

            if (resp.statusCode == 200) {
              Map<String, dynamic> uploadBody = {};
              try {
                uploadBody =
                    mapaRespostaSyncJson(json.decode(resp.body));
              } catch (_) {}

              final stUpload = serverTimeDoJsonResposta(uploadBody);
              final reconciliacao =
                  servidorVenceuLwwDoJson(uploadBody);

              if (reconciliacao.isNotEmpty) {
                for (final rowSrv in reconciliacao) {
                  await _processarOrdemTarefa(
                    rowSrv,
                    stUpload,
                    prioridadeServidor: true,
                  );
                }
                uploadedCount++;
                continue;
              }

              String? novoArquivo;
              final list = uploadBody['sincronizados'];
              if (list is List && list.isNotEmpty) {
                final first = list.first;
                if (first is Map && first['arquivo'] != null) {
                  final u = first['arquivo'].toString().trim();
                  if (u.isNotEmpty && _isHttpUrl(u)) novoArquivo = u;
                }
              }
              final uuidMp = foto['uuid']?.toString();
              if (uuidMp != null && uuidMp.isNotEmpty) {
                await _marcarFotoSincronizada(db, uuidMp,
                    novoArquivoHttp: novoArquivo);
              }
              uploadedCount++;
            } else if (resp.statusCode == 401) {
              _updateSyncStatus(
                  false, 'Token expirado. Faça login novamente.', 0, 0);
              return;
            } else {
              final currentCount = _asInt(relatoriosAtividadesFotosComUuid
                      .firstWhere((r) => r['uuid'] == foto['uuid'],
                          orElse: () =>
                              {'sync_try_count': 0})['sync_try_count']) ??
                  0;
              await db.update(
                'relatorio_atividade_fotos',
                {'sync_try_count': currentCount + 1},
                where: 'uuid = ?',
                whereArgs: [foto['uuid']],
              );
              print(
                  '❌ Erro no upload multipart (${foto['uuid']}): ${resp.statusCode} - ${resp.body}');
              hadError = true;
            }
          } catch (e) {
            print('❌ Erro no upload multipart (${foto['uuid']}): $e');
            hadError = true;
          }
        }

        // incrementa tentativas apenas para itens JSON em caso de erro geral dessa etapa
        if (hadError) {
          for (var relatorioAtividadeFoto in relatoriosAtividadesFotosComUuid) {
            if ((await db.query(
                  'relatorio_atividade_fotos',
                  columns: ['synced'],
                  where: 'uuid = ?',
                  whereArgs: [relatorioAtividadeFoto['uuid']],
                  limit: 1,
                ))
                    .firstOrNull?['synced'] !=
                1) {
              final currentCount =
                  _asInt(relatorioAtividadeFoto['sync_try_count']) ?? 0;
              await db.update(
                'relatorio_atividade_fotos',
                {'sync_try_count': currentCount + 1},
                where: 'uuid = ?',
                whereArgs: [relatorioAtividadeFoto['uuid']],
              );
            }
          }
        }

        print(
            '✅ Upload processado: $uploadedCount relatorios atividades fotos');
      } else {
        print('ℹ️ Nenhuma relatorio atividade fotos para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
      hadError = true;
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_atividade_fotos');
      print('📥 Buscando relatorios atividades fotos desde: $lastSync');

      final downloadUri = _uriRelatorioAtividadeFotosDownload();
      print('📥 POST $downloadUri');
      final downloadResponse = await http.post(
        downloadUri,
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosAtividadesFotosDoServidor =
            downloadResult['dados'] as List;

        print(
            '📥 Recebidas ${relatoriosAtividadesFotosDoServidor.length} atividades fotos');

        for (var relatorioAtividadeFotoServer
            in relatoriosAtividadesFotosDoServidor) {
          await _processarOrdemTarefa(
              relatorioAtividadeFotoServer, downloadResult['server_time']);
          downloadedCount++;
        }

        if (relatoriosAtividadesFotosDoServidor.isNotEmpty) {
          await updateLastSyncRelatorioAtividadeFotosSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print(
            '✅ Download concluído: $downloadedCount relatorios atividades fotos');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
        hadError = true;
      }
    } catch (e) {
      print('❌ Erro no download: $e');
      hadError = true;
    }

    if (hadError) {
      _updateSyncStatus(
        false,
        'Sync atividades fotos com erros: ↑$uploadedCount ↓$downloadedCount',
        uploadedCount,
        downloadedCount,
      );
      print('⚠️ Sync relatorios atividades fotos finalizada com erros');
      return;
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync atividades fotos concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios atividades fotos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios atividades fotos: $e');
    _updateSyncStatus(
        false, 'Erro geral sync relatorios atividades fotos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioAtividadeFotoServer,
    String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = relatorioAtividadeFotoServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioAtividadeFotoServer['id'] != null) {
    await _salvarMapeamento('relatorio_atividade_fotos',
        relatorioAtividadeFotoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorio_atividade_fotos',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: relatorioAtividadeFotoServer,
          tabela: 'relatorio_atividade_fotos',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    // UPDATE
    final merged = await _mergeArquivoFotoCampos(
      existingRow: Map<String, dynamic>.from(existe.first),
      serverArquivoRaw: relatorioAtividadeFotoServer['arquivo'],
    );
    final existingFk = _asInt(existe.first['relatorio_atividade_id']);
    final resolvedRaId = await _localRelatorioAtividadeIdParaFoto(
      db,
      relatorioAtividadeFotoServer,
      existingLocalFk: existingFk,
    );
    final raIdSqlite = resolvedRaId ?? existingFk;
    final upd = {
      if (raIdSqlite != null) 'relatorio_atividade_id': raIdSqlite,
      'relatorio_atividade_uuid': _nonEmptyStr(
          relatorioAtividadeFotoServer['relatorio_atividade_uuid']),
      'nome': relatorioAtividadeFotoServer['nome'],
      'arquivo': merged['arquivo'],
      'arquivo_servidor': merged['arquivo_servidor'],
      'created_by': _createdByLocal(relatorioAtividadeFotoServer),
      'created_at': relatorioAtividadeFotoServer['created_at'],
      'synced': 1,
      'last_sync_date': serverTime,
      'updated_at': relatorioAtividadeFotoServer['updated_at'],
      'data_hora': _nonEmptyStr(relatorioAtividadeFotoServer['data_hora']),
      'latitude': _nonEmptyStr(relatorioAtividadeFotoServer['latitude']),
      'longitude': _nonEmptyStr(relatorioAtividadeFotoServer['longitude']),
    };
    upd.removeWhere((k, v) => v == null);
    await db.update(
      'relatorio_atividade_fotos',
      upd,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    final mergedIns = await _mergeArquivoFotoCampos(
      existingRow: null,
      serverArquivoRaw: relatorioAtividadeFotoServer['arquivo'],
    );
    final resolvedIns = await _localRelatorioAtividadeIdParaFoto(
      db,
      relatorioAtividadeFotoServer,
    );
    final raIns = resolvedIns ??
        _asInt(relatorioAtividadeFotoServer['relatorio_atividade_id']);
    final ins = {
      'uuid': uuid,
      'relatorio_atividade_id': raIns,
      'relatorio_atividade_uuid': _nonEmptyStr(
          relatorioAtividadeFotoServer['relatorio_atividade_uuid']),
      'nome': relatorioAtividadeFotoServer['nome'],
      'arquivo': mergedIns['arquivo'],
      'arquivo_servidor': mergedIns['arquivo_servidor'],
      'created_by': _createdByLocal(relatorioAtividadeFotoServer),
      'created_at': relatorioAtividadeFotoServer['created_at'],
      'synced': 1,
      'last_sync_date': serverTime,
      'updated_at': relatorioAtividadeFotoServer['updated_at'],
      'data_hora': _nonEmptyStr(relatorioAtividadeFotoServer['data_hora']),
      'latitude': _nonEmptyStr(relatorioAtividadeFotoServer['latitude']),
      'longitude': _nonEmptyStr(relatorioAtividadeFotoServer['longitude']),
    };
    ins.removeWhere((k, v) => v == null);
    await db.insert(
      'relatorio_atividade_fotos',
      ins,
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
    return FFAppState().UserToken;
  } catch (e) {
    return '';
  }
}

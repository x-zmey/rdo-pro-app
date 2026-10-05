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

import 'index.dart'; // Imports other custom actions

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import '/backend/sqlite/situacao_soft_delete.dart';

import 'sync_relatorio_download_merge_guard.dart';

const String _kUrlUploadRelatorioOcorrencias =
    '$kApiBaseUrl/api/v1/sync/relatorios/ocorrencias/upload';
const String _kUrlDownloadRelatorioOcorrencias =
    '$kApiBaseUrl/api/v1/sync/relatorios/ocorrencias/download';

Uri _uriRelatorioOcorrenciasUpload() =>
    Uri.parse(_kUrlUploadRelatorioOcorrencias.trim());

Uri _uriRelatorioOcorrenciasDownload() =>
    Uri.parse(_kUrlDownloadRelatorioOcorrencias.trim());

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

Future<String> _getUltimaSync(String tabela) async {
  return lastSyncDateForCurrentCreator(tabela);
}

String _generateUuid() {
  final random = Random();
  final hexDigits = '0123456789abcdef';
  String generatePart(int length) =>
      List.generate(length, (_) => hexDigits[random.nextInt(16)]).join();
  return '${generatePart(8)}-${generatePart(4)}-4${generatePart(3)}-${generatePart(4)}-${generatePart(12)}';
}

String? _nonEmptyStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

Future<String?> _buscarTipoUuidPorId(int? tipoId) async {
  if (tipoId == null) return null;
  final db = await SQLiteManager.instance.database;
  final rows = await db.query(
    'tipo_ocorrencias',
    columns: ['uuid'],
    where: 'id = ?',
    whereArgs: [tipoId],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return _nonEmptyStr(rows.first['uuid']);
}

Future<int?> _buscarTipoIdPorUuid(String? tipoUuid) async {
  if (tipoUuid == null || tipoUuid.isEmpty) return null;
  final db = await SQLiteManager.instance.database;
  final rows = await db.query(
    'tipo_ocorrencias',
    columns: ['id'],
    where: 'uuid = ?',
    whereArgs: [tipoUuid],
    limit: 1,
  );
  if (rows.isEmpty) return null;
  return _asInt(rows.first['id']);
}

Future syncRelatorioOcorrencias() async {
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

    try {
      await stampPendingRelatorioOcorrenciasCreatedByTenantFallback(db);

      var naoSincronizadas =
          await pendingRelatorioOcorrenciasForTenantSimple(db);

      if (naoSincronizadas.isNotEmpty) {
        for (final ocorrencia in naoSincronizadas) {
          if (ocorrencia['uuid'] == null ||
              (ocorrencia['uuid'] as String?)?.trim().isEmpty == true) {
            await db.update(
              'relatorio_ocorrencias',
              {'uuid': _generateUuid()},
              where: 'id = ?',
              whereArgs: [ocorrencia['id']],
            );
          }
        }

        final comUuid = await pendingRelatorioOcorrenciasForTenantSimple(db);

        final payload = <Map<String, dynamic>>[];
        for (final rowRaw in comUuid) {
          final row = Map<String, dynamic>.from(rowRaw);
          await backfillRelatorioUuidForPayloadRow(db, row);
          int? tipoId = _asInt(row['tipo_id']);
          String? tipoUuid = _nonEmptyStr(row['tipo_uuid']);
          if (tipoUuid == null && tipoId != null) {
            tipoUuid = await _buscarTipoUuidPorId(tipoId);
          }
          if (tipoId == null && tipoUuid != null) {
            tipoId = await _buscarTipoIdPorUuid(tipoUuid);
          }
          payload.add({
            'uuid': row['uuid'],
            'user_id': row['user_id'],
            'user_uuid': row['user_uuid'],
            'relatorio_id': row['relatorio_id'],
            'relatorio_uuid': row['relatorio_uuid'],
            'tipo_id': tipoId,
            'tipo_uuid': tipoUuid,
            'descricao': row['descricao'],
            'hora_inicio': row['hora_inicio'],
            'hora_saida': row['hora_saida'],
            'atividade_id': row['atividade_id'],
            'created_by_uuid': row['created_by'],
            'situacao': row['situacao'],
            'created_at': row['created_at'],
            'updated_at': row['updated_at'],
          });
        }

        print('📤 Enviando ${payload.length} relatorios ocorrencias...');
        print('📤 POST ${_uriRelatorioOcorrenciasUpload()}');
        final uploadResponse = await http.post(
          _uriRelatorioOcorrenciasUpload(),
          headers: headers,
          body: json.encode({'dados': payload}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadBody =
              mapaRespostaSyncJson(json.decode(uploadResponse.body));
          final stUpload = serverTimeDoJsonResposta(uploadBody);

          for (final rowSrv in servidorVenceuLwwDoJson(uploadBody)) {
            await _processarOcorrencia(
              rowSrv,
              stUpload,
              prioridadeServidor: true,
            );
          }

          final sincronizados =
              (uploadBody['sincronizados'] as List?) ?? [];
          for (final row in sincronizados) {
            if (row is! Map) continue;
            final u = row['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_ocorrencias',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [u],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount ocorrencias');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
          return;
        } else {
          for (final row in comUuid) {
            final currentCount = _asInt(row['sync_try_count']) ?? 0;
            await db.update(
              'relatorio_ocorrencias',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [row['uuid']],
            );
          }
          print(
              '❌ Erro no upload: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhuma ocorrencia para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    try {
      final lastSync = await _getUltimaSync('relatorio_ocorrencias');
      print('📥 Buscando relatorios ocorrencias desde: $lastSync');
      print('📥 POST ${_uriRelatorioOcorrenciasDownload()}');

      final downloadResponse = await http.post(
        _uriRelatorioOcorrenciasDownload(),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final dados = (downloadResult['dados'] as List?) ?? [];
        print('📥 Recebidas ${dados.length} ocorrencias');

        for (final ocorrenciaServer in dados) {
          await _processarOcorrencia(
            Map<String, dynamic>.from(ocorrenciaServer as Map),
            _nonEmptyStr(downloadResult['server_time']) ??
                DateTime.now().toIso8601String(),
          );
          downloadedCount++;
        }

        if (dados.isNotEmpty) {
          await updateLastSyncRelatorioOcorrenciasSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print('✅ Download concluído: $downloadedCount ocorrencias');
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

    _updateSyncStatus(
      true,
      'Sync ocorrencias concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios ocorrencias concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios ocorrencias: $e');
    _updateSyncStatus(
      false,
      'Erro geral sync relatorios ocorrencias: $e',
      0,
      0,
    );
  }
}

Future<void> _processarOcorrencia(
    Map<String, dynamic> ocorrenciaServer, String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  final uuid = _nonEmptyStr(ocorrenciaServer['uuid']) ?? _generateUuid();
  final serverId = _asInt(ocorrenciaServer['id']);
  if (serverId != null) {
    await _salvarMapeamento('relatorio_ocorrencias', serverId, uuid);
  }

  final existe = await db.query(
    'relatorio_ocorrencias',
    where: 'uuid = ?',
    whereArgs: [uuid],
    limit: 1,
  );
  final atual =
      existe.isNotEmpty ? Map<String, dynamic>.from(existe.first) : {};

  int? tipoId = _asInt(ocorrenciaServer['tipo_id']) ?? _asInt(atual['tipo_id']);
  final tipoUuid = _nonEmptyStr(ocorrenciaServer['tipo_uuid']);
  if (tipoId == null && tipoUuid != null) {
    tipoId = await _buscarTipoIdPorUuid(tipoUuid);
  }

  final row = <String, dynamic>{
    'user_id':
        _asInt(ocorrenciaServer['user_id']) ?? _asInt(atual['user_id']) ?? 0,
    'user_uuid': _nonEmptyStr(ocorrenciaServer['user_uuid']) ??
        _nonEmptyStr(atual['user_uuid']) ??
        '',
    'relatorio_id': _asInt(ocorrenciaServer['relatorio_id']) ??
        _asInt(atual['relatorio_id']) ??
        0,
    'relatorio_uuid': _nonEmptyStr(ocorrenciaServer['relatorio_uuid']) ??
        _nonEmptyStr(atual['relatorio_uuid']) ??
        '',
    'tipo_id': tipoId ?? 0,
    'descricao': _nonEmptyStr(ocorrenciaServer['descricao']),
    'hora_inicio': _nonEmptyStr(ocorrenciaServer['hora_inicio']),
    'hora_saida': _nonEmptyStr(ocorrenciaServer['hora_saida']),
    'atividade_id': _asInt(ocorrenciaServer['atividade_id']),
    'created_by': _nonEmptyStr(ocorrenciaServer['created_by_uuid']) ??
        _nonEmptyStr(ocorrenciaServer['created_by']) ??
        _nonEmptyStr(atual['created_by']) ??
        '',
    'situacao':
        _asInt(ocorrenciaServer['situacao']) ??
            _asInt(atual['situacao']) ??
            kSituacaoAtivo,
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': _nonEmptyStr(ocorrenciaServer['created_at']) ??
        _nonEmptyStr(atual['created_at']),
    'updated_at': _nonEmptyStr(ocorrenciaServer['updated_at']) ??
        _nonEmptyStr(atual['updated_at']) ??
        serverTime,
  };

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: ocorrenciaServer,
          tabela: 'relatorio_ocorrencias',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    await db.update(
      'relatorio_ocorrencias',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    await db.insert('relatorio_ocorrencias', {'uuid': uuid, ...row});
  }
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
    return FFAppState().UserToken;
  } catch (e) {
    return '';
  }
}

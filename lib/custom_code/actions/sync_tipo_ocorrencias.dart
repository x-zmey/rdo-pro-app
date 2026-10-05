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

import '/backend/sqlite/situacao_soft_delete.dart';

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

Future syncTipoOcorrencias() async {
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
      final naoSincronizadas = await db.query(
        'tipo_ocorrencias',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (naoSincronizadas.isNotEmpty) {
        for (final tipo in naoSincronizadas) {
          if (_nonEmptyStr(tipo['uuid']) == null) {
            await db.update(
              'tipo_ocorrencias',
              {'uuid': _generateUuid()},
              where: 'id = ?',
              whereArgs: [tipo['id']],
            );
          }
        }

        final comUuid = await db.query(
          'tipo_ocorrencias',
          where: 'synced = ?',
          whereArgs: [0],
        );

        final payload = comUuid.map((row) {
          return {
            'uuid': row['uuid'],
            'user_id': row['user_id'],
            'user_uuid': row['user_uuid'],
            'nome': row['nome'],
            'created_by_uuid': row['created_by'],
            'situacao': row['situacao'],
            'created_at': row['created_at'],
            'updated_at': row['updated_at'],
          };
        }).toList();

        print('📤 Enviando ${payload.length} tipos de ocorrencia...');
        final uploadResponse = await http.post(
          Uri.parse(
              '$kApiBaseUrl/api/v1/sync/tipo-ocorrencias/upload'),
          headers: headers,
          body: json.encode({'dados': payload}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);
          final sincronizados = (uploadResult['sincronizados'] as List?) ?? [];
          for (final row in sincronizados) {
            await db.update(
              'tipo_ocorrencias',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [row['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount tipos de ocorrencia');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
          return;
        } else {
          for (final row in comUuid) {
            final currentCount = _asInt(row['sync_try_count']) ?? 0;
            await db.update(
              'tipo_ocorrencias',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [row['uuid']],
            );
          }
          print(
              '❌ Erro no upload: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhum tipo de ocorrencia para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    try {
      final lastSync = await _getUltimaSync('tipo_ocorrencias');
      print('📥 Buscando tipos de ocorrencia desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/tipo-ocorrencias/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final dados = (downloadResult['dados'] as List?) ?? [];
        print('📥 Recebidos ${dados.length} tipos de ocorrencia');

        for (final tipoServer in dados) {
          await _processarTipoOcorrencia(
            Map<String, dynamic>.from(tipoServer as Map),
            _nonEmptyStr(downloadResult['server_time']) ??
                DateTime.now().toIso8601String(),
          );
          downloadedCount++;
        }

        if (dados.isNotEmpty) {
          await db.update(
            'tipo_ocorrencias',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount tipos de ocorrencia');
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
      'Sync tipo ocorrencias concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync tipo ocorrencias concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync tipo ocorrencias: $e');
    _updateSyncStatus(
      false,
      'Erro geral sync tipo ocorrencias: $e',
      0,
      0,
    );
  }
}

Future<void> _processarTipoOcorrencia(
    Map<String, dynamic> tipoServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuid = _nonEmptyStr(tipoServer['uuid']) ?? _generateUuid();
  final serverId = _asInt(tipoServer['id']);
  if (serverId != null) {
    await _salvarMapeamento('tipo_ocorrencias', serverId, uuid);
  }

  final existe = await db.query(
    'tipo_ocorrencias',
    where: 'uuid = ?',
    whereArgs: [uuid],
    limit: 1,
  );
  final atual =
      existe.isNotEmpty ? Map<String, dynamic>.from(existe.first) : {};

  final row = <String, dynamic>{
    'user_id': _asInt(tipoServer['user_id']) ?? _asInt(atual['user_id']) ?? 0,
    'user_uuid': _nonEmptyStr(tipoServer['user_uuid']) ??
        _nonEmptyStr(atual['user_uuid']) ??
        '',
    'nome':
        _nonEmptyStr(tipoServer['nome']) ?? _nonEmptyStr(atual['nome']) ?? '',
    'created_by': _nonEmptyStr(tipoServer['created_by_uuid']) ??
        _nonEmptyStr(tipoServer['created_by']) ??
        _nonEmptyStr(atual['created_by']) ??
        '',
    'situacao':
        _asInt(tipoServer['situacao']) ??
            _asInt(atual['situacao']) ??
            kSituacaoAtivo,
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': _nonEmptyStr(tipoServer['created_at']) ??
        _nonEmptyStr(atual['created_at']),
    'updated_at': _nonEmptyStr(tipoServer['updated_at']) ??
        _nonEmptyStr(atual['updated_at']) ??
        serverTime,
  };

  if (existe.isNotEmpty) {
    await db.update(
      'tipo_ocorrencias',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    await db.insert('tipo_ocorrencias', {'uuid': uuid, ...row});
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

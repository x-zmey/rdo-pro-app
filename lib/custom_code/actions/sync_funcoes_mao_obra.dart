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
import 'package:sqflite/sqflite.dart';

import '/backend/sqlite/situacao_soft_delete.dart';

Future<String> _getUltimaSync(String tabela) async {
  return lastSyncDateForCurrentCreator(tabela);
}

String _nonEmptyStr(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  return s.isEmpty ? '' : s;
}

String _createdBy(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().trim().isNotEmpty) {
    return u.toString().trim();
  }
  final creator = FFAppState().creatorUuid.trim();
  if (creator.isNotEmpty) {
    return creator;
  }
  final legacy = row['created_by'];
  if (legacy == null) return '';
  return legacy.toString();
}

int _parseSituacao(dynamic v) {
  if (v == null) return kSituacaoAtivo;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? kSituacaoAtivo;
}

Future syncFuncoesMaoObra() async {
  try {
    final db = SQLiteManager.instance.database;
    final token = FFAppState().UserToken;

    if (token.isEmpty) {
      _updateSyncStatus(false, 'Usuário não autenticado', 0, 0);
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    int downloadedCount = 0;
    final lastSync = await _getUltimaSync('funcoes_mao_obra');

    final downloadResponse = await http.post(
      Uri.parse(
          '$kApiBaseUrl/api/v1/sync/funcoes-mao-obra/download'),
      headers: headers,
      body: json.encode({'ultima_sync': lastSync}),
    );

    if (downloadResponse.statusCode == 200) {
      final downloadResult =
          json.decode(downloadResponse.body) as Map<String, dynamic>;
      final rawDados = downloadResult['dados'];
      final funcoesDoServidor = rawDados is List ? rawDados : <dynamic>[];
      final serverTime = downloadResult['server_time']?.toString() ??
          DateTime.now().toIso8601String();

      for (var funcaoServer in funcoesDoServidor) {
        if (funcaoServer is Map<String, dynamic>) {
          await _processarFuncao(funcaoServer, serverTime);
          downloadedCount++;
        }
      }

      if (funcoesDoServidor.isNotEmpty) {
        await db.update(
          'funcoes_mao_obra',
          {'last_sync_date': serverTime},
          where: 'synced = ?',
          whereArgs: [1],
        );
      }
    } else if (downloadResponse.statusCode == 401) {
      _updateSyncStatus(false, 'Token expirado. Faça login novamente.', 0, 0);
      return;
    }

    _updateSyncStatus(
      true,
      'Sync funções de mão de obra concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
  } catch (e) {
    _updateSyncStatus(false, 'Erro geral sync funções de mão de obra: $e', 0, 0);
  }
}

Future<void> _processarFuncao(
    Map<String, dynamic> funcaoServer, String serverTime) async {
  final db = SQLiteManager.instance.database;

  final idServidor = funcaoServer['id'] is int
      ? funcaoServer['id'] as int
      : int.tryParse('${funcaoServer['id']}');
  if (idServidor == null) return;

  final nome = _nonEmptyStr(funcaoServer['nome']);
  if (nome.isEmpty) return;

  final owner = _createdBy(funcaoServer);
  final situacao = _parseSituacao(funcaoServer['situacao']);

  final exists = await db.query(
    'funcoes_mao_obra',
    where: 'id = ?',
    whereArgs: [idServidor],
    limit: 1,
  );

  final row = <String, dynamic>{
    'nome': nome,
    'created_by': owner.isEmpty ? null : owner,
    'situacao': situacao,
    'synced': 1,
    'sync_try_count': 0,
    'last_sync_date': serverTime,
    'created_at': funcaoServer['created_at'],
    'updated_at': funcaoServer['updated_at'],
  };

  if (exists.isNotEmpty) {
    await db.update(
      'funcoes_mao_obra',
      row,
      where: 'id = ?',
      whereArgs: [idServidor],
    );
  } else {
    await db.insert(
      'funcoes_mao_obra',
      {
        'id': idServidor,
        ...row,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
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
  } catch (_) {}
}

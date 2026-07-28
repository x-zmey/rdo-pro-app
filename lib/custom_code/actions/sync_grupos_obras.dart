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

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

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
      print('❌ Erro ao salvar mapeamento grupo_obra: $e');
    }
  }
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

String _nonEmptyStr(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  return s.isEmpty ? '' : s;
}

String _createdByLocal(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().isNotEmpty) return u.toString();
  final legacy = row['created_by'];
  if (legacy == null) return '0';
  final s = legacy.toString();
  return s.isEmpty ? '0' : s;
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncGruposObras() async {
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

    int downloadedCount = 0;

    // ===== DOWNLOAD - Buscar atualizações do servidor =====
    try {
      final lastSync = await _getUltimaSync('grupo_obra');
      print('📥 Buscando grupos de obras desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/obras/grupos/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final gruposDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${gruposDoServidor.length} grupos de obras');

        for (var grupoServer in gruposDoServidor) {
          await _processarGrupoObra(grupoServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (gruposDoServidor.isNotEmpty) {
          await db.update(
            'grupo_obra',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount grupos de obras');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(false, 'Token expirado. Faça login novamente.', 0, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
        print('❌ Body do erro: ${downloadResponse.body}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
      _updateSyncStatus(false, 'Erro no download: $e', 0, 0);
      return;
    }

    // ===== SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync grupos concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync grupos de obras concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync grupos: $e');
    _updateSyncStatus(false, 'Erro geral sync grupos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE GRUPO OBRA =====

Future<void> _processarGrupoObra(
    Map<String, dynamic> grupoServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = grupoServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (grupoServer['id'] != null) {
    await _salvarMapeamento('grupo_obra', grupoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'grupo_obra',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'grupo_obra',
      {
        'user_id': grupoServer['user_id'],
        'user_uuid': _nonEmptyStr(grupoServer['user_uuid']),
        'nome': grupoServer['nome'],
        'created_by': _createdByLocal(grupoServer),
        'situacao': grupoServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': grupoServer['created_at'],
        'updated_at': grupoServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Grupo atualizado: ${grupoServer['nome']}');
  } else {
    // INSERT
    await db.insert(
      'grupo_obra',
      {
        'uuid': uuid,
        'user_id': grupoServer['user_id'],
        'user_uuid': _nonEmptyStr(grupoServer['user_uuid']),
        'nome': grupoServer['nome'],
        'created_by': _createdByLocal(grupoServer),
        'situacao': grupoServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': grupoServer['created_at'],
        'updated_at': grupoServer['updated_at'],
      },
    );
    print('✅ Novo grupo inserido: ${grupoServer['nome']}');
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

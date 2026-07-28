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
      print('❌ Erro ao salvar mapeamento obra_etapas: $e');
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

Future syncObrasEtapas() async {
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
      final lastSync = await _getUltimaSync('obra_etapas');
      print('📥 Buscando etapas desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/obras/etapas/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final etapasDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${etapasDoServidor.length} etapas');

        for (var etapaServer in etapasDoServidor) {
          await _processarEtapa(etapaServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (etapasDoServidor.isNotEmpty) {
          await db.update(
            'obra_etapas',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount etapas');
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
      'Sync etapas concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync etapas concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync etapas: $e');
    _updateSyncStatus(false, 'Erro geral sync etapas: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ETAPA =====

Future<void> _processarEtapa(
    Map<String, dynamic> etapaServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = etapaServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (etapaServer['id'] != null) {
    await _salvarMapeamento('obra_etapas', etapaServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'obra_etapas',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'obra_etapas',
      {
        'user_id': etapaServer['user_id'],
        'user_uuid': _nonEmptyStr(etapaServer['user_uuid']),
        'obra_id': etapaServer['obra_id'],
        'obra_uuid': _nonEmptyStr(etapaServer['obra_uuid']),
        'item': etapaServer['item'],
        'nome': etapaServer['nome'],
        'created_by': _createdByLocal(etapaServer),
        'situacao': etapaServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': etapaServer['created_at'],
        'updated_at': etapaServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Etapa atualizada: ${etapaServer['nome']}');
  } else {
    // INSERT
    await db.insert(
      'obra_etapas',
      {
        'uuid': uuid,
        'user_id': etapaServer['user_id'],
        'user_uuid': _nonEmptyStr(etapaServer['user_uuid']),
        'obra_id': etapaServer['obra_id'],
        'obra_uuid': _nonEmptyStr(etapaServer['obra_uuid']),
        'item': etapaServer['item'],
        'nome': etapaServer['nome'],
        'created_by': _createdByLocal(etapaServer),
        'situacao': etapaServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': etapaServer['created_at'],
        'updated_at': etapaServer['updated_at'],
      },
    );
    print('✅ Nova etapa inserida: ${etapaServer['nome']}');
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

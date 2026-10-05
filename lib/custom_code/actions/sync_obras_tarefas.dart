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
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:math';

/// Preferência legada (one-shot). Recovery contínuo = full resync diário.
const String _kObraTarefasFullResyncV2 = 'obra_etapa_tarefas_full_resync_v2';
const String _kDailyScope = 'obra_etapa_tarefas';

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
      print('❌ Erro ao salvar mapeamento obra_etapa_tarefas: $e');
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

String _createdByLocal(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().isNotEmpty) return u.toString();
  final legacy = row['created_by'];
  if (legacy == null) return '0';
  final s = legacy.toString();
  return s.isEmpty ? '0' : s;
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncObrasTarefas() async {
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
      final prefs = await SharedPreferences.getInstance();
      final alreadyRepaired = prefs.getBool(_kObraTarefasFullResyncV2) ?? false;
      final needsDaily = await shouldForceDailyFullResync(_kDailyScope);
      final forceFull = !alreadyRepaired || needsDaily;
      final lastSync =
          forceFull ? kSyncEpoch : await _getUltimaSync('obra_etapa_tarefas');
      print(
          '📥 Buscando tarefas desde: $lastSync${forceFull ? ' (resync completo)' : ''}');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/obras/etapa-tarefas/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final tarefasDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${tarefasDoServidor.length} tarefas');

        for (var tarefaServer in tarefasDoServidor) {
          await _processarTarefa(tarefaServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (tarefasDoServidor.isNotEmpty) {
          await db.update(
            'obra_etapa_tarefas',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        if (forceFull) {
          await prefs.setBool(_kObraTarefasFullResyncV2, true);
          await markDailyFullResyncDone(_kDailyScope);
        }
        print('✅ Download concluído: $downloadedCount tarefas');
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
      'Sync tarefas concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync tarefas concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync tarefas: $e');
    _updateSyncStatus(false, 'Erro geral sync tarefas: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE TAREFA =====

Future<void> _processarTarefa(
    Map<String, dynamic> tarefaServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = tarefaServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (tarefaServer['id'] != null) {
    await _salvarMapeamento(
        'obra_etapa_tarefas', tarefaServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'obra_etapa_tarefas',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'obra_etapa_tarefas',
      {
        'obra_etapa_id': tarefaServer['obra_etapa_id'],
        'etapa_uuid': tarefaServer['etapa_uuid'],
        'tarefa_pai': tarefaServer['tarefa_pai'],
        'tarefa_pai_uuid': tarefaServer['tarefa_pai_uuid'],
        'item': tarefaServer['item'],
        'tipo': tarefaServer['tipo'],
        'local': tarefaServer['local'],
        'descricao': tarefaServer['descricao'],
        'qtd': tarefaServer['qtd'],
        'unidade': tarefaServer['unidade'],
        'valor_unitario': tarefaServer['valor_unitario'],
        'meta': tarefaServer['meta'],
        'meta_unidade': tarefaServer['meta_unidade'],
        'qtd_realizada': tarefaServer['qtd_realizada'],
        'porcentagem': tarefaServer['porcentagem'],
        'status': tarefaServer['status'],
        'situacao': tarefaServer['situacao'],
        'created_by': _createdByLocal(tarefaServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': tarefaServer['created_at'],
        'updated_at': tarefaServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Tarefa atualizada: ${tarefaServer['descricao']}');
  } else {
    // INSERT
    await db.insert(
      'obra_etapa_tarefas',
      {
        'uuid': uuid,
        'obra_etapa_id': tarefaServer['obra_etapa_id'],
        'etapa_uuid': tarefaServer['etapa_uuid'],
        'tarefa_pai': tarefaServer['tarefa_pai'],
        'tarefa_pai_uuid': tarefaServer['tarefa_pai_uuid'],
        'item': tarefaServer['item'],
        'tipo': tarefaServer['tipo'],
        'local': tarefaServer['local'],
        'descricao': tarefaServer['descricao'],
        'qtd': tarefaServer['qtd'],
        'unidade': tarefaServer['unidade'],
        'valor_unitario': tarefaServer['valor_unitario'],
        'meta': tarefaServer['meta'],
        'meta_unidade': tarefaServer['meta_unidade'],
        'qtd_realizada': tarefaServer['qtd_realizada'],
        'porcentagem': tarefaServer['porcentagem'],
        'status': tarefaServer['status'],
        'situacao': tarefaServer['situacao'],
        'created_by': _createdByLocal(tarefaServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': tarefaServer['created_at'],
        'updated_at': tarefaServer['updated_at'],
      },
    );
    print('✅ Nova tarefa inserida: ${tarefaServer['descricao']}');
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

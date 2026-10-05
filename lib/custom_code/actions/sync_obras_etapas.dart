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
const String _kObraEtapasFullResyncV2 = 'obra_etapas_full_resync_v2';
const String _kDailyScope = 'obra_etapas';

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
      final prefs = await SharedPreferences.getInstance();
      final alreadyRepaired = prefs.getBool(_kObraEtapasFullResyncV2) ?? false;
      final needsDaily = await shouldForceDailyFullResync(_kDailyScope);
      final forceFull = !alreadyRepaired || needsDaily;
      final lastSync =
          forceFull ? kSyncEpoch : await _getUltimaSync('obra_etapas');
      print(
          '📥 Buscando etapas desde: $lastSync${forceFull ? ' (resync completo)' : ''}');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/obras/etapas/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final etapasDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${etapasDoServidor.length} etapas');

        for (var etapaServer in etapasDoServidor) {
          await _processarEtapa(
            Map<String, dynamic>.from(etapaServer as Map),
            downloadResult['server_time']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
            touchLastSync: true,
          );
          downloadedCount++;
        }

        // Watermark = updated_at do registro (não "agora" em massa).
        // Mantém server_time só como referência do creator sync helper.
        if (etapasDoServidor.isNotEmpty) {
          await db.update(
            'obra_etapas',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        if (forceFull) {
          await prefs.setBool(_kObraEtapasFullResyncV2, true);
          await markDailyFullResyncDone(_kDailyScope);
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
  Map<String, dynamic> etapaServer,
  String serverTime, {
  String? forceObraUuid,
  bool touchLastSync = true,
}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = etapaServer['uuid']?.toString() ?? _generateUuid();
  if (uuid.trim().isEmpty || uuid.toLowerCase() == 'null') {
    uuid = _generateUuid();
  }

  final sid = etapaServer['id'];
  final sidInt = sid is int
      ? sid
      : (sid is num ? sid.toInt() : int.tryParse(sid?.toString() ?? ''));
  if (sidInt != null) {
    await _salvarMapeamento('obra_etapas', sidInt, uuid);
  }

  final existe = await db.query(
    'obra_etapas',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final obraUuid = (forceObraUuid ?? '').trim().isNotEmpty
      ? forceObraUuid!.trim()
      : _nonEmptyStr(etapaServer['obra_uuid']);

  final rowComum = <String, dynamic>{
    'user_id': etapaServer['user_id'],
    'user_uuid': _nonEmptyStr(etapaServer['user_uuid']),
    'obra_id': etapaServer['obra_id'],
    'obra_uuid': obraUuid,
    'item': etapaServer['item'],
    'nome': etapaServer['nome'],
    'created_by': _createdByLocal(etapaServer),
    'situacao': etapaServer['situacao'],
    'synced': 1,
    'created_at': etapaServer['created_at'],
    'updated_at': etapaServer['updated_at'],
  };
  if (touchLastSync) {
    rowComum['last_sync_date'] = serverTime;
  }

  if (existe.isNotEmpty) {
    await db.update(
      'obra_etapas',
      rowComum,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    await db.insert(
      'obra_etapas',
      {
        'uuid': uuid,
        ...rowComum,
        if (!touchLastSync) 'last_sync_date': serverTime,
      },
    );
  }
}

Future<void> _processarTarefaLocal(
  Map<String, dynamic> tarefaServer,
  String serverTime, {
  String? forceEtapaUuid,
  bool touchLastSync = true,
}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = tarefaServer['uuid']?.toString() ?? _generateUuid();
  if (uuid.trim().isEmpty || uuid.toLowerCase() == 'null') {
    uuid = _generateUuid();
  }

  final sid = tarefaServer['id'];
  final sidInt = sid is int
      ? sid
      : (sid is num ? sid.toInt() : int.tryParse(sid?.toString() ?? ''));
  if (sidInt != null) {
    await _salvarMapeamento('obra_etapa_tarefas', sidInt, uuid);
  }

  final existe = await db.query(
    'obra_etapa_tarefas',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final etapaUuid = (forceEtapaUuid ?? '').trim().isNotEmpty
      ? forceEtapaUuid!.trim()
      : _nonEmptyStr(tarefaServer['etapa_uuid']);

  final rowComum = <String, dynamic>{
    'obra_etapa_id': tarefaServer['obra_etapa_id'],
    'etapa_uuid': etapaUuid,
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
    'created_at': tarefaServer['created_at'],
    'updated_at': tarefaServer['updated_at'],
  };
  if (touchLastSync) {
    rowComum['last_sync_date'] = serverTime;
  }

  if (existe.isNotEmpty) {
    await db.update(
      'obra_etapa_tarefas',
      rowComum,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    await db.insert(
      'obra_etapa_tarefas',
      {
        'uuid': uuid,
        ...rowComum,
        if (!touchLastSync) 'last_sync_date': serverTime,
      },
    );
  }

  final filhos = tarefaServer['filhos'];
  if (filhos is List) {
    for (final f in filhos.whereType<Map>()) {
      final filho = Map<String, dynamic>.from(f);
      filho['etapa_uuid'] = etapaUuid;
      await _processarTarefaLocal(
        filho,
        serverTime,
        forceEtapaUuid: etapaUuid,
        touchLastSync: touchLastSync,
      );
    }
  }
}

/// Baixa `/obras/{uuid}/list-etapas` (mesma fonte da aba Tarefas) e grava no SQLite.
Future<void> refreshEtapasTarefasPorObra({required String obraUuid}) async {
  final uuid = obraUuid.trim();
  if (uuid.isEmpty) return;

  final token = await _getAuthToken();
  if (token.isEmpty) return;

  final online = await checkInternetConnection();
  if (!online) return;

  try {
    final response = await http.get(
      Uri.parse('$kApiBaseUrl/api/obras/$uuid/list-etapas'),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      print(
          '⚠️ refreshEtapasTarefasPorObra HTTP ${response.statusCode}: ${response.body}');
      return;
    }

    final dynamic body =
        response.body.isNotEmpty ? json.decode(response.body) : null;
    List etapas = const [];
    if (body is Map) {
      final er = body['etapasResult'] ?? body['etapas'] ?? body['data'];
      if (er is List) etapas = er;
    } else if (body is List) {
      etapas = body;
    }

    final now = DateTime.now().toUtc().toIso8601String();
    var nEtapas = 0;
    var nTarefas = 0;
    for (final raw in etapas.whereType<Map>()) {
      final etapa = Map<String, dynamic>.from(raw);
      etapa['obra_uuid'] = uuid;
      await _processarEtapa(
        etapa,
        now,
        forceObraUuid: uuid,
        touchLastSync: false,
      );
      nEtapas++;
      final etapaUuid = _nonEmptyStr(etapa['uuid']);
      final tarefas = etapa['tarefas'];
      if (tarefas is List) {
        for (final t in tarefas.whereType<Map>()) {
          final tarefa = Map<String, dynamic>.from(t);
          tarefa['etapa_uuid'] = etapaUuid;
          await _processarTarefaLocal(
            tarefa,
            now,
            forceEtapaUuid: etapaUuid,
            touchLastSync: false,
          );
          nTarefas++;
        }
      }
    }

    print(
        '✅ refreshEtapasTarefasPorObra: $nEtapas etapas / $nTarefas tarefas da obra $uuid');
  } catch (e) {
    print('⚠️ refreshEtapasTarefasPorObra: $e');
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

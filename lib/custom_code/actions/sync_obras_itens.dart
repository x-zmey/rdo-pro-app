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
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:math';

/// Preferência legada (one-shot). O recovery contínuo é o full resync diário.
const String _kObraItensFullResyncV2 = 'obra_itens_full_resync_v2';
const String _kDailyScope = 'obra_itens';

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
      print('❌ Erro ao salvar mapeamento obra_itens: $e');
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

String? _nullableStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty || s.toLowerCase() == 'null') return null;
  return s;
}

num _asNum(dynamic v, [num defaultVal = 0]) {
  if (v == null) return defaultVal;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? defaultVal;
}

String _createdByLocal(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().isNotEmpty) return u.toString();
  final legacy = row['created_by'];
  if (legacy == null) return '0';
  final s = legacy.toString();
  return s.isEmpty ? '0' : s;
}

int? _serverId(Map<String, dynamic> row) {
  final v = row['id'];
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

List<Map<String, dynamic>> _extractItensList(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (body is Map) {
    for (final key in ['dados', 'data', 'value', 'itens']) {
      final c = body[key];
      if (c is List) {
        return c
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
  }
  return <Map<String, dynamic>>[];
}

/// Preenche `obra_uuid` quando o sync antigo gravou só `obra_id` (server).
Future<int> _backfillObraUuidLocal(Database db) async {
  var total = 0;
  try {
    total += await db.rawUpdate('''
UPDATE obra_itens
SET obra_uuid = (
  SELECT m.uuid FROM sync_id_mapping AS m
  WHERE m.tabela = 'obras' AND m.id_servidor = obra_itens.obra_id
  LIMIT 1
)
WHERE (obra_uuid IS NULL OR TRIM(obra_uuid) = '' OR LOWER(obra_uuid) = 'null')
  AND obra_id IS NOT NULL
''');
  } catch (e) {
    print('⚠️ Backfill obra_uuid via mapping: $e');
  }
  try {
    total += await db.rawUpdate('''
UPDATE obra_itens
SET obra_uuid = (
  SELECT o.uuid FROM obras AS o
  WHERE o.id = obra_itens.obra_id
  LIMIT 1
)
WHERE (obra_uuid IS NULL OR TRIM(obra_uuid) = '' OR LOWER(obra_uuid) = 'null')
  AND obra_id IS NOT NULL
''');
  } catch (e) {
    print('⚠️ Backfill obra_uuid via obras.id: $e');
  }
  if (total > 0) {
    print('🔧 Backfill obra_uuid em $total obra_itens');
  }
  return total;
}

Future<bool> _temObraItensSemObraUuid(Database db) async {
  try {
    final rows = await db.rawQuery('''
SELECT COUNT(*) AS c FROM obra_itens
WHERE obra_uuid IS NULL OR TRIM(obra_uuid) = '' OR LOWER(obra_uuid) = 'null'
''');
    final c = rows.isEmpty ? 0 : _asNum(rows.first['c']).toInt();
    return c > 0;
  } catch (_) {
    return false;
  }
}

Future<String?> _resolverObraUuid({
  required Database db,
  required Map<String, dynamic> itemServer,
  String? forceObraUuid,
}) async {
  final forced = _nullableStr(forceObraUuid);
  if (forced != null) return forced;

  final fromServer = _nullableStr(itemServer['obra_uuid']);
  if (fromServer != null) return fromServer;

  final obraId = _serverId({'id': itemServer['obra_id']});
  if (obraId == null) return null;

  try {
    final byUuidMap = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: ['obras', obraId],
      limit: 1,
    );
    if (byUuidMap.isNotEmpty) {
      return _nullableStr(byUuidMap.first['uuid']);
    }
  } catch (_) {}

  try {
    final byLocal = await db.query(
      'obras',
      columns: ['uuid'],
      where: 'id = ?',
      whereArgs: [obraId],
      limit: 1,
    );
    if (byLocal.isNotEmpty) {
      return _nullableStr(byLocal.first['uuid']);
    }
  } catch (_) {}

  return null;
}

// ===== FUNÇÃO PRINCIPAL - DOWNLOAD =====

Future syncObrasItens() async {
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

    try {
      await _backfillObraUuidLocal(db);

      final prefs = await SharedPreferences.getInstance();
      final alreadyRepaired = prefs.getBool(_kObraItensFullResyncV2) ?? false;
      final needsUuidRepair = await _temObraItensSemObraUuid(db);
      final needsDaily = await shouldForceDailyFullResync(_kDailyScope);
      final forceFull =
          !alreadyRepaired || needsUuidRepair || needsDaily;

      final lastSync =
          forceFull ? kSyncEpoch : await _getUltimaSync('obra_itens');
      print(
          '📥 Buscando itens desde: $lastSync${forceFull ? ' (resync completo)' : ''}');

      final downloadResponse = await http.post(
        Uri.parse('$kApiBaseUrl/api/v1/sync/obra-itens/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final itensDoServidor = _extractItensList(downloadResult);

        print('📥 Recebidas ${itensDoServidor.length} itens');

        for (final itemServer in itensDoServidor) {
          await _processarItem(
            itemServer,
            touchLastSync: true,
          );
          downloadedCount++;
        }

        await _backfillObraUuidLocal(db);

        if (forceFull && downloadResponse.statusCode == 200) {
          await prefs.setBool(_kObraItensFullResyncV2, true);
          await markDailyFullResyncDone(_kDailyScope);
        }

        print('✅ Download concluído: $downloadedCount itens');
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

    _updateSyncStatus(
      true,
      'Sync itens concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync itens concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync itens: $e');
    _updateSyncStatus(false, 'Erro geral sync itens: $e', 0, 0);
  }
}

/// Baixa do endpoint da obra (`/obras/{uuid}/itens`) e grava no SQLite.
/// Usado ao abrir o select de presença no RDO — mesma fonte da tela Mão de Obra.
Future<void> refreshObraItensPorTipo({
  required String obraUuid,
  required String tipo,
}) async {
  final uuid = obraUuid.trim();
  final tipoNorm = tipo.trim();
  if (uuid.isEmpty || tipoNorm.isEmpty) return;

  final token = await _getAuthToken();
  if (token.isEmpty) return;

  final online = await checkInternetConnection();
  if (!online) return;

  try {
    final response = await http.get(
      Uri.parse(
        '$kApiBaseUrl/api/obras/$uuid/itens?tipo=$tipoNorm',
      ),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      print(
          '⚠️ refreshObraItensPorTipo HTTP ${response.statusCode}: ${response.body}');
      return;
    }

    final dynamic body =
        response.body.isNotEmpty ? json.decode(response.body) : null;
    final itens = _extractItensList(body);
    final creatorUuid = FFAppState().creatorUuid.trim();

    for (final raw in itens) {
      final item = Map<String, dynamic>.from(raw);
      item['obra_uuid'] = uuid;
      item['tipo'] = item['tipo'] ?? tipoNorm;
      if (_nullableStr(item['created_by_uuid']) == null &&
          creatorUuid.isNotEmpty) {
        item['created_by_uuid'] = creatorUuid;
      }
      // Não altera watermark incremental do sync geral.
      await _processarItem(
        item,
        forceObraUuid: uuid,
        touchLastSync: false,
      );
    }

    print(
        '✅ refreshObraItensPorTipo: ${itens.length} $tipoNorm da obra $uuid');
  } catch (e) {
    print('⚠️ refreshObraItensPorTipo: $e');
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ITEM =====

Future<void> _processarItem(
  Map<String, dynamic> itemServer, {
  String? forceObraUuid,
  bool touchLastSync = true,
}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = itemServer['uuid']?.toString() ?? _generateUuid();
  if (uuid.trim().isEmpty || uuid.toLowerCase() == 'null') {
    uuid = _generateUuid();
  }

  final sid = _serverId(itemServer);
  if (sid != null) {
    await _salvarMapeamento('obra_itens', sid, uuid);
  }

  final existe = await db.query(
    'obra_itens',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final qtd = _asNum(itemServer['qtd']).round();
  final qtdRealizada = _asNum(itemServer['qtd_realizada']).round();
  final porcentagem = _asNum(itemServer['porcentagem']);
  final valorUnitario = _asNum(itemServer['valor_unitario']).toDouble();

  final obraUuid = await _resolverObraUuid(
    db: db,
    itemServer: itemServer,
    forceObraUuid: forceObraUuid,
  );

  // Watermark = updated_at do registro (não "agora"), senão itens antigos
  // nunca mais entram no download incremental.
  final itemUpdatedAt = _nullableStr(itemServer['updated_at']);

  final rowComum = <String, dynamic>{
    'obra_id': itemServer['obra_id'],
    'obra_uuid': obraUuid,
    'tipo': itemServer['tipo'],
    'cargo_funcao': _nullableStr(itemServer['cargo_funcao']),
    'id_orcamento_item': itemServer['id_orcamento_item'],
    'orcamento_item_uuid': _nullableStr(itemServer['orcamento_item_uuid']),
    'id_orcamento_item_pai': itemServer['id_orcamento_item_pai'],
    'orcamento_item_pai_uuid':
        _nullableStr(itemServer['orcamento_item_pai_uuid']),
    'descricao': itemServer['descricao'],
    'qtd': qtd,
    'unidade': itemServer['unidade'],
    'valor_unitario': valorUnitario,
    'qtd_realizada': qtdRealizada,
    'porcentagem': porcentagem,
    'situacao': itemServer['situacao'],
    'created_by': _createdByLocal(itemServer),
    'synced': 1,
    'created_at': itemServer['created_at'],
    'updated_at': itemServer['updated_at'],
  };

  if (touchLastSync) {
    rowComum['last_sync_date'] = itemUpdatedAt ??
        DateTime.now().toUtc().toIso8601String();
  }

  if (existe.isNotEmpty) {
    await db.update(
      'obra_itens',
      rowComum,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Item atualizado: ${itemServer['descricao']}');
  } else {
    await db.insert(
      'obra_itens',
      {
        'uuid': uuid,
        ...rowComum,
      },
    );
    print('✅ Novo item inserido: ${itemServer['descricao']}');
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

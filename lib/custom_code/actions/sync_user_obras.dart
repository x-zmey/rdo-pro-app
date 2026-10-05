// Automatic FlutterFlow imports
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import '/auth/fetch_allowed_obras.dart';
import '/auth/membership_access.dart';
import 'sync_tenant_headers.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_config.dart';

import 'package:http/http.dart' as http;
import 'dart:convert';

Future<String> _getUltimaSyncUserObras() async {
  final db = await SQLiteManager.instance.database;
  try {
    final rows = await db.rawQuery('''
      SELECT MAX(ts) AS last_sync FROM (
        SELECT COALESCE(updated_at, created_at) AS ts FROM user_obras
        UNION ALL
        SELECT COALESCE(updated_at, created_at) AS ts FROM empresa_user_obra
      )
    ''');
    if (rows.isNotEmpty && rows.first['last_sync'] != null) {
      final s = rows.first['last_sync'].toString().trim();
      if (s.isNotEmpty) return s;
    }
  } catch (e) {
    print('⚠️ _getUltimaSyncUserObras: $e');
  }
  return '2000-01-01T00:00:00.000Z';
}

String _str(dynamic v) => v?.toString().trim() ?? '';

int? _intVal(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

Future<void> _upsertUserObra(Map<String, dynamic> row) async {
  final db = await SQLiteManager.instance.database;
  final userId = _intVal(row['user_id']);
  var obraId = _intVal(row['obra_id']);
  final userUuid = _str(row['user_uuid']);
  var obraUuid = _str(row['obra_uuid']);

  if (userId == null && userUuid.isEmpty) return;
  if (obraId == null && obraUuid.isEmpty) return;

  // obra_id da API é do servidor — resolve para id/uuid locais.
  try {
    if (obraId != null) {
      final maps = await db.query(
        'sync_id_mapping',
        columns: ['uuid'],
        where: 'tabela = ? AND id_servidor = ?',
        whereArgs: ['obras', obraId],
        limit: 1,
      );
      if (maps.isNotEmpty) {
        final mappedUuid = _str(maps.first['uuid']);
        if (mappedUuid.isNotEmpty) {
          obraUuid = mappedUuid;
          final local = await db.query(
            'obras',
            columns: ['id'],
            where: 'uuid = ?',
            whereArgs: [mappedUuid],
            limit: 1,
          );
          if (local.isNotEmpty) {
            obraId = _intVal(local.first['id']) ?? obraId;
          }
        }
      }
    }
    if (obraUuid.isNotEmpty) {
      final local = await db.query(
        'obras',
        columns: ['id'],
        where: 'uuid = ?',
        whereArgs: [obraUuid],
        limit: 1,
      );
      if (local.isNotEmpty) {
        obraId = _intVal(local.first['id']) ?? obraId;
      }
    }
  } catch (_) {}

  if (obraId == null && obraUuid.isEmpty) return;

  final payload = <String, dynamic>{
    'user_id': userId,
    'obra_id': obraId,
    'user_uuid': userUuid,
    'obra_uuid': obraUuid,
    'permissao': _str(row['permissao']).isEmpty ? 'visualizar' : _str(row['permissao']),
    'created_at': _str(row['created_at']).isEmpty ? null : _str(row['created_at']),
    'updated_at': _str(row['updated_at']).isEmpty ? null : _str(row['updated_at']),
  };

  List<Map<String, Object?>> existe = const [];
  if (userUuid.isNotEmpty && obraUuid.isNotEmpty) {
    existe = await db.query(
      'user_obras',
      where: 'user_uuid = ? AND obra_uuid = ?',
      whereArgs: [userUuid, obraUuid],
      limit: 1,
    );
  }

  if (existe.isEmpty && userId != null && obraId != null) {
    existe = await db.query(
      'user_obras',
      where: 'user_id = ? AND obra_id = ?',
      whereArgs: [userId, obraId],
      limit: 1,
    );
  }

  if (existe.isNotEmpty) {
    await db.update(
      'user_obras',
      payload,
      where: 'id = ?',
      whereArgs: [existe.first['id']],
    );
  } else {
    await db.insert('user_obras', payload);
  }
}

void _updateSyncStatus(bool success, String message, int downloaded) {
  try {
    FFAppState().update(() {
      FFAppState().syncSuccess = success;
      FFAppState().syncMessage = message;
      FFAppState().syncUploadedCount = 0;
      FFAppState().syncDownloadedCount = downloaded;
      FFAppState().lastSyncTime = DateTime.now().toIso8601String();
    });
  } catch (e) {
    print('❌ Erro ao atualizar AppState: $e');
  }
}

Future syncUserObras() async {
  try {
    final token = FFAppState().UserToken;
    final userId = FFAppState().UserID;
    if (token.isEmpty || userId <= 0) {
      _updateSyncStatus(false, 'Usuário não autenticado para sync user_obras.', 0);
      return;
    }

    // Com obra_travada, sempre baixa o conjunto completo — incremental deixava
    // vínculos antigos de fora e a home ficava sem obras.
    final forceFull = MembershipAccess.obraTravada;
    final lastSync = forceFull
        ? '2000-01-01T00:00:00.000Z'
        : await _getUltimaSyncUserObras();
    final headers = syncAuthHeaders();

    final response = await http.post(
      Uri.parse('$kApiBaseUrl/api/v1/sync/user-obras/download'),
      headers: headers,
      body: json.encode({
        'ultima_sync': lastSync,
        'user_id': userId,
        if (forceFull) 'force_full': true,
      }),
    );

    if (response.statusCode == 401) {
      _updateSyncStatus(false, 'Token expirado. Faça login novamente.', 0);
      return;
    }
    if (response.statusCode != 200) {
      _updateSyncStatus(
        false,
        'Erro ao baixar vínculos user_obras: ${response.statusCode}',
        0,
      );
      return;
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    final dadosRaw = jsonBody['dados'];
    final dados = dadosRaw is List ? dadosRaw : <dynamic>[];

    var count = 0;
    for (final item in dados) {
      if (item is Map<String, dynamic>) {
        await _upsertUserObra(item);
        await upsertEmpresaUserObraFromServer(
          await SQLiteManager.instance.database,
          item,
        );
        count++;
      }
    }

    // Garante vínculos locais a partir dos IDs permitidos (login / API).
    await ensureLocalUserObraLinksFromAllowedIds();

    _updateSyncStatus(true, 'Sync user_obras concluída: ↓$count', count);
  } catch (e) {
    _updateSyncStatus(false, 'Erro geral sync user_obras: $e', 0);
  }
}


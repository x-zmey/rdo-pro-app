import 'package:sqflite/sqflite.dart';

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Tabelas e backfill local para multi-empresa (`empresa_users`, pivots).
Future<void> ensureEmpresaMultiTenantTables(Database database) async {
  await database.execute('''
CREATE TABLE IF NOT EXISTS empresa_users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  id_server INTEGER,
  user_id INTEGER,
  user_uuid TEXT,
  tenant_user_id INTEGER NOT NULL,
  tenant_user_uuid TEXT,
  type TEXT NOT NULL DEFAULT 'user',
  obra_travada INTEGER NOT NULL DEFAULT 0,
  situacao INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT,
  last_sync_date TEXT
)
''');

  await database.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_empresa_users_server
ON empresa_users (id_server)
WHERE id_server IS NOT NULL
''');

  await database.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_empresa_users_user_tenant
ON empresa_users (user_uuid, tenant_user_id)
WHERE user_uuid IS NOT NULL AND TRIM(user_uuid) != ''
''');

  await database.execute('''
CREATE TABLE IF NOT EXISTS empresa_user_permission (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  id_server INTEGER,
  empresa_user_id INTEGER,
  empresa_user_id_server INTEGER NOT NULL,
  permission_id INTEGER NOT NULL,
  permission_name TEXT,
  permission_description TEXT,
  created_at TEXT,
  updated_at TEXT
)
''');

  await database.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_eup_membership_permission
ON empresa_user_permission (empresa_user_id_server, permission_id)
''');

  await database.execute('''
CREATE TABLE IF NOT EXISTS empresa_user_obra (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  id_server INTEGER,
  empresa_user_id INTEGER,
  empresa_user_id_server INTEGER NOT NULL,
  user_id INTEGER,
  user_uuid TEXT,
  obra_id INTEGER NOT NULL,
  obra_uuid TEXT,
  permissao TEXT NOT NULL DEFAULT 'visualizar',
  situacao INTEGER NOT NULL DEFAULT 1,
  created_at TEXT,
  updated_at TEXT
)
''');

  await database.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS idx_euo_membership_obra
ON empresa_user_obra (empresa_user_id_server, obra_id)
''');

  await _ensureEmpresaUserPermissionDescriptionColumn(database);
  await _backfillEmpresaUsersFromLegacyUsers(database);
  await _backfillEmpresaUserObrasFromUserObras(database);
}

Future<void> _ensureEmpresaUserPermissionDescriptionColumn(
  Database database,
) async {
  try {
    final info =
        await database.rawQuery('PRAGMA table_info(empresa_user_permission)');
    if (info.isEmpty) return;
    final has = info.any((row) => (row['name'] as String?) == 'permission_description');
    if (!has) {
      await database.execute(
        'ALTER TABLE empresa_user_permission ADD COLUMN permission_description TEXT',
      );
    }
  } catch (_) {}
}

Future<void> _backfillEmpresaUsersFromLegacyUsers(Database database) async {
  try {
    await database.rawInsert('''
INSERT INTO empresa_users (
  user_id, user_uuid, tenant_user_id, tenant_user_uuid,
  type, obra_travada, situacao, created_at, updated_at
)
SELECT
  u.id,
  u.uuid,
  COALESCE(t.id_server, t.id),
  u.created_by,
  COALESCE(NULLIF(TRIM(u.type), ''), 'user'),
  COALESCE(u.obra_travada, 0),
  COALESCE(u.situacao, 1),
  u.created_at,
  u.updated_at
FROM users AS u
INNER JOIN users AS t ON t.uuid = u.created_by
WHERE u.created_by IS NOT NULL
  AND TRIM(u.created_by) != ''
  AND LOWER(TRIM(u.created_by)) != LOWER(TRIM(COALESCE(u.uuid, '')))
  AND NOT EXISTS (
    SELECT 1 FROM empresa_users AS eu
    WHERE eu.user_id = u.id
      AND eu.tenant_user_id = COALESCE(t.id_server, t.id)
  )
''');
  } catch (_) {}
}

Future<void> _backfillEmpresaUserObrasFromUserObras(Database database) async {
  try {
    await database.rawInsert('''
INSERT INTO empresa_user_obra (
  empresa_user_id, empresa_user_id_server,
  user_id, user_uuid, obra_id, obra_uuid,
  permissao, situacao, created_at, updated_at
)
SELECT
  eu.id,
  eu.id_server,
  uo.user_id,
  uo.user_uuid,
  uo.obra_id,
  uo.obra_uuid,
  COALESCE(NULLIF(TRIM(uo.permissao), ''), 'visualizar'),
  COALESCE(uo.situacao, 1),
  uo.created_at,
  uo.updated_at
FROM user_obras AS uo
INNER JOIN users AS u ON u.id = uo.user_id
INNER JOIN users AS t ON t.uuid = u.created_by
INNER JOIN empresa_users AS eu
  ON eu.user_id = u.id
  AND eu.tenant_user_id = COALESCE(t.id_server, t.id)
WHERE COALESCE(eu.id_server, eu.id) IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM empresa_user_obra AS euo
    WHERE euo.empresa_user_id_server = eu.id_server
      AND euo.obra_id = uo.obra_id
  )
''');
  } catch (_) {}
}

Future<void> upsertEmpresaUserFromServer(
  Database db,
  Map<String, dynamic> row,
  String serverTime,
) async {
  final idServer = _optInt(row['empresa_user_id']);
  final userId = _optInt(row['id']);
  final userUuid = _str(row['uuid']);
  final tenantId = _optInt(row['tenant_user_id']) ?? _optInt(row['created_by']);
  final tenantUuid = _str(row['created_by_uuid']);
  if (tenantId == null && tenantUuid.isEmpty) return;

  final payload = <String, dynamic>{
    if (idServer != null) 'id_server': idServer,
    if (userId != null) 'user_id': userId,
    if (userUuid.isNotEmpty) 'user_uuid': userUuid,
    'tenant_user_id': tenantId ?? 0,
    if (tenantUuid.isNotEmpty) 'tenant_user_uuid': tenantUuid,
    'type': _str(row['membership_type']).isEmpty
        ? (_str(row['type']).isEmpty ? 'user' : _str(row['type']))
        : _str(row['membership_type']),
    'obra_travada': _optInt(row['obra_travada']) ?? 0,
    'situacao':
        _optInt(row['membership_situacao']) ?? _optInt(row['situacao']) ?? 1,
    'created_at': _nullableStr(row['created_at']),
    'updated_at': _nullableStr(row['empresa_user_updated_at']) ??
        _nullableStr(row['updated_at']),
    'last_sync_date': serverTime,
  };

  List<Map<String, Object?>> existe = const [];
  if (idServer != null) {
    existe = await db.query(
      'empresa_users',
      where: 'id_server = ?',
      whereArgs: [idServer],
      limit: 1,
    );
  }
  if (existe.isEmpty && userUuid.isNotEmpty && tenantId != null) {
    existe = await db.query(
      'empresa_users',
      where: 'user_uuid = ? AND tenant_user_id = ?',
      whereArgs: [userUuid, tenantId],
      limit: 1,
    );
  }

  if (existe.isNotEmpty) {
    await db.update(
      'empresa_users',
      payload,
      where: 'id = ?',
      whereArgs: [existe.first['id']],
    );
  } else {
    await db.insert('empresa_users', payload);
  }
}

Future<void> upsertEmpresaUserObraFromServer(
  Database db,
  Map<String, dynamic> row,
) async {
  final empresaUserIdServer =
      _optInt(row['empresa_user_id']) ?? _optInt(row['empresa_user_id_server']);
  var obraId = _optInt(row['obra_id']);
  final userId = _optInt(row['user_id']);
  final userUuid = _str(row['user_uuid']);
  var obraUuid = _str(row['obra_uuid']);

  // obra_id da API é do servidor — prefere uuid/id local.
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
            obraId = _optInt(local.first['id']) ?? obraId;
          }
        }
      }
    } else if (obraUuid.isNotEmpty) {
      final local = await db.query(
        'obras',
        columns: ['id'],
        where: 'uuid = ?',
        whereArgs: [obraUuid],
        limit: 1,
      );
      if (local.isNotEmpty) {
        obraId = _optInt(local.first['id']);
      }
    }
  } catch (_) {}

  if (obraId == null && obraUuid.isEmpty) return;

  int? empresaUserLocalId;
  if (empresaUserIdServer != null) {
    final euRows = await db.query(
      'empresa_users',
      columns: ['id'],
      where: 'id_server = ?',
      whereArgs: [empresaUserIdServer],
      limit: 1,
    );
    if (euRows.isNotEmpty) {
      empresaUserLocalId = euRows.first['id'] as int?;
    }
  }

  final payload = <String, dynamic>{
    if (empresaUserIdServer != null)
      'empresa_user_id_server': empresaUserIdServer,
    if (empresaUserLocalId != null) 'empresa_user_id': empresaUserLocalId,
    if (userId != null) 'user_id': userId,
    if (userUuid.isNotEmpty) 'user_uuid': userUuid,
    if (obraId != null) 'obra_id': obraId,
    if (obraUuid.isNotEmpty) 'obra_uuid': obraUuid,
    'permissao':
        _str(row['permissao']).isEmpty ? 'visualizar' : _str(row['permissao']),
    'situacao': _optInt(row['situacao']) ?? 1,
    'created_at': _nullableStr(row['created_at']),
    'updated_at': _nullableStr(row['updated_at']),
    if (_optInt(row['id']) != null) 'id_server': _optInt(row['id']),
  };

  List<Map<String, Object?>> existe = const [];
  if (empresaUserIdServer != null && obraUuid.isNotEmpty) {
    existe = await db.query(
      'empresa_user_obra',
      where: 'empresa_user_id_server = ? AND obra_uuid = ?',
      whereArgs: [empresaUserIdServer, obraUuid],
      limit: 1,
    );
  }
  if (existe.isEmpty && empresaUserIdServer != null && obraId != null) {
    existe = await db.query(
      'empresa_user_obra',
      where: 'empresa_user_id_server = ? AND obra_id = ?',
      whereArgs: [empresaUserIdServer, obraId],
      limit: 1,
    );
  }

  if (existe.isNotEmpty) {
    await db.update(
      'empresa_user_obra',
      payload,
      where: 'id = ?',
      whereArgs: [existe.first['id']],
    );
  } else {
    await db.insert('empresa_user_obra', payload);
  }
}

String _str(dynamic v) => v?.toString().trim() ?? '';

String? _nullableStr(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

int? _optInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

Future<void> upsertEmpresaUserPermissionFromServer(
  Database db,
  Map<String, dynamic> row,
) async {
  var empresaUserIdServer = _optInt(row['empresa_user_id']);
  final permissionId = _optInt(row['permission_id']);
  if (permissionId == null) return;

  if (empresaUserIdServer == null || empresaUserIdServer == 0) {
    if (FFAppState().isUserTypeCompany && FFAppState().activeTenantUserId > 0) {
      empresaUserIdServer = FFAppState().activeTenantUserId;
    } else {
      return;
    }
  }

  int? empresaUserLocalId;
  if (empresaUserIdServer > 0) {
    final euRows = await db.query(
      'empresa_users',
      columns: ['id'],
      where: 'id_server = ?',
      whereArgs: [empresaUserIdServer],
      limit: 1,
    );
    if (euRows.isNotEmpty) {
      empresaUserLocalId = euRows.first['id'] as int?;
    }
  }

  final permName = _str(row['permission_name']);
  final permDesc = _str(row['permission_description']);

  final payload = <String, dynamic>{
    'empresa_user_id_server': empresaUserIdServer,
    if (empresaUserLocalId != null) 'empresa_user_id': empresaUserLocalId,
    'permission_id': permissionId,
    if (permName.isNotEmpty) 'permission_name': permName,
    if (permDesc.isNotEmpty) 'permission_description': permDesc,
    'created_at': _nullableStr(row['created_at']),
    'updated_at': _nullableStr(row['updated_at']),
    if (_optInt(row['id']) != null) 'id_server': _optInt(row['id']),
  };

  List<Map<String, Object?>> existe = const [];
  if (empresaUserIdServer > 0) {
    existe = await db.query(
      'empresa_user_permission',
      where: 'empresa_user_id_server = ? AND permission_id = ?',
      whereArgs: [empresaUserIdServer, permissionId],
      limit: 1,
    );
  }

  if (existe.isNotEmpty) {
    await db.update(
      'empresa_user_permission',
      payload,
      where: 'id = ?',
      whereArgs: [existe.first['id']],
    );
  } else {
    await db.insert('empresa_user_permission', payload);
  }
}

/// Permissões do vínculo ativo (ou conta empresa) para `FFAppState().UserPermissoes`.
Future<List<Map<String, dynamic>>> loadPermissionsPayloadForActiveMembership(
  Database db, {
  required int activeEmpresaUserId,
  required int activeTenantUserId,
  required String userUuid,
  required bool isCompanyAccount,
}) async {
  final membershipKey = isCompanyAccount && activeEmpresaUserId <= 0
      ? activeTenantUserId
      : activeEmpresaUserId;
  if (membershipKey <= 0) return [];

  final rows = await db.query(
    'empresa_user_permission',
    columns: ['permission_id', 'permission_name', 'permission_description'],
    where: 'empresa_user_id_server = ?',
    whereArgs: [membershipKey],
    orderBy: 'permission_name COLLATE NOCASE ASC',
  );

  if (rows.isEmpty && userUuid.isNotEmpty && activeTenantUserId > 0) {
    final fallback = await db.rawQuery(
      '''
SELECT eup.permission_id AS id, eup.permission_name AS name,
       eup.permission_description AS description
FROM empresa_user_permission AS eup
INNER JOIN empresa_users AS eu ON eu.id_server = eup.empresa_user_id_server
WHERE eu.user_uuid = ? AND eu.tenant_user_id = ?
ORDER BY eup.permission_name COLLATE NOCASE ASC
''',
      [userUuid, activeTenantUserId],
    );
    return fallback
        .map((r) => {
              'id': r['id'],
              'name': r['name']?.toString() ?? '',
              'description': r['description']?.toString(),
            })
        .toList();
  }

  return rows
      .map((r) => {
            'id': r['permission_id'],
            'name': r['permission_name']?.toString() ?? '',
            'description': r['permission_description']?.toString(),
          })
      .toList();
}

/// Lista permissões de um vínculo (ex.: tela de detalhes do usuário offline).
Future<List<Map<String, dynamic>>> loadPermissionsPayloadForEmpresaUser(
  Database db,
  int empresaUserIdServer,
) async {
  final rows = await db.query(
    'empresa_user_permission',
    columns: ['permission_id', 'permission_name', 'permission_description'],
    where: 'empresa_user_id_server = ?',
    whereArgs: [empresaUserIdServer],
    orderBy: 'permission_name COLLATE NOCASE ASC',
  );
  return rows
      .map((r) => {
            'id': r['permission_id'],
            'name': r['permission_name']?.toString() ?? '',
            'description': r['permission_description']?.toString(),
          })
      .toList();
}

Future<void> refreshAppStatePermissoesFromSqlite() async {
  try {
    final db = await SQLiteManager.instance.database;
    final payload = await loadPermissionsPayloadForActiveMembership(
      db,
      activeEmpresaUserId: FFAppState().activeEmpresaUserId,
      activeTenantUserId: FFAppState().activeTenantUserId,
      userUuid: FFAppState().UserUuid,
      isCompanyAccount: FFAppState().isUserTypeCompany,
    );
    if (payload.isNotEmpty) {
      FFAppState().UserPermissoes = payload;
      final names = payload
          .map((p) => p['name']?.toString().trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (names.isNotEmpty) {
        FFAppState().permissionNames = names;
      }
    }
  } catch (e) {
    print('⚠️ refreshAppStatePermissoesFromSqlite: $e');
  }
}

import '/auth/apply_membership_auth.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Aplica resposta de login ou `switch-tenant` ao [FFAppState].
Future<void> applyTenantAuthPayload(
  dynamic response, {
  int? fallbackTenantUserId,
}) async {
  await applyMembershipFromAuth(
    response,
    fallbackTenantUserId: fallbackTenantUserId,
  );
}

/// Garante [creatorUuid] do tenant ativo (SQLite ou API) após troca de empresa.
Future<void> ensureCreatorUuidForActiveTenant() async {
  final tenantId = FFAppState().activeTenantUserId;
  if (tenantId <= 0) return;

  if (FFAppState().creatorId <= 0) {
    FFAppState().creatorId = tenantId;
  }

  final current = FFAppState().creatorUuid.trim();
  if (current.isNotEmpty) return;

  try {
    final db = await SQLiteManager.instance.database;
    final rows = await db.query(
      'users',
      columns: ['uuid'],
      where: 'id_server = ?',
      whereArgs: [tenantId],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final uuid = rows.first['uuid']?.toString().trim() ?? '';
      if (uuid.isNotEmpty) {
        FFAppState().creatorUuid = uuid;
        return;
      }
    }
  } catch (e) {
    print('⚠️ ensureCreatorUuidForActiveTenant: $e');
  }
}

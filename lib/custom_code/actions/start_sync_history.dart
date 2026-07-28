import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
Future<int> startSyncHistory() async {
  final db = SQLiteManager.instance.database;
  final now = DateTime.now().toIso8601String();
  final userId = FFAppState().creatorId;
  final userUuid = FFAppState().creatorUuid;

  final id = await db.insert(
    'sync_history',
    {
      'user_id': userId,
      'user_uuid': userUuid,
      'started_at': now,
      'status': 'running',
      'created_at': now,
    },
  );

  return id;
}

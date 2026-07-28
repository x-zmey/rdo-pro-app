// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

/// Set your action name, define your arguments and return parameter, and then
/// add the boilerplate code using the green button on the right!
Future finishSuccessSync(int syncId) async {
  final db = await SQLiteManager.instance.database;

  await db.update(
    'sync_history',
    {
      'completed_at': DateTime.now().toIso8601String(),
      'status': 'success',
    },
    where: 'id = ?',
    whereArgs: [syncId],
  );
}

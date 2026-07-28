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

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

Future checkSyncStatus() async {
  final db = await SQLiteManager.instance.database;

  // Verificar obras não sincronizadas
  final unsyncedObras = await db.query(
    'obras',
    where: 'synced = ?',
    whereArgs: [0],
  );

  // Verificar total de obras
  final allObras = await db.query('obras');

  print('📊 Status do Banco Local:');
  print('   Total de obras: ${allObras.length}');
  print('   Obras não sincronizadas: ${unsyncedObras.length}');
  print('   Obras sincronizadas: ${allObras.length - unsyncedObras.length}');

  // Mostrar algumas obras não sincronizadas
  if (unsyncedObras.isNotEmpty) {
    print('   📝 Obras pendentes:');
    for (var i = 0; i < min(3, unsyncedObras.length); i++) {
      print(
          '      - ${unsyncedObras[i]['nome']} (${unsyncedObras[i]['uuid']})');
    }
  }
}

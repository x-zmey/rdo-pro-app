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

import 'checklist_offline.dart';

Future<String> salvarRespostaTexto(
  String checklistDataJson,
  String areaId,
  String itemId,
  String resposta,
) {
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {'respostaTexto': resposta},
  );
}

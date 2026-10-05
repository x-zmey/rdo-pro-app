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

/// Próximo número de RDO **por obra** (não global entre obras).
///
/// Preferir [nextRelatorioNumeroForObra]. Este helper legado só incrementa
/// um valor já obtido — se [numeroAnterior] vier de query sem filtro de obra,
/// o salto/duplicata volta.
Future<int?> incriseRelatorioNumero(int? numeroAnterior) async {
  if (numeroAnterior == null) {
    return 1;
  }
  return numeroAnterior + 1;
}

/// Calcula `max(numero)+1` no SQLite filtrando pela obra.
Future<int> nextRelatorioNumeroForObra({
  required String accountOwnerUuid,
  required String obraUuid,
}) async {
  final owner = accountOwnerUuid.trim();
  final obra = obraUuid.trim();
  if (owner.isEmpty || obra.isEmpty) {
    return 1;
  }
  final ultimo = await SQLiteManager.instance.carregaUltimoRelatorio(
    accountOwnerUuid: owner,
    obraUuid: obra,
  );
  final n = ultimo.firstOrNull?.numero;
  if (n == null || n < 1) return 1;
  return n + 1;
}

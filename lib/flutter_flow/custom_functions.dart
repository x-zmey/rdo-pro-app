import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'lat_lng.dart';
import 'place.dart';
import 'uploaded_file.dart';
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/auth/custom_auth/auth_util.dart';

List<dynamic> getAreasFromChecklist(String checklistJson) {
  try {
    if (checklistJson.isEmpty) {
      print('⚠️ checklistJson está vazio');
      return [];
    }

    final checklistData = json.decode(checklistJson);
    final templateData = checklistData['template_data'];
    final areas = templateData['areas'] as List;

    print('✅ Áreas encontradas: ${areas.length}');

    return areas;
  } catch (e) {
    print('❌ Erro ao buscar áreas: $e');
    return [];
  }
}

dynamic getDadosFromChecklist(String checklistJson) {
  try {
    if (checklistJson.isEmpty) {
      print('⚠️ checklistJson está vazio');
      return null;
    }

    final checklistData = json.decode(checklistJson);

    print('✅dados do template: ${checklistData}');

    return checklistData;
  } catch (e) {
    print('❌ Erro ao buscar áreas: $e');
    return null;
  }
}

/// Quantidade de material recebido / similar: aceita int, double, `5.5`, `"2,00"` (API / BR).
double parseQuantidadeRelatorio(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value.toDouble();
  if (value is double) return value;
  if (value is num) return value.toDouble();
  final s = value.toString().trim().replaceAll(',', '.');
  if (s.isEmpty) return 0;
  return double.tryParse(s) ?? 0;
}

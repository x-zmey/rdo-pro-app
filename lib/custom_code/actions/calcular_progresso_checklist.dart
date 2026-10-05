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

import 'dart:convert';

import 'checklist_complementos.dart';
import 'checklist_offline.dart';

String calcularProgressoChecklist(String checklistDataJson) {
  try {
    final checklistData = decodeChecklistEnvelope(checklistDataJson);
    if (checklistData == null) {
      throw Exception('JSON inválido');
    }
    final templateData = templateDataFromEnvelope(checklistData);
    final areas = templateData?['areas'] as List? ?? [];

    var totalItens = 0;
    var itensRespondidos = 0;
    var itensObrigatorios = 0;
    var itensObrigatoriosRespondidos = 0;
    var complementosPendentes = 0;

    for (final area in areas) {
      if (area is! Map) continue;
      final items = area['items'] as List? ?? [];
      for (final item in items) {
        if (item is! Map) continue;
        totalItens++;
        final obrigatorio =
            item['obrigatorio'] == true || item['required'] == true;
        if (obrigatorio) itensObrigatorios++;

        final tipo = normalizeChecklistItemType(item['type']);
        final respondido = _isRespondido(tipo, item);
        if (respondido) {
          itensRespondidos++;
          if (obrigatorio) itensObrigatoriosRespondidos++;
        }

        final pendencias = checklistPendenciasComplementos(item);
        if (pendencias.isNotEmpty) {
          complementosPendentes += pendencias.length;
        }
      }
    }

    final progressoTotal =
        totalItens > 0 ? (itensRespondidos / totalItens) * 100 : 0.0;
    final progressoObrigatorios = itensObrigatorios > 0
        ? (itensObrigatoriosRespondidos / itensObrigatorios) * 100
        : 100.0;
    final completo = itensObrigatoriosRespondidos == itensObrigatorios &&
        complementosPendentes == 0;

    return json.encode({
      'total_itens': totalItens,
      'itens_respondidos': itensRespondidos,
      'itens_obrigatorios': itensObrigatorios,
      'itens_obrigatorios_respondidos': itensObrigatoriosRespondidos,
      'complementos_pendentes': complementosPendentes,
      'progresso_total': progressoTotal.round(),
      'progresso_obrigatorios': progressoObrigatorios.round(),
      'completo': completo,
      'pode_finalizar': completo,
    });
  } catch (e) {
    return json.encode({
      'total_itens': 0,
      'itens_respondidos': 0,
      'itens_obrigatorios': 0,
      'itens_obrigatorios_respondidos': 0,
      'complementos_pendentes': 0,
      'progresso_total': 0,
      'progresso_obrigatorios': 0,
      'completo': false,
      'pode_finalizar': false,
      'erro': e.toString(),
    });
  }
}

bool _isRespondido(String tipo, Map item) {
  switch (tipo) {
    case 'Avaliativo Sim/Não':
      return item['respostaBoolean'] != null;
    case 'Avaliativo Emojis':
      return (item['respostaEmoji']?.toString() ?? '').trim().isNotEmpty;
    case 'Texto':
    case 'Cadastro':
      return (item['respostaTexto']?.toString() ?? '').trim().isNotEmpty;
    case 'Data':
      return item['respostaData'] != null &&
          item['respostaData'].toString().trim().isNotEmpty;
    case 'Número':
      return item['respostaNumero'] != null;
    case 'Opção':
      return (item['respostaOpcao']?.toString() ?? '').trim().isNotEmpty;
    case 'Anexo':
      return checklistAnexosRespostaPreenchidos(item);
    default:
      return item['resposta'] != null;
  }
}

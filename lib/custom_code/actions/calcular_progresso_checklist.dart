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

String calcularProgressoChecklist(String checklistDataJson) {
  try {
    final checklistData = json.decode(checklistDataJson);
    final templateData = checklistData['template_data'];
    final areas = templateData['areas'] as List;

    int totalItens = 0;
    int itensRespondidos = 0;
    int itensObrigatorios = 0;
    int itensObrigatoriosRespondidos = 0;

    for (final area in areas) {
      final items = area['items'] as List;

      for (final item in items) {
        totalItens++;

        final obrigatorio = item['obrigatorio'] == true;
        if (obrigatorio) {
          itensObrigatorios++;
        }

        final tipo = item['type'] as String;
        bool respondido = false;

        switch (tipo) {
          case 'Avaliativo Sim/Não':
            respondido = item['respostaBoolean'] != null;
            break;
          case 'Avaliativo Emojis':
            respondido = item['respostaEmoji'] != null;
            break;
          case 'Texto longo':
            respondido = item['respostaTexto'] != null &&
                (item['respostaTexto'] as String).isNotEmpty;
            break;
          case 'Data':
            respondido = item['respostaData'] != null;
            break;
          case 'Número':
            respondido = item['respostaNumero'] != null;
            break;
          case 'Opções':
            respondido = item['respostaOpcao'] != null;
            break;
          default:
            respondido = item['resposta'] != null;
        }

        if (respondido) {
          itensRespondidos++;
          if (obrigatorio) {
            itensObrigatoriosRespondidos++;
          }
        }
      }
    }

    final progressoTotal =
        totalItens > 0 ? (itensRespondidos / totalItens) * 100 : 0;
    final progressoObrigatorios = itensObrigatorios > 0
        ? (itensObrigatoriosRespondidos / itensObrigatorios) * 100
        : 0;
    final completo = itensObrigatoriosRespondidos == itensObrigatorios;

    final resultado = {
      'total_itens': totalItens,
      'itens_respondidos': itensRespondidos,
      'itens_obrigatorios': itensObrigatorios,
      'itens_obrigatorios_respondidos': itensObrigatoriosRespondidos,
      'progresso_total': progressoTotal.round(),
      'progresso_obrigatorios': progressoObrigatorios.round(),
      'completo': completo,
      'pode_finalizar':
          completo, // Só pode finalizar se todos obrigatórios respondidos
    };

    print(
        '📊 Progresso: $itensRespondidos/$totalItens itens ($progressoTotal%)');
    print(
        '🎯 Obrigatórios: $itensObrigatoriosRespondidos/$itensObrigatorios ($progressoObrigatorios%)');

    return json.encode(resultado);
  } catch (e) {
    print('❌ Erro ao calcular progresso: $e');

    return json.encode({
      'total_itens': 0,
      'itens_respondidos': 0,
      'itens_obrigatorios': 0,
      'itens_obrigatorios_respondidos': 0,
      'progresso_total': 0,
      'progresso_obrigatorios': 0,
      'completo': false,
      'pode_finalizar': false,
      'erro': e.toString(),
    });
  }
}

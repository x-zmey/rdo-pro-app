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

Future<String> salvarRespostaEmoji(
  String checklistDataJson,
  String areaId,
  String itemId,
  String resposta,
) async {
  try {
    // Converter JSON string para Map
    final checklistData = json.decode(checklistDataJson);

    final templateData =
        Map<String, dynamic>.from(checklistData['template_data']);
    final areas = templateData['areas'] as List;

    bool itemEncontrado = false;
    String descricaoItem = '';

    // Encontrar e atualizar o item específico
    final novasAreas = areas.map<Map<String, dynamic>>((area) {
      final areaMap = Map<String, dynamic>.from(area);

      if (areaMap['id'].toString() == areaId) {
        final items = areaMap['items'] as List;

        final novosItems = items.map<Map<String, dynamic>>((item) {
          final itemMap = Map<String, dynamic>.from(item);

          if (itemMap['id'].toString() == itemId) {
            itemEncontrado = true;
            descricaoItem =
                itemMap['description']?.toString() ?? 'Sem descrição';

            // Atualizar resposta
            itemMap['respostaEmoji'] = resposta;

            // Verificar se precisa de plano de ação baseado no emoji selecionado
            final opcoes = itemMap['emojiRatingOptions'] as List? ?? [];
            for (final opcao in opcoes) {
              if (opcao['valor'] == resposta) {
                final requisitos =
                    opcao['requisitos'] as Map<String, dynamic>? ?? {};
                if (requisitos['plano_acao'] == true) {
                  itemMap['precisa_plano_acao'] = true;
                }
                break;
              }
            }

            print('✅ Resposta emoji salva: $descricaoItem = $resposta');
          }

          return itemMap;
        }).toList();

        areaMap['items'] = novosItems;
      }

      return areaMap;
    }).toList();

    if (!itemEncontrado) {
      throw Exception('Item não encontrado: Área $areaId, Item $itemId');
    }

    templateData['areas'] = novasAreas;

    // Atualizar checklist data
    final novoChecklistData = Map<String, dynamic>.from(checklistData);
    novoChecklistData['template_data'] = templateData;
    novoChecklistData['ultima_atualizacao'] = DateTime.now().toIso8601String();

    // Converter de volta para JSON string
    final resultadoJson = json.encode(novoChecklistData);

    return resultadoJson;
  } catch (e) {
    print('❌ Erro ao salvar resposta emoji: $e');

    final erro = {
      'erro': true,
      'mensagem': e.toString(),
      'funcao': 'salvarRespostaEmoji',
    };

    return json.encode(erro);
  }
}

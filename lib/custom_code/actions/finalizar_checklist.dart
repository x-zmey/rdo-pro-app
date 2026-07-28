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
import 'dart:math';

Future<String> finalizarChecklist(
  String checklistDataJson,
  String comentarioGeral,
  String assinatura,
) async {
  try {
    final db = await SQLiteManager.instance.database;

    // Converter JSON string para Map
    final checklistData = json.decode(checklistDataJson);
    final templateData =
        Map<String, dynamic>.from(checklistData['template_data']);

    // Adicionar dados de conclusão ao template
    templateData['comentario_geral'] = comentarioGeral;
    templateData['assinatura'] = assinatura.isNotEmpty ? assinatura : null;
    templateData['data_conclusao'] = DateTime.now().toIso8601String();

    // Calcular nota final
    final calculoNota = _calcularNotaFinal(templateData);
    final notaFinal = calculoNota['nota_final'] ?? 0.0;
    final maximoPossivel = calculoNota['maximo_possivel'] ?? 0.0;

    // Salvar no banco
    final resultadoInsert = await db.insert('checklists_preenchidos', {
      'uuid': checklistData['uuid'],
      'checklist_template_id': checklistData['template_id'],
      'obra_id': checklistData['obra_id'],
      'usuario_id': checklistData['usuario_id'],
      'json_respostas': json.encode(templateData),
      'nota_final': notaFinal,
      'situacao': 'concluido',
      'created_by': checklistData['usuario_id'],
      'synced': 0, // Não sincronizado ainda
      'last_sync_date': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    });

    print('✅ Checklist finalizado e salvo no SQLite');
    print('📝 UUID: ${checklistData['uuid']}');
    print('🎯 Nota: $notaFinal/$maximoPossivel');
    print('💾 ID no SQLite: $resultadoInsert');

    final resultado = {
      'sucesso': true,
      'mensagem': 'Checklist finalizado com sucesso!',
      'uuid': checklistData['uuid'],
      'nota_final': notaFinal,
      'maximo_possivel': maximoPossivel,
      'id_sqlite': resultadoInsert,
      'template_nome': checklistData['template_name'],
    };

    return json.encode(resultado);
  } catch (e) {
    print('❌ Erro ao finalizar checklist: $e');

    final erro = {
      'sucesso': false,
      'mensagem': 'Erro ao finalizar checklist: ${e.toString()}',
      'erro': e.toString(),
    };

    return json.encode(erro);
  }
}

Map<String, dynamic> _calcularNotaFinal(Map<String, dynamic> templateData) {
  double notaTotal = 0;
  double maximoTotal = 0;
  int itensAvaliativos = 0;

  final areas = templateData['areas'] as List;

  for (final area in areas) {
    final items = area['items'] as List;

    for (final item in items) {
      final tipo = item['type'] as String;
      final peso = double.tryParse(item['peso']?.toString() ?? '0') ?? 0;

      if (peso > 0) {
        // Só considerar itens com peso > 0
        maximoTotal += peso;

        if (tipo == 'Avaliativo Sim/Não' && item['respostaBoolean'] != null) {
          final resposta = item['respostaBoolean'] as bool;

          if (resposta) {
            notaTotal += peso;
          } else {
            final naoPeso =
                double.tryParse(item['naoPeso']?.toString() ?? '0') ?? 0;
            notaTotal += naoPeso;
          }
          itensAvaliativos++;
        } else if (tipo == 'Avaliativo Emojis' &&
            item['respostaEmoji'] != null) {
          final resposta = item['respostaEmoji'] as String;
          final opcoes = item['emojiRatingOptions'] as List;

          for (final opcao in opcoes) {
            if (opcao['valor'] == resposta) {
              final pesoOpcao = (opcao['peso'] as num?)?.toDouble() ?? 0;
              notaTotal += pesoOpcao;
              break;
            }
          }
          itensAvaliativos++;
        }
      }
    }
  }

  return {
    'nota_final':
        itensAvaliativos > 0 ? double.parse(notaTotal.toStringAsFixed(2)) : 0.0,
    'maximo_possivel': maximoTotal,
    'itens_avaliados': itensAvaliativos,
  };
}

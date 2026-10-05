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

import 'checklist_offline.dart';

Future<String> salvarRespostaEmoji(
  String checklistDataJson,
  String areaId,
  String itemId,
  String resposta,
) async {
  final fields = <String, dynamic>{
    'respostaEmoji': resposta,
    'precisa_plano_acao': false,
  };

  final envelope = decodeChecklistEnvelope(checklistDataJson);
  final templateData = envelope == null ? null : templateDataFromEnvelope(envelope);
  if (templateData != null) {
    for (final area in templateData['areas'] as List? ?? []) {
      if (area is! Map || area['id']?.toString() != areaId) continue;
      for (final item in area['items'] as List? ?? []) {
        if (item is! Map || item['id']?.toString() != itemId) continue;
        final opcoes = item['emojiRatingOptions'] as List? ?? [];
        for (final opcao in opcoes) {
          if (opcao is Map && opcao['valor']?.toString() == resposta) {
            final requisitos =
                opcao['requisitos'] as Map<String, dynamic>? ?? {};
            if (requisitos['plano_acao'] == true) {
              fields['precisa_plano_acao'] = true;
            }
          }
        }
      }
    }
  }

  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: fields,
  );
}

Future<String> salvarRespostaOpcao(
  String checklistDataJson,
  String areaId,
  String itemId,
  String resposta,
) {
  final fields = <String, dynamic>{
    'respostaOpcao': resposta,
    'precisa_plano_acao': false,
  };

  final envelope = decodeChecklistEnvelope(checklistDataJson);
  final templateData =
      envelope == null ? null : templateDataFromEnvelope(envelope);
  if (templateData != null) {
    for (final area in templateData['areas'] as List? ?? []) {
      if (area is! Map || area['id']?.toString() != areaId) continue;
      for (final item in area['items'] as List? ?? []) {
        if (item is! Map || item['id']?.toString() != itemId) continue;
        final opcoes = item['options'] as List? ?? [];
        for (final opcao in opcoes) {
          if (opcao is! Map) continue;
          final match = opcao['valor']?.toString() == resposta ||
              opcao['label']?.toString() == resposta ||
              opcao['texto']?.toString() == resposta ||
              opcao['name']?.toString() == resposta;
          if (!match) continue;
          final requisitos = opcao['requisitos'];
          if (requisitos is Map &&
              (requisitos['plano_acao'] == true ||
                  requisitos['plano_acao'] == 1 ||
                  requisitos['plano_acao'] == '1')) {
            fields['precisa_plano_acao'] = true;
          }
        }
      }
    }
  }

  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: fields,
  );
}

Future<String> salvarRespostaNumero(
  String checklistDataJson,
  String areaId,
  String itemId,
  num? resposta,
) {
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {'respostaNumero': resposta},
  );
}

Future<String> salvarRespostaData(
  String checklistDataJson,
  String areaId,
  String itemId,
  String resposta,
) {
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {'respostaData': resposta},
  );
}

Future<String> salvarRespostaBoolean(
  String checklistDataJson,
  String areaId,
  String itemId,
  bool? resposta,
) {
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {'respostaBoolean': resposta},
  );
}

Future<String> salvarComentarioItemChecklist(
  String checklistDataJson,
  String areaId,
  String itemId,
  String comentario,
) {
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {
      'respostaComentario': comentario,
      'comentario': comentario,
    },
  );
}

Future<String> salvarPlanoAcaoItemChecklist(
  String checklistDataJson,
  String areaId,
  String itemId,
  String descricao,
  String prazo,
  String prioridade,
  int? responsavelId,
  String responsavelNome, {
  List<dynamic>? anexos,
}) {
  final plano = {
    'descricao': descricao.trim(),
    'prazo': prazo.trim().isEmpty ? null : prazo.trim(),
    'prioridade': prioridade.trim().isEmpty ? 'media' : prioridade.trim(),
    'responsavel_id': responsavelId,
    'responsavel_nome': responsavelNome.trim(),
    'responsavel': responsavelNome.trim(),
    'anexos': anexos ?? <dynamic>[],
  };
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {
      'planoAcao': plano['descricao'].toString().isEmpty ? null : plano,
      'precisa_plano_acao': false,
    },
  );
}

Future<String> salvarAnexosComplementaresItemChecklist(
  String checklistDataJson,
  String areaId,
  String itemId,
  List<dynamic> anexos,
) {
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {'anexosComplementares': anexos},
  );
}

Future<String> salvarAnexosRespostaItemChecklist(
  String checklistDataJson,
  String areaId,
  String itemId,
  List<dynamic> anexos,
) {
  return applyChecklistAnswerAndPersist(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: {'anexos': anexos},
  );
}

/// Reabre um preenchido local (rascunho ou respondido) no envelope do app.
Future<String> carregarChecklistPreenchido(String uuid) async {
  try {
    final db = await SQLiteManager.instance.database;
    final rows = await db.query(
      'checklists_preenchidos',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (rows.isEmpty) {
      return jsonEncodeErro('Checklist preenchido não encontrado');
    }
    final row = rows.first;
    final templateId = row['checklist_template_id'];
    var templateName = 'Checklist';
    var templateDescricao = '';
    if (templateId != null) {
      final templates = await db.query(
        'checklists_templates',
        where: 'id = ?',
        whereArgs: [templateId],
        limit: 1,
      );
      if (templates.isNotEmpty) {
        templateName = templates.first['nome']?.toString() ?? templateName;
        templateDescricao =
            templates.first['descricao']?.toString() ?? '';
      }
    }

    dynamic respostas = row['json_respostas'];
    Map<String, dynamic> templateData;
    if (respostas is String && respostas.trim().isNotEmpty) {
      templateData = Map<String, dynamic>.from(json.decode(respostas) as Map);
    } else if (respostas is Map) {
      templateData = Map<String, dynamic>.from(respostas);
    } else {
      templateData = {'areas': <dynamic>[]};
    }

    // Normaliza tipos ao reabrir.
    final areas = (templateData['areas'] as List? ?? [])
        .map((a) => Map<String, dynamic>.from(a as Map))
        .toList();
    for (final area in areas) {
      final items = (area['items'] as List? ?? [])
          .map((i) => Map<String, dynamic>.from(i as Map))
          .toList();
      for (final item in items) {
        item['type'] = normalizeChecklistItemType(item['type']);
      }
      area['items'] = items;
    }
    templateData['areas'] = areas;

    final situacao = (row['situacao'] ?? 'preenchendo').toString();
    final envelope = {
      'uuid': row['uuid'],
      'template_data': templateData,
      'template_id': templateId,
      'template_uuid': row['checklist_template_uuid'],
      'obra_id': row['obra_id'],
      'obra_uuid': row['obra_uuid'],
      'usuario_id': row['usuario_id'],
      'usuario_uuid': row['usuario_uuid'],
      'template_name': templateName,
      'template_descricao': templateDescricao,
      'status': situacao == 'concluido' ? 'respondido' : situacao,
      'nota_final': row['nota_final'],
      'data_criacao': row['created_at'],
      'ultima_atualizacao': row['updated_at'],
    };
    final jsonStr = json.encode(envelope);
    FFAppState().update(() {
      FFAppState().checklistAtualJson = jsonStr;
    });
    return jsonStr;
  } catch (e) {
    return jsonEncodeErro(e.toString());
  }
}

String jsonEncodeErro(String mensagem) =>
    json.encode({'erro': true, 'mensagem': mensagem});

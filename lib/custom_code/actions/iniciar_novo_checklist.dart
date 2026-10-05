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

import 'checklist_offline.dart';

Future<String> iniciarNovoChecklist(
  int templateId,
  int obraId,
  int usuarioId,
) async {
  try {
    final db = await SQLiteManager.instance.database;

    final templates = await db.query(
      'checklists_templates',
      where: 'id = ?',
      whereArgs: [templateId],
      limit: 1,
    );
    if (templates.isEmpty) {
      throw Exception('Template de checklist não encontrado');
    }

    final template = templates.first;
    final templateUuid = (template['uuid'] ?? '').toString();
    final templateJson = template['json_config'] as String?;
    if (templateJson == null || templateJson.trim().isEmpty) {
      throw Exception('Campo json_config não encontrado ou está nulo');
    }

    final templateData =
        Map<String, dynamic>.from(json.decode(templateJson) as Map);
    if (templateData['areas'] == null) {
      throw Exception('Template sem áreas definidas');
    }

    final checklistComRespostas = _inicializarRespostas(templateData);
    final uuid = _generateUuid();
    final now = DateTime.now().toIso8601String();
    final creatorUuid = FFAppState().creatorUuid.trim();
    final userUuid = FFAppState().UserUuid.trim();

    String? obraUuid;
    final obraLocal = await db.query(
      'obras',
      columns: ['uuid'],
      where: 'id = ?',
      whereArgs: [obraId],
      limit: 1,
    );
    if (obraLocal.isNotEmpty) {
      final u = (obraLocal.first['uuid'] ?? '').toString().trim();
      if (u.isNotEmpty) obraUuid = u;
    }
    if (obraUuid == null || obraUuid.isEmpty) {
      final obraRows = await db.query(
        'sync_id_mapping',
        columns: ['uuid'],
        where: 'tabela = ? AND id_servidor = ?',
        whereArgs: ['obras', obraId],
        limit: 1,
      );
      if (obraRows.isNotEmpty) {
        obraUuid = obraRows.first['uuid']?.toString();
      }
    }

    await db.insert('checklists_preenchidos', {
      'uuid': uuid,
      'checklist_template_id': templateId,
      'checklist_template_uuid':
          templateUuid.isEmpty ? null : templateUuid,
      'obra_id': obraId,
      'obra_uuid': obraUuid,
      'usuario_id': usuarioId,
      'usuario_uuid': userUuid.isEmpty ? null : userUuid,
      'json_respostas': json.encode(checklistComRespostas),
      'nota_final': null,
      'situacao': 'preenchendo',
      'created_by': creatorUuid.isNotEmpty ? creatorUuid : userUuid,
      'synced': 0,
      'sync_try_count': 0,
      'last_sync_date': null,
      'created_at': now,
      'updated_at': now,
    });

    final resultado = {
      'uuid': uuid,
      'template_data': checklistComRespostas,
      'template_id': templateId,
      'template_uuid': templateUuid,
      'obra_id': obraId,
      'obra_uuid': obraUuid,
      'usuario_id': usuarioId,
      'usuario_uuid': userUuid,
      'template_name': template['nome'] ?? 'Checklist sem nome',
      'template_descricao': template['descricao'] ?? '',
      'status': 'preenchendo',
      'data_criacao': now,
      'versao_template': templateData['versao'] ?? '1.0',
    };

    return json.encode(resultado);
  } catch (e) {
    return json.encode({
      'erro': true,
      'mensagem': e.toString(),
      'template_id': templateId,
      'obra_id': obraId,
    });
  }
}

Map<String, dynamic> _inicializarRespostas(Map<String, dynamic> template) {
  final templateComRespostas = Map<String, dynamic>.from(template);
  final areas = (template['areas'] as List? ?? []);

  final novasAreas = areas.map<Map<String, dynamic>>((area) {
    final areaMap = Map<String, dynamic>.from(area as Map);
    final items = areaMap['items'] as List? ?? [];

    final novosItems = items.map<Map<String, dynamic>>((item) {
      final itemMap = Map<String, dynamic>.from(item as Map);
      final tipo = normalizeChecklistItemType(itemMap['type']);
      itemMap['type'] = tipo;

      itemMap['respostaComentario'] ??= itemMap['comentario'];
      itemMap['anexosComplementares'] ??= <dynamic>[];
      itemMap['anexosComplementaresOpcao'] ??= <dynamic>[];
      itemMap['planoAcao'] ??= null;

      switch (tipo) {
        case 'Avaliativo Sim/Não':
          itemMap['respostaBoolean'] ??= null;
          break;
        case 'Avaliativo Emojis':
          itemMap['respostaEmoji'] ??= null;
          break;
        case 'Texto':
        case 'Cadastro':
          itemMap['respostaTexto'] ??= null;
          break;
        case 'Data':
          itemMap['respostaData'] ??= null;
          break;
        case 'Número':
          itemMap['respostaNumero'] ??= null;
          break;
        case 'Opção':
          itemMap['respostaOpcao'] ??= null;
          break;
        case 'Anexo':
          itemMap['anexos'] ??= <dynamic>[];
          break;
        default:
          itemMap['resposta'] ??= null;
      }
      return itemMap;
    }).toList();

    areaMap['items'] = novosItems;
    return areaMap;
  }).toList();

  templateComRespostas['areas'] = novasAreas;
  templateComRespostas['comentario_geral'] ??= null;
  templateComRespostas['assinatura'] ??= null;
  templateComRespostas['anexos_gerais'] ??= <dynamic>[];
  templateComRespostas['data_inicio_preenchimento'] =
      DateTime.now().toIso8601String();
  return templateComRespostas;
}

String _generateUuid() {
  final random = Random();
  const hexDigits = '0123456789abcdef';
  String part(int length) =>
      List.generate(length, (_) => hexDigits[random.nextInt(16)]).join();
  return '${part(8)}-${part(4)}-4${part(3)}-${part(4)}-${part(12)}';
}

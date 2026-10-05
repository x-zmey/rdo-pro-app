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

Future<String> finalizarChecklist(
  String checklistDataJson,
  String comentarioGeral,
  String assinatura,
) async {
  try {
    final db = await SQLiteManager.instance.database;
    final checklistData = decodeChecklistEnvelope(checklistDataJson);
    if (checklistData == null || checklistData['erro'] == true) {
      throw Exception('Checklist inválido para finalizar');
    }

    final templateData = templateDataFromEnvelope(checklistData);
    if (templateData == null) {
      throw Exception('template_data ausente');
    }

    templateData['comentario_geral'] = comentarioGeral;
    templateData['assinatura'] = assinatura.isNotEmpty ? assinatura : null;
    templateData['data_conclusao'] = DateTime.now().toIso8601String();

    final calculoNota = _calcularNotaFinal(templateData);
    final notaFinal = (calculoNota['nota_final'] as num?)?.toDouble() ?? 0.0;
    final maximoPossivel =
        (calculoNota['maximo_possivel'] as num?)?.toDouble() ?? 0.0;

    final uuid = (checklistData['uuid'] ?? '').toString().trim();
    if (uuid.isEmpty) {
      throw Exception('UUID do checklist ausente');
    }

    final now = DateTime.now().toIso8601String();
    final existing = await db.query(
      'checklists_preenchidos',
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );

    final row = <String, dynamic>{
      'checklist_template_id': checklistData['template_id'],
      'checklist_template_uuid': checklistData['template_uuid'],
      'obra_id': checklistData['obra_id'],
      'obra_uuid': checklistData['obra_uuid'],
      'usuario_id': checklistData['usuario_id'],
      'usuario_uuid': checklistData['usuario_uuid'],
      'json_respostas': json.encode(templateData),
      'nota_final': notaFinal,
      'situacao': 'respondido',
      'created_by': FFAppState().creatorUuid.trim().isNotEmpty
          ? FFAppState().creatorUuid.trim()
          : checklistData['usuario_uuid'],
      'synced': 0,
      'updated_at': now,
    };

    int idSqlite;
    if (existing.isNotEmpty) {
      await db.update(
        'checklists_preenchidos',
        row,
        where: 'uuid = ?',
        whereArgs: [uuid],
      );
      idSqlite = existing.first['id'] as int? ?? 0;
    } else {
      row['uuid'] = uuid;
      row['created_at'] = checklistData['data_criacao'] ?? now;
      idSqlite = await db.insert('checklists_preenchidos', row);
    }

    if (idSqlite > 0) {
      await _criarPlanosAcaoLocais(
        db: db,
        checklistLocalId: idSqlite,
        checklistData: checklistData,
        templateData: templateData,
        now: now,
      );
    }

    checklistData['template_data'] = templateData;
    checklistData['status'] = 'respondido';
    checklistData['nota_final'] = notaFinal;
    final envelope = json.encode(checklistData);
    FFAppState().update(() {
      FFAppState().checklistAtualJson = envelope;
    });

    return json.encode({
      'sucesso': true,
      'mensagem': 'Checklist finalizado com sucesso!',
      'uuid': uuid,
      'nota_final': notaFinal,
      'maximo_possivel': maximoPossivel,
      'id_sqlite': idSqlite,
      'template_nome': checklistData['template_name'],
    });
  } catch (e) {
    return json.encode({
      'sucesso': false,
      'mensagem': 'Erro ao finalizar checklist: $e',
      'erro': e.toString(),
    });
  }
}

Future<void> _criarPlanosAcaoLocais({
  required dynamic db,
  required int checklistLocalId,
  required Map<String, dynamic> checklistData,
  required Map<String, dynamic> templateData,
  required String now,
}) async {
  final areas = templateData['areas'] as List? ?? [];
  final createdBy = FFAppState().UserID > 0
      ? FFAppState().UserID
      : (int.tryParse(checklistData['usuario_id']?.toString() ?? '') ?? 0);

  for (final area in areas) {
    if (area is! Map) continue;
    final areaId = int.tryParse(area['id']?.toString() ?? '');
    final items = area['items'] as List? ?? [];
    for (final item in items) {
      if (item is! Map) continue;
      final plano = item['planoAcao'];
      if (plano is! Map) continue;
      final descricao = (plano['descricao'] ?? '').toString().trim();
      if (descricao.isEmpty) continue;

      final itemId = int.tryParse(item['id']?.toString() ?? '');
      await db.insert('planos_acoes', {
        'uuid': _generateUuid(),
        'checklist_preenchido_id': checklistLocalId,
        'area_id': areaId,
        'item_id': itemId,
        'descricao': descricao,
        'area': area['name']?.toString(),
        'pergunta': item['description']?.toString(),
        'resposta': item['respostaOpcao']?.toString() ??
            item['respostaEmoji']?.toString() ??
            item['respostaBoolean']?.toString(),
        'prazo': plano['prazo'],
        'prioridade': plano['prioridade'] ?? 'media',
        'anexos': json.encode(plano['anexos'] is List ? plano['anexos'] : []),
        'responsavel_id': plano['responsavel_id'],
        'responsavel_uuid': plano['responsavel_uuid'],
        'checklist_preenchido_uuid': checklistData['uuid']?.toString(),
        'created_by': createdBy,
        'status': 'Em andamento',
        'historico': json.encode([
          {'data': now, 'descricao': 'Plano criado'},
        ]),
        'synced': 0,
        'sync_try_count': 0,
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}

Map<String, dynamic> _calcularNotaFinal(Map<String, dynamic> templateData) {
  double notaTotal = 0;
  double maximoTotal = 0;
  var itensAvaliativos = 0;

  final areas = templateData['areas'] as List? ?? [];
  for (final area in areas) {
    if (area is! Map) continue;
    final items = area['items'] as List? ?? [];
    for (final item in items) {
      if (item is! Map) continue;
      final tipo = normalizeChecklistItemType(item['type']);
      final peso = double.tryParse(item['peso']?.toString() ?? '0') ?? 0;
      if (peso <= 0) continue;
      maximoTotal += peso;

      if (tipo == 'Avaliativo Sim/Não' && item['respostaBoolean'] != null) {
        final resposta = item['respostaBoolean'] == true;
        if (resposta) {
          notaTotal += peso;
        } else {
          notaTotal +=
              double.tryParse(item['naoPeso']?.toString() ?? '0') ?? 0;
        }
        itensAvaliativos++;
      } else if (tipo == 'Avaliativo Emojis' &&
          item['respostaEmoji'] != null) {
        final resposta = item['respostaEmoji'].toString();
        final opcoes = item['emojiRatingOptions'] as List? ?? [];
        for (final opcao in opcoes) {
          if (opcao is Map && opcao['valor']?.toString() == resposta) {
            notaTotal += (opcao['peso'] as num?)?.toDouble() ?? 0;
            break;
          }
        }
        itensAvaliativos++;
      } else if (tipo == 'Opção' && item['respostaOpcao'] != null) {
        final resposta = item['respostaOpcao'].toString();
        final opcoes = item['options'] as List? ?? [];
        for (final opcao in opcoes) {
          if (opcao is Map && opcao['texto']?.toString() == resposta) {
            notaTotal += (opcao['peso'] as num?)?.toDouble() ?? peso;
            break;
          }
        }
        itensAvaliativos++;
      } else if (_itemRespondido(tipo, item)) {
        notaTotal += peso;
        itensAvaliativos++;
      }
    }
  }

  final notaPercent = maximoTotal > 0 ? (notaTotal / maximoTotal) * 100 : 0.0;
  return {
    'nota_final': double.parse(notaPercent.toStringAsFixed(2)),
    'maximo_possivel': maximoTotal,
    'itens_avaliados': itensAvaliativos,
  };
}

bool _itemRespondido(String tipo, Map item) {
  switch (tipo) {
    case 'Texto':
    case 'Cadastro':
      return (item['respostaTexto']?.toString() ?? '').trim().isNotEmpty;
    case 'Data':
      return item['respostaData'] != null;
    case 'Número':
      return item['respostaNumero'] != null;
    case 'Anexo':
      return (item['anexos'] as List? ?? []).isNotEmpty;
    default:
      return item['resposta'] != null;
  }
}

String _generateUuid() {
  final random = Random();
  const hexDigits = '0123456789abcdef';
  String part(int length) =>
      List.generate(length, (_) => hexDigits[random.nextInt(16)]).join();
  return '${part(8)}-${part(4)}-4${part(3)}-${part(4)}-${part(12)}';
}

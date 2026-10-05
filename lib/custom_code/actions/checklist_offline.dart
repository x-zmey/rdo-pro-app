import 'dart:convert';

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Normaliza labels de tipo do template (legado FlutterFlow vs web).
String normalizeChecklistItemType(dynamic raw) {
  final t = (raw ?? '').toString().trim();
  switch (t.toLowerCase()) {
    case 'texto longo':
    case 'texto':
      return 'Texto';
    case 'opções':
    case 'opcoes':
    case 'opção':
    case 'opcao':
      return 'Opção';
    case 'avaliativo sim/não':
    case 'avaliativo sim/nao':
    case 'sim/não':
    case 'sim/nao':
      return 'Avaliativo Sim/Não';
    case 'avaliativo emojis':
    case 'emojis':
      return 'Avaliativo Emojis';
    case 'número':
    case 'numero':
      return 'Número';
    case 'data':
      return 'Data';
    case 'cadastro':
      return 'Cadastro';
    case 'anexo':
    case 'arquivo':
      return 'Anexo';
    default:
      return t.isEmpty ? 'Texto' : t;
  }
}

Map<String, dynamic>? decodeChecklistEnvelope(String raw) {
  try {
    if (raw.trim().isEmpty) return null;
    final decoded = json.decode(raw);
    if (decoded is! Map) return null;
    return Map<String, dynamic>.from(decoded);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? templateDataFromEnvelope(Map<String, dynamic> envelope) {
  final td = envelope['template_data'];
  if (td is Map) return Map<String, dynamic>.from(td);
  return null;
}

/// Atualiza um campo do item e devolve o envelope JSON completo.
String patchChecklistItemField({
  required String checklistDataJson,
  required String areaId,
  required String itemId,
  required Map<String, dynamic> fields,
}) {
  final envelope = decodeChecklistEnvelope(checklistDataJson);
  if (envelope == null) {
    return json.encode({
      'erro': true,
      'mensagem': 'Checklist inválido',
    });
  }
  final templateData = templateDataFromEnvelope(envelope);
  if (templateData == null) {
    return json.encode({
      'erro': true,
      'mensagem': 'template_data ausente',
    });
  }

  final areas = (templateData['areas'] as List? ?? [])
      .map((e) => Map<String, dynamic>.from(e as Map))
      .toList();
  var found = false;

  for (final area in areas) {
    if (area['id']?.toString() != areaId) continue;
    final items = (area['items'] as List? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
    for (var i = 0; i < items.length; i++) {
      if (items[i]['id']?.toString() != itemId) continue;
      found = true;
      items[i] = {...items[i], ...fields};
      items[i]['type'] = normalizeChecklistItemType(items[i]['type']);
    }
    area['items'] = items;
  }

  if (!found) {
    return json.encode({
      'erro': true,
      'mensagem': 'Item não encontrado: área $areaId item $itemId',
    });
  }

  templateData['areas'] = areas;
  envelope['template_data'] = templateData;
  envelope['ultima_atualizacao'] = DateTime.now().toIso8601String();
  envelope['status'] = envelope['status'] == 'respondido'
      ? 'respondido'
      : 'preenchendo';
  return json.encode(envelope);
}

Future<void> persistChecklistEnvelope(String checklistDataJson) async {
  final envelope = decodeChecklistEnvelope(checklistDataJson);
  if (envelope == null || envelope['erro'] == true) return;

  FFAppState().update(() {
    FFAppState().checklistAtualJson = checklistDataJson;
  });

  final uuid = (envelope['uuid'] ?? '').toString().trim();
  if (uuid.isEmpty) return;

  final templateData = templateDataFromEnvelope(envelope);
  final db = await SQLiteManager.instance.database;
  final now = DateTime.now().toIso8601String();

  final existing = await db.query(
    'checklists_preenchidos',
    columns: ['id', 'situacao'],
    where: 'uuid = ?',
    whereArgs: [uuid],
    limit: 1,
  );
  if (existing.isEmpty) return;

  final situacaoAtual = (existing.first['situacao'] ?? '').toString();
  if (situacaoAtual == 'respondido' || situacaoAtual == 'concluido') {
    return;
  }

  await db.update(
    'checklists_preenchidos',
    {
      'json_respostas':
          templateData == null ? null : json.encode(templateData),
      'situacao': 'preenchendo',
      'synced': 0,
      'updated_at': now,
    },
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
}

Future<String> applyChecklistAnswerAndPersist({
  required String checklistDataJson,
  required String areaId,
  required String itemId,
  required Map<String, dynamic> fields,
}) async {
  final next = patchChecklistItemField(
    checklistDataJson: checklistDataJson,
    areaId: areaId,
    itemId: itemId,
    fields: fields,
  );
  await persistChecklistEnvelope(next);
  return next;
}

bool checklistJsonHasError(String raw) {
  final m = decodeChecklistEnvelope(raw);
  return m != null && m['erro'] == true;
}

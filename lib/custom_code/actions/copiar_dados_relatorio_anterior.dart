// Automatic FlutterFlow imports
import '/backend/sqlite/sqlite_manager.dart';
import 'index.dart'; // Imports other custom actions
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

/// Opções alinhadas à web (`opcoesCopiar`): sem fotos.
/// Valores: atividades | ocorrencias | controleMateriais | comentarios | mao_obra
///
/// [anteriorRelatorioUuid] deve ser resolvido **antes** de criar o novo RDO.
Future<void> copiarDadosRelatorioAnterior({
  required int novoRelatorioId,
  required String novoRelatorioUuid,
  required String anteriorRelatorioUuid,
  required String dataReferencia,
  required List<String> tiposParaCopiar,
  required int companyId,
  required String companyUuid,
  required String createdByUuid,
}) async {
  final tipos = tiposParaCopiar
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toSet()
      .toList();
  if (tipos.isEmpty) return;

  final antUuid = anteriorRelatorioUuid.trim();
  if (antUuid.isEmpty || antUuid == novoRelatorioUuid.trim()) return;

  final db = SQLiteManager.instance.database;
  final agora = DateTime.now().toUtc().toIso8601String();

  for (final tipo in tipos) {
    try {
      switch (tipo) {
        case 'atividades':
          await _copiarAtividades(
            db,
            antUuid: antUuid,
            novoId: novoRelatorioId,
            novoUuid: novoRelatorioUuid,
            createdBy: createdByUuid,
            agora: agora,
          );
          break;
        case 'ocorrencias':
          await _copiarOcorrencias(
            db,
            antUuid: antUuid,
            novoId: novoRelatorioId,
            novoUuid: novoRelatorioUuid,
            createdBy: createdByUuid,
            agora: agora,
          );
          break;
        case 'controleMateriais':
          await _copiarMateriais(
            db,
            antUuid: antUuid,
            novoId: novoRelatorioId,
            novoUuid: novoRelatorioUuid,
            createdBy: createdByUuid,
            agora: agora,
          );
          break;
        case 'comentarios':
          await _copiarComentarios(
            db,
            antUuid: antUuid,
            novoId: novoRelatorioId,
            novoUuid: novoRelatorioUuid,
            createdBy: createdByUuid,
            agora: agora,
          );
          break;
        case 'mao_obra':
          await _copiarMaoObra(
            db,
            antUuid: antUuid,
            novoId: novoRelatorioId,
            novoUuid: novoRelatorioUuid,
            dataReferencia: dataReferencia,
            companyId: companyId,
            companyUuid: companyUuid,
            createdBy: createdByUuid,
            agora: agora,
          );
          break;
      }
    } catch (e) {
      debugPrint('Erro ao copiar "$tipo" do relatório anterior: $e');
    }
  }

  await db.rawUpdate(
    'UPDATE relatorios SET updated_at = ?, synced = 0 WHERE id = ?',
    [agora, novoRelatorioId],
  );
}

Future<void> _copiarAtividades(
  Database db, {
  required String antUuid,
  required int novoId,
  required String novoUuid,
  required String createdBy,
  required String agora,
}) async {
  final atividades = await db.rawQuery('''
SELECT * FROM relatorio_atividades
WHERE relatorio_uuid = ?
  AND (situacao IS NULL OR (CAST(situacao AS INTEGER) != $kSituacaoExcluidoLogico
       AND CAST(situacao AS INTEGER) != -1))
ORDER BY id ASC
''', [antUuid]);

  for (final a in atividades) {
    final novaAtivUuid = await generateUuid();
    await db.rawInsert('''
INSERT INTO relatorio_atividades (
  uuid, user_id, user_uuid, relatorio_id, relatorio_uuid,
  ordem_id, ordem_uuid, tarefa_id, tarefa_uuid, item, local, descricao,
  quantidade, unidade, qtd_realizada, created_by, situacao, updated_at, synced
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, 0)
''', [
      novaAtivUuid,
      a['user_id'],
      a['user_uuid']?.toString() ?? '',
      novoId,
      novoUuid,
      a['ordem_id'],
      a['ordem_uuid']?.toString(),
      a['tarefa_id'],
      a['tarefa_uuid']?.toString() ?? '',
      a['item']?.toString(),
      a['local']?.toString(),
      a['descricao']?.toString(),
      a['quantidade'] ?? 0,
      a['unidade']?.toString(),
      createdBy,
      kSituacaoAtivo,
      agora,
    ]);

    final novaAtivRows = await db.rawQuery(
      'SELECT id FROM relatorio_atividades WHERE uuid = ? LIMIT 1',
      [novaAtivUuid],
    );
    final novaAtivId =
        novaAtivRows.isEmpty ? null : novaAtivRows.first['id'] as int?;
    if (novaAtivId == null) continue;

    // Itens apenas — fotos NÃO são copiadas (igual opção web sem "Fotos").
    final itens = await db.rawQuery('''
SELECT * FROM relatorio_atividades_itens
WHERE relatorio_atividade_uuid = ?
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != $kSituacaoExcluidoLogico)
''', [a['uuid']?.toString()]);

    for (final item in itens) {
      final novoItemUuid = await generateUuid();
      await db.rawInsert('''
INSERT INTO relatorio_atividades_itens (
  uuid, relatorio_atividade_id, relatorio_atividade_uuid, tipo,
  obra_item_id, obra_item_uuid, qtd_utilizada, qtd_realizada, qtd_produzida,
  situacao, created_by, updated_at, synced
) VALUES (?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?, 0)
''', [
        novoItemUuid,
        novaAtivId,
        novaAtivUuid,
        item['tipo']?.toString() ?? '',
        item['obra_item_id'],
        item['obra_item_uuid']?.toString() ?? '',
        item['qtd_utilizada'] ?? 0,
        item['qtd_produzida'] ?? 0,
        kSituacaoAtivo,
        createdBy,
        agora,
      ]);
    }
  }
}

Future<void> _copiarOcorrencias(
  Database db, {
  required String antUuid,
  required int novoId,
  required String novoUuid,
  required String createdBy,
  required String agora,
}) async {
  final rows = await db.rawQuery('''
SELECT * FROM relatorio_ocorrencias
WHERE relatorio_uuid = ?
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != $kSituacaoExcluidoLogico)
''', [antUuid]);

  for (final o in rows) {
    final uuid = await generateUuid();
    await db.rawInsert('''
INSERT INTO relatorio_ocorrencias (
  uuid, user_id, user_uuid, relatorio_id, relatorio_uuid, descricao, tipo_uuid,
  hora_inicio, hora_saida, created_by, situacao, updated_at, synced
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
''', [
      uuid,
      o['user_id'],
      o['user_uuid']?.toString() ?? createdBy,
      novoId,
      novoUuid,
      o['descricao']?.toString() ?? '',
      o['tipo_uuid']?.toString() ?? '',
      o['hora_inicio']?.toString(),
      o['hora_saida']?.toString(),
      createdBy,
      kSituacaoAtivo,
      agora,
    ]);
  }
}

Future<void> _copiarMateriais(
  Database db, {
  required String antUuid,
  required int novoId,
  required String novoUuid,
  required String createdBy,
  required String agora,
}) async {
  final rows = await db.rawQuery('''
SELECT * FROM relatorio_equipamento_recebido
WHERE relatorio_uuid = ?
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != $kSituacaoExcluidoLogico)
''', [antUuid]);

  for (final m in rows) {
    final uuid = await generateUuid();
    await db.rawInsert('''
INSERT INTO relatorio_equipamento_recebido (
  uuid, relatorio_id, relatorio_uuid, equipamento_id, equipamento_uuid,
  quantidade, created_by, situacao, updated_at, synced
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
''', [
      uuid,
      novoId,
      novoUuid,
      m['equipamento_id'],
      m['equipamento_uuid']?.toString() ?? '',
      m['quantidade'] ?? 0,
      createdBy,
      kSituacaoAtivo,
      agora,
    ]);
  }
}

Future<void> _copiarComentarios(
  Database db, {
  required String antUuid,
  required int novoId,
  required String novoUuid,
  required String createdBy,
  required String agora,
}) async {
  final rows = await db.rawQuery('''
SELECT * FROM relatorio_comentarios
WHERE relatorio_uuid = ?
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != $kSituacaoExcluidoLogico)
''', [antUuid]);

  for (final c in rows) {
    final uuid = await generateUuid();
    await db.rawInsert('''
INSERT INTO relatorio_comentarios (
  uuid, relatorio_id, relatorio_uuid, texto, created_by, situacao,
  created_at, updated_at, synced
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0)
''', [
      uuid,
      novoId,
      novoUuid,
      c['texto']?.toString() ?? '',
      createdBy,
      kSituacaoAtivo,
      agora,
      agora,
    ]);
  }
}

Future<void> _copiarMaoObra(
  Database db, {
  required String antUuid,
  required int novoId,
  required String novoUuid,
  required String dataReferencia,
  required int companyId,
  required String companyUuid,
  required String createdBy,
  required String agora,
}) async {
  final rel = await db.rawQuery(
    'SELECT entrada_manha, saida_tarde, inicio_intervalo, fim_intervalo FROM relatorios WHERE uuid = ? LIMIT 1',
    [novoUuid],
  );
  String hora(String key, String fallback) {
    if (rel.isEmpty) return fallback;
    final v = rel.first[key]?.toString().trim() ?? '';
    return v.isEmpty ? fallback : v;
  }

  final entrada = hora('entrada_manha', '08:00');
  final saida = hora('saida_tarde', '17:00');
  final intIni = hora('inicio_intervalo', '11:00');
  final intFim = hora('fim_intervalo', '13:00');

  final rows = await db.rawQuery('''
SELECT * FROM relatorio_mao_obra_presenca
WHERE relatorio_uuid = ?
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != $kSituacaoExcluidoLogico)
''', [antUuid]);

  for (final p in rows) {
    final uuid = await generateUuid();
    final status = p['status_presenca']?.toString() ?? 'presente';
    await db.rawInsert('''
INSERT INTO relatorio_mao_obra_presenca (
  uuid, relatorio_id, relatorio_uuid, company_id, company_uuid,
  obra_item_id, obra_item_uuid, data_referencia, status_presenca,
  hora_entrada, hora_saida, intervalo_inicio, intervalo_fim, horas_trabalhadas,
  created_by, created_at, situacao, motivo_saida_cedo, motivo_ausencia,
  updated_at, synced
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL, ?, ?, 0)
''', [
      uuid,
      novoId,
      novoUuid,
      companyId,
      companyUuid,
      p['obra_item_id'],
      p['obra_item_uuid']?.toString() ?? '',
      dataReferencia,
      status,
      entrada,
      saida,
      intIni,
      intFim,
      '8',
      createdBy,
      agora,
      kSituacaoAtivo,
      p['motivo_ausencia']?.toString(),
      agora,
    ]);
  }
}

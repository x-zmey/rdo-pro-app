import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '/backend/sqlite/situacao_soft_delete.dart';

const _origensVinculadas = {'insumo', 'mao_obra', 'equipamento'};

double _sqlNum(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().trim().replaceAll(',', '.')) ?? 0;
}

int _sqlInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim()) ?? 0;
}

bool _sqlBool(dynamic v) {
  if (v == true || v == 1 || v == '1') return true;
  return false;
}

/// Custos da OS vinculados (insumo / mão de obra / equipamento) passam a
/// refletir o consumo das atividades deste RDO. Avulsos não são alterados.
///
/// Mão de obra e equipamento: campo Real. (`qtd_realizada` — HH/HM).
/// Insumo: Util. (`qtd_utilizada`), com fallback para realizado.
/// Itens com `qtd_manual = 1` não são sobrescritos.
Future<void> performSincronizarCustosOsComUsoAtividades(
  Database database, {
  int? relatorioId,
  String? relatorioUuid,
}) async {
  var rid = relatorioId ?? 0;
  final ruuid = (relatorioUuid ?? '').trim();
  if (rid < 1 && ruuid.isNotEmpty) {
    final rows = await database.rawQuery(
      'SELECT id FROM relatorios WHERE uuid = ? LIMIT 1',
      [ruuid],
    );
    if (rows.isNotEmpty) {
      rid = _sqlInt(rows.first['id']);
    }
  }
  if (rid < 1) return;

  try {
    await _aplicar(database, rid);
  } catch (e) {
    // Não bloqueia o save da atividade se o recálculo falhar.
    debugPrint('⚠️ Falha ao sincronizar custos da OS com atividades: $e');
  }
}

/// Ao alterar Real./Util. na atividade, libera override manual do custo OS
/// do mesmo obra_item + origem para o sync aplicar de novo.
Future<void> performLiberarManualCustoOsDoItemAtividade(
  Database database, {
  String? itemUuid,
}) async {
  final uuid = (itemUuid ?? '').trim();
  if (uuid.isEmpty) return;

  try {
    final rows = await database.rawQuery(
      '''
SELECT
  rai.tipo AS tipo,
  rai.obra_item_id AS obra_item_id,
  TRIM(COALESCE(NULLIF(rai.obra_item_uuid, ''), oi.uuid, '')) AS obra_item_uuid,
  ra.relatorio_id AS relatorio_id
FROM relatorio_atividades_itens AS rai
INNER JOIN relatorio_atividades AS ra
  ON (
    rai.relatorio_atividade_id IS NOT NULL
    AND ra.id = rai.relatorio_atividade_id
  )
  OR (
    rai.relatorio_atividade_id IS NULL
    AND TRIM(COALESCE(rai.relatorio_atividade_uuid, '')) != ''
    AND LOWER(TRIM(ra.uuid)) = LOWER(TRIM(rai.relatorio_atividade_uuid))
  )
LEFT JOIN obra_itens AS oi
  ON (
    rai.obra_item_id IS NOT NULL
    AND oi.id = rai.obra_item_id
  )
  OR (
    (rai.obra_item_id IS NULL OR rai.obra_item_id = 0)
    AND TRIM(COALESCE(rai.obra_item_uuid, '')) != ''
    AND LOWER(TRIM(oi.uuid)) = LOWER(TRIM(rai.obra_item_uuid))
  )
WHERE rai.uuid = ?
LIMIT 1
''',
      [uuid],
    );
    if (rows.isEmpty) return;

    final row = rows.first;
    final tipo = (row['tipo'] as String? ?? '').trim().toLowerCase();
    if (!_origensVinculadas.contains(tipo)) return;

    final rid = _sqlInt(row['relatorio_id']);
    final oid = _sqlInt(row['obra_item_id']);
    final oiUuid = (row['obra_item_uuid'] as String? ?? '').trim();
    if (rid < 1 || (oid < 1 && oiUuid.isEmpty)) return;

    final ts = DateTime.now().toUtc().toIso8601String();
    await database.rawUpdate(
      '''
UPDATE relatorio_custos
SET qtd_manual = 0, updated_at = ?, synced = 0
WHERE relatorio_id = ?
  AND COALESCE(qtd_manual, 0) = 1
  AND ${sqlNaoExcluidoPorSituacao('relatorio_custos')}
  AND ordem_servico_custo_uuid IN (
    SELECT cos.uuid FROM ordem_servico_custos AS cos
    WHERE LOWER(TRIM(COALESCE(cos.origem, ''))) = ?
      AND (
        (? > 0 AND cos.obra_item_id = ?)
        OR (? != '' AND LOWER(TRIM(COALESCE(cos.obra_item_uuid, ''))) = LOWER(?))
      )
  )
''',
      [ts, rid, tipo, oid, oid, oiUuid, oiUuid],
    );
  } catch (e) {
    debugPrint('⚠️ Falha ao liberar qtd_manual do custo OS: $e');
  }
}

Future<void> _aplicar(Database database, int relatorioId) async {
  final usoRows = await database.rawQuery(
    '''
SELECT
  rai.tipo AS tipo,
  rai.obra_item_id AS obra_item_id,
  TRIM(COALESCE(NULLIF(rai.obra_item_uuid, ''), oi.uuid, '')) AS obra_item_uuid,
  SUM(
    CASE
      WHEN rai.tipo IN ('mao_obra', 'equipamento') THEN COALESCE(rai.qtd_realizada, 0)
      ELSE COALESCE(
        NULLIF(rai.qtd_utilizada, 0),
        rai.qtd_realizada,
        0
      )
    END
  ) AS qtd
FROM relatorio_atividades_itens AS rai
INNER JOIN relatorio_atividades AS ra
  ON (
    rai.relatorio_atividade_id IS NOT NULL
    AND ra.id = rai.relatorio_atividade_id
  )
  OR (
    rai.relatorio_atividade_id IS NULL
    AND TRIM(COALESCE(rai.relatorio_atividade_uuid, '')) != ''
    AND LOWER(TRIM(ra.uuid)) = LOWER(TRIM(rai.relatorio_atividade_uuid))
  )
LEFT JOIN obra_itens AS oi
  ON (
    rai.obra_item_id IS NOT NULL
    AND oi.id = rai.obra_item_id
  )
  OR (
    (rai.obra_item_id IS NULL OR rai.obra_item_id = 0)
    AND TRIM(COALESCE(rai.obra_item_uuid, '')) != ''
    AND LOWER(TRIM(oi.uuid)) = LOWER(TRIM(rai.obra_item_uuid))
  )
WHERE ra.relatorio_id = ?
  AND ${sqlNaoExcluidoPorSituacao('rai')}
  AND ${sqlNaoExcluidoPorSituacao('ra')}
  AND rai.tipo IN ('insumo', 'mao_obra', 'equipamento')
GROUP BY rai.tipo, rai.obra_item_id, obra_item_uuid
''',
    [relatorioId],
  );

  final uso = <String, double>{};
  for (final row in usoRows) {
    final tipo = (row['tipo'] as String? ?? '').trim();
    if (!_origensVinculadas.contains(tipo)) continue;
    final qtd = _sqlNum(row['qtd']);
    final oid = _sqlInt(row['obra_item_id']);
    final uuid = (row['obra_item_uuid'] as String? ?? '').trim();
    if (oid > 0) {
      uso['$tipo|id:$oid'] = (uso['$tipo|id:$oid'] ?? 0) + qtd;
    }
    if (uuid.isNotEmpty) {
      uso['$tipo|uuid:$uuid'] = (uso['$tipo|uuid:$uuid'] ?? 0) + qtd;
    }
  }

  final custos = await database.rawQuery(
    '''
SELECT
  rc.uuid AS rc_uuid,
  rc.qtd_realizada AS qtd_realizada,
  rc.valor_unitario_real AS valor_unitario_real,
  COALESCE(rc.qtd_manual, 0) AS qtd_manual,
  cos.origem AS origem,
  cos.fixo AS fixo,
  cos.obra_item_id AS obra_item_id,
  TRIM(COALESCE(cos.obra_item_uuid, '')) AS obra_item_uuid
FROM relatorio_custos AS rc
INNER JOIN ordem_servico_custos AS cos
  ON cos.uuid = rc.ordem_servico_custo_uuid
  OR (rc.ordem_servico_custo_id IS NOT NULL AND cos.id = rc.ordem_servico_custo_id)
WHERE rc.relatorio_id = ?
  AND ${sqlNaoExcluidoPorSituacao('rc')}
''',
    [relatorioId],
  );

  final ts = DateTime.now().toUtc().toIso8601String();

  for (final custo in custos) {
    final rcUuid = (custo['rc_uuid'] as String? ?? '').trim();
    if (rcUuid.isEmpty) continue;

    final fixo = _sqlInt(custo['fixo']) == 1;
    if (fixo) {
      if (_sqlNum(custo['qtd_realizada']) != 0) {
        await _gravarQtd(database, rcUuid, 0, _sqlNum(custo['valor_unitario_real']), ts);
      }
      continue;
    }

    var origem = (custo['origem'] as String? ?? '').trim().toLowerCase();
    if (origem.isEmpty) origem = 'avulso';
    if (!_origensVinculadas.contains(origem)) {
      continue;
    }

    // Valor editado manualmente no RDO: não sobrescrever com o uso das atividades.
    if (_sqlBool(custo['qtd_manual'])) {
      continue;
    }

    final oid = _sqlInt(custo['obra_item_id']);
    final uuid = (custo['obra_item_uuid'] as String? ?? '').trim();
    var qtd = 0.0;
    if (uuid.isNotEmpty) {
      qtd = uso['$origem|uuid:$uuid'] ?? 0;
    }
    if (qtd == 0 && oid > 0) {
      qtd = uso['$origem|id:$oid'] ?? 0;
    }
    qtd = double.parse(qtd.toStringAsFixed(2));

    if (( _sqlNum(custo['qtd_realizada']) - qtd ).abs() < 0.001) {
      continue;
    }

    await _gravarQtd(
      database,
      rcUuid,
      qtd,
      _sqlNum(custo['valor_unitario_real']),
      ts,
    );
  }
}

Future<void> _gravarQtd(
  Database database,
  String uuid,
  double qtd,
  double valorUnitario,
  String ts,
) async {
  await database.rawUpdate(
    '''
UPDATE relatorio_custos SET
  qtd_realizada = ?,
  valor_total_real = ? * ?,
  updated_at = ?,
  synced = 0
WHERE uuid = ?
''',
    [qtd, qtd, valorUnitario, ts, uuid],
  );
}

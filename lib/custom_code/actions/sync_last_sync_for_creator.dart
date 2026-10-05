import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';

List<Map<String, dynamic>> _rowsAsDynamicMaps(List<Map<String, Object?>> raw) =>
    raw.map((e) => Map<String, dynamic>.from(e)).toList();

/// **Creator** neste módulo = **tenant / dono da conta**, não o usuário logado (colaborador).
/// Alinha-se ao `getCreatorId()` da API.

/// UUID do tenant (gravado em `created_by` TEXT onde o schema usa o dono da conta).
String currentCreatorUuidForSync() => FFAppState().creatorUuid.trim();

/// ID numérico do tenant (`relatorios.user_id` no SQLite espelha o MySQL).
int currentCreatorIdForSync() => FFAppState().creatorId;

/// Relatórios pendentes (`synced = 0`): `created_by` = UUID do **tenant**, não do user logado.
Future<List<Map<String, dynamic>>> pendingRelatoriosForCurrentCreator(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT r.* FROM relatorios AS r
WHERE r.synced = 0
  AND LOWER(TRIM(COALESCE(r.created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Upload atividades: só esta tabela; `created_by` = tenant, sem JOIN.
Future<List<Map<String, dynamic>>> pendingRelatorioAtividadesForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_atividades
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Compat: mesmo que [pendingRelatorioAtividadesForTenantSimple].
Future<List<Map<String, dynamic>>> pendingRelatorioAtividadesForCurrentCreator(
        Database db) =>
    pendingRelatorioAtividadesForTenantSimple(db);

/// Upload itens de atividade: só esta tabela; `created_by` = tenant, sem JOIN.
Future<List<Map<String, dynamic>>> pendingRelatorioAtividadesItensForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_atividades_itens
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Compat: mesmo que [pendingRelatorioAtividadesItensForTenantSimple].
Future<List<Map<String, dynamic>>>
    pendingRelatorioAtividadesItensForCurrentCreator(Database db) =>
        pendingRelatorioAtividadesItensForTenantSimple(db);

/// Upload fotos de atividade: só esta tabela; `created_by` = tenant, sem JOIN.
Future<List<Map<String, dynamic>>> pendingRelatorioAtividadeFotosForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_atividade_fotos
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Compat: mesmo que [pendingRelatorioAtividadeFotosForTenantSimple].
Future<List<Map<String, dynamic>>>
    pendingRelatorioAtividadeFotosForCurrentCreator(Database db) =>
        pendingRelatorioAtividadeFotosForTenantSimple(db);

/// Preenche `created_by` em itens pendentes que ainda estão vazios ou com valor que não
/// parece UUID (legado), desde que a atividade/relatório pertença ao tenant atual (JOIN legado).
/// Preferir [stampPendingRelatorioAtividadesItensCreatedByTenantFallback] no fluxo de sync.
Future<int> stampPendingRelatorioAtividadesItensCreatedByForCurrentCreator(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_atividades_itens AS i
SET created_by = ?
WHERE (i.synced IS NULL OR i.synced = 0)
  AND (
    TRIM(COALESCE(i.created_by, '')) = ''
    OR INSTR(TRIM(i.created_by), '-') = 0
  )
  AND EXISTS (
    SELECT 1 FROM relatorio_atividades AS ra
    INNER JOIN relatorios AS r ON r.id = ra.relatorio_id
    WHERE (
      (i.relatorio_atividade_id IS NOT NULL AND ra.id = i.relatorio_atividade_id)
      OR (
        TRIM(COALESCE(i.relatorio_atividade_uuid, '')) != ''
        AND LOWER(TRIM(ra.uuid)) = LOWER(TRIM(i.relatorio_atividade_uuid))
      )
    )
    AND (
      LOWER(TRIM(COALESCE(r.user_uuid, ''))) = LOWER(?)
      OR LOWER(TRIM(COALESCE(r.criador, ''))) = LOWER(?)
      OR LOWER(TRIM(COALESCE(r.created_by, ''))) = LOWER(?)
    )
  )
''',
    [cu, cu, cu, cu],
  );
}

/// Stamp `created_by` = UUID do tenant em **todas** as linhas pendentes de [relatorio_atividades_itens].
Future<int> stampPendingRelatorioAtividadesItensCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_atividades_itens
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Mesma lógica para atividades de relatório pendentes (`created_by` vazio ou legado numérico).
Future<int> stampPendingRelatorioAtividadesCreatedByForCurrentCreator(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_atividades AS ra
SET created_by = ?
WHERE (ra.synced IS NULL OR ra.synced = 0)
  AND (
    TRIM(COALESCE(ra.created_by, '')) = ''
    OR INSTR(TRIM(ra.created_by), '-') = 0
  )
  AND EXISTS (
    SELECT 1 FROM relatorios AS r
    WHERE r.id = ra.relatorio_id
    AND (
      LOWER(TRIM(COALESCE(r.user_uuid, ''))) = LOWER(?)
      OR LOWER(TRIM(COALESCE(r.criador, ''))) = LOWER(?)
      OR LOWER(TRIM(COALESCE(r.created_by, ''))) = LOWER(?)
    )
  )
''',
    [cu, cu, cu, cu],
  );
}

/// Stamp `created_by` = UUID do tenant em **todas** as linhas pendentes de [relatorio_atividades].
Future<int> stampPendingRelatorioAtividadesCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_atividades
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Fotos de atividade idem (evita fila de upload vazia com `created_by` legado).
Future<int> stampPendingRelatorioAtividadeFotosCreatedByForCurrentCreator(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_atividade_fotos AS f
SET created_by = ?
WHERE (f.synced IS NULL OR f.synced = 0)
  AND (
    TRIM(COALESCE(f.created_by, '')) = ''
    OR INSTR(TRIM(f.created_by), '-') = 0
  )
  AND EXISTS (
    SELECT 1 FROM relatorio_atividades AS ra
    INNER JOIN relatorios AS r ON r.id = ra.relatorio_id
    WHERE (
      (f.relatorio_atividade_id IS NOT NULL AND ra.id = f.relatorio_atividade_id)
      OR (
        TRIM(COALESCE(f.relatorio_atividade_uuid, '')) != ''
        AND LOWER(TRIM(ra.uuid)) = LOWER(TRIM(f.relatorio_atividade_uuid))
      )
    )
    AND (
      LOWER(TRIM(COALESCE(r.user_uuid, ''))) = LOWER(?)
      OR LOWER(TRIM(COALESCE(r.criador, ''))) = LOWER(?)
      OR LOWER(TRIM(COALESCE(r.created_by, ''))) = LOWER(?)
    )
  )
''',
    [cu, cu, cu, cu],
  );
}

/// Stamp `created_by` = UUID do tenant em **todas** as linhas pendentes de [relatorio_atividade_fotos].
Future<int> stampPendingRelatorioAtividadeFotosCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_atividade_fotos
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Alinha **todas** as linhas pendentes com `created_by` = UUID do tenant (conta).
///
/// O fallback antigo só tratava vazio ou texto sem `-`; no device apareceram valores
/// corrompidos (segmentos com tamanho errado, caracteres não hex) que ainda continham `-`,
/// não batiam com [currentCreatorUuidForSync].
Future<int> stampPendingRelatorioEquipamentoRecebidoCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_equipamento_recebido
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Upload de materiais recebidos: só esta tabela, sem JOIN — `created_by` = UUID do tenant.
Future<List<Map<String, dynamic>>> pendingRelatorioEquipamentoRecebidoForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_equipamento_recebido
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Após download de materiais recebidos: atualiza `last_sync_date` só por `created_by` (tenant).
Future<void> updateLastSyncEquipamentoRecebidoSyncedForTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_equipamento_recebido
SET last_sync_date = ?
WHERE synced = 1
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Uma query em [relatorios] por linha: preenche [relatorio_uuid] no mapa do payload (sync sem JOIN na lista).
Future<void> backfillRelatorioUuidForPayloadRow(
    Database db, Map<String, dynamic> row) async {
  final existing = (row['relatorio_uuid']?.toString() ?? '').trim();
  if (existing.isNotEmpty) return;
  final rid = row['relatorio_id'];
  final id = rid is int ? rid : int.tryParse(rid?.toString() ?? '');
  if (id == null || id < 1) return;
  final q = await db.query(
    'relatorios',
    columns: ['uuid'],
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (q.isEmpty) return;
  final u = q.first['uuid']?.toString().trim();
  if (u != null && u.isNotEmpty) row['relatorio_uuid'] = u;
}

/// Uma query em [relatorio_atividades] por linha: preenche [relatorio_atividade_uuid] no payload (sync sem JOIN na lista).
Future<void> backfillRelatorioAtividadeUuidForPayloadRow(
    Database db, Map<String, dynamic> row) async {
  final existing =
      (row['relatorio_atividade_uuid']?.toString() ?? '').trim();
  if (existing.isNotEmpty) return;
  final aid = row['relatorio_atividade_id'];
  final id = aid is int ? aid : int.tryParse(aid?.toString() ?? '');
  if (id == null || id < 1) return;
  final q = await db.query(
    'relatorio_atividades',
    columns: ['uuid'],
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (q.isEmpty) return;
  final u = q.first['uuid']?.toString().trim();
  if (u != null && u.isNotEmpty) row['relatorio_atividade_uuid'] = u;
}

/// Uma query em [obra_itens] por linha: preenche [obra_item_uuid] no payload (sync sem JOIN na lista).
Future<void> backfillObraItemUuidForPayloadRow(
    Database db, Map<String, dynamic> row) async {
  final existing = (row['obra_item_uuid']?.toString() ?? '').trim();
  if (existing.isNotEmpty) return;
  final oid = row['obra_item_id'];
  final id = oid is int ? oid : int.tryParse(oid?.toString() ?? '');
  if (id == null || id < 1) return;
  final q = await db.query(
    'obra_itens',
    columns: ['uuid'],
    where: 'id = ?',
    whereArgs: [id],
    limit: 1,
  );
  if (q.isEmpty) return;
  final u = q.first['uuid']?.toString().trim();
  if (u != null && u.isNotEmpty) row['obra_item_uuid'] = u;
}

/// Stamp `created_by` = UUID do tenant nas linhas pendentes de [relatorio_mao_obra_presenca].
Future<int> stampPendingRelatorioMaoObraPresencaCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_mao_obra_presenca
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Upload presenças: só esta tabela; filtro `created_by` = tenant, sem JOIN com [relatorios].
Future<List<Map<String, dynamic>>> pendingRelatorioMaoObraPresencaForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_mao_obra_presenca
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Após download de presenças: `last_sync_date` só por `created_by` (tenant).
Future<void> updateLastSyncMaoObraPresencaSyncedForTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_mao_obra_presenca
SET last_sync_date = ?
WHERE synced = 1
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Stamp `created_by` = UUID do tenant nas linhas pendentes de [relatorio_comentarios].
Future<int> stampPendingRelatorioComentariosCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_comentarios
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Upload comentários: só esta tabela; filtro `created_by` = tenant, sem JOIN.
Future<List<Map<String, dynamic>>> pendingRelatorioComentariosForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_comentarios
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Após download de comentários: `last_sync_date` só por `created_by` (tenant).
Future<void> updateLastSyncRelatorioComentariosSyncedForTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_comentarios
SET last_sync_date = ?
WHERE synced = 1
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Stamp `created_by` = UUID do tenant nas linhas pendentes de [relatorio_ocorrencias].
Future<int> stampPendingRelatorioOcorrenciasCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_ocorrencias
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Upload ocorrências: só esta tabela; filtro `created_by` = tenant, sem JOIN.
Future<List<Map<String, dynamic>>> pendingRelatorioOcorrenciasForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_ocorrencias
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

/// Após download de ocorrências: `last_sync_date` só por `created_by` (tenant).
Future<void> updateLastSyncRelatorioOcorrenciasSyncedForTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_ocorrencias
SET last_sync_date = ?
WHERE synced = 1
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Stamp `created_by` = UUID do tenant nas linhas pendentes de [relatorio_ordem_servico].
Future<int> stampPendingRelatorioOrdemServicoCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_ordem_servico
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Upload vínculo relatório × OS: só esta tabela; `created_by` = tenant, sem JOIN.
Future<List<Map<String, dynamic>>> pendingRelatorioOrdemServicoForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_ordem_servico
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

Future<void> updateLastSyncRelatorioOrdemServicoSyncedForTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_ordem_servico
SET last_sync_date = ?
WHERE synced = 1
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Stamp `created_by` = UUID do tenant nas linhas pendentes de [relatorio_custos].
Future<int> stampPendingRelatorioCustosCreatedByTenantFallback(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return 0;
  return await db.rawUpdate(
    '''
UPDATE relatorio_custos
SET created_by = ?
WHERE (synced IS NULL OR synced = 0)
''',
    [cu],
  );
}

/// Upload custos do relatório: só esta tabela; `created_by` = tenant, sem JOIN.
Future<List<Map<String, dynamic>>> pendingRelatorioCustosForTenantSimple(
    Database db) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return [];
  final raw = await db.rawQuery(
    '''
SELECT * FROM relatorio_custos
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [cu],
  );
  return _rowsAsDynamicMaps(raw);
}

Future<void> updateLastSyncRelatorioCustosSyncedForTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_custos
SET last_sync_date = ?
WHERE synced = 1
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Filhos do relatório (`relatorio_id`): escopo pelo **relatório pai** (tenant da conta).
/// O SQLite costuma espelhar o tenant em `relatorios.user_uuid` / `created_by`; coluna
/// `criador` no relatório é quem preencheu o RDO (pode ser colaborador), distinto do tenant.
Future<List<Map<String, dynamic>>> pendingRowsForCurrentCreatorViaRelatorio(
  Database db, {
  required String table,
  required String alias,
  required String pendingSql,
}) async {
  final cu = currentCreatorUuidForSync();
  final cid = currentCreatorIdForSync();
  if (cu.isEmpty && cid <= 0) return [];
  final raw = await db.rawQuery(
    '''
SELECT $alias.* FROM $table AS $alias
INNER JOIN relatorios AS r ON (
  (
    COALESCE($alias.relatorio_id, 0) > 0
    AND r.id = $alias.relatorio_id
  )
  OR (
    COALESCE($alias.relatorio_id, 0) <= 0
    AND TRIM(COALESCE($alias.relatorio_uuid, '')) != ''
    AND LOWER(TRIM(r.uuid)) = LOWER(TRIM($alias.relatorio_uuid))
  )
)
WHERE $pendingSql
  AND (
    (
      ? != ''
      AND (
        LOWER(TRIM(COALESCE(r.user_uuid, ''))) = LOWER(?)
        OR LOWER(TRIM(COALESCE(r.criador, ''))) = LOWER(?)
        OR LOWER(TRIM(COALESCE(r.created_by, ''))) = LOWER(?)
      )
    )
    OR (
      ? > 0
      AND (
        COALESCE(r.user_id, 0) = ?
        OR TRIM(COALESCE(CAST(r.criador AS TEXT), '')) = ?
      )
    )
  )
''',
    [
      cu,
      cu,
      cu,
      cu,
      cid,
      cid,
      cid.toString(),
    ],
  );
  return _rowsAsDynamicMaps(raw);
}

Future<void> updateRelatoriosLastSyncForCurrentTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorios SET last_sync_date = ?
WHERE synced = 1
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

Future<void> updateRelatorioAtividadesLastSyncForCurrentTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_atividades AS ra SET last_sync_date = ?
WHERE ra.synced = 1
  AND LOWER(TRIM(COALESCE(ra.created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Alias explícito (mesmo SQL que [updateRelatorioAtividadesLastSyncForCurrentTenant]).
Future<void> updateLastSyncRelatorioAtividadesSyncedForTenant(
  Database db,
  String serverTime,
) =>
    updateRelatorioAtividadesLastSyncForCurrentTenant(db, serverTime);

Future<void> updateRelatorioAtividadesItensLastSyncForCurrentTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_atividades_itens AS rai SET last_sync_date = ?
WHERE rai.synced = 1
  AND LOWER(TRIM(COALESCE(rai.created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Alias explícito (mesmo SQL que [updateRelatorioAtividadesItensLastSyncForCurrentTenant]).
Future<void> updateLastSyncRelatorioAtividadesItensSyncedForTenant(
  Database db,
  String serverTime,
) =>
    updateRelatorioAtividadesItensLastSyncForCurrentTenant(db, serverTime);

Future<void> updateRelatorioAtividadeFotosLastSyncForCurrentTenant(
  Database db,
  String serverTime,
) async {
  final cu = currentCreatorUuidForSync();
  if (cu.isEmpty) return;
  await db.rawUpdate(
    '''
UPDATE relatorio_atividade_fotos AS f SET last_sync_date = ?
WHERE f.synced = 1
  AND LOWER(TRIM(COALESCE(f.created_by, ''))) = LOWER(?)
''',
    [serverTime, cu],
  );
}

/// Alias explícito (mesmo SQL que [updateRelatorioAtividadeFotosLastSyncForCurrentTenant]).
Future<void> updateLastSyncRelatorioAtividadeFotosSyncedForTenant(
  Database db,
  String serverTime,
) =>
    updateRelatorioAtividadeFotosLastSyncForCurrentTenant(db, serverTime);

Future<void> updateLastSyncForSyncedRowsViaRelatorioIdForCurrentTenant(
  Database db, {
  required String table,
  required String alias,
  required String serverTime,
}) async {
  final cu = currentCreatorUuidForSync();
  final cid = currentCreatorIdForSync();
  if (cu.isEmpty && cid <= 0) return;
  await db.rawUpdate(
    '''
UPDATE $table AS $alias SET last_sync_date = ?
WHERE $alias.synced = 1 AND EXISTS (
  SELECT 1 FROM relatorios AS r
  WHERE (
    (
      COALESCE($alias.relatorio_id, 0) > 0
      AND r.id = $alias.relatorio_id
    )
    OR (
      COALESCE($alias.relatorio_id, 0) <= 0
      AND TRIM(COALESCE($alias.relatorio_uuid, '')) != ''
      AND LOWER(TRIM(r.uuid)) = LOWER(TRIM($alias.relatorio_uuid))
    )
  )
  AND (
    (
      ? != ''
      AND (
        LOWER(TRIM(COALESCE(r.user_uuid, ''))) = LOWER(?)
        OR LOWER(TRIM(COALESCE(r.criador, ''))) = LOWER(?)
        OR LOWER(TRIM(COALESCE(r.created_by, ''))) = LOWER(?)
      )
    )
    OR (
      ? > 0
      AND (
        COALESCE(r.user_id, 0) = ?
        OR TRIM(COALESCE(CAST(r.criador AS TEXT), '')) = ?
      )
    )
  )
)
''',
    [
      serverTime,
      cu,
      cu,
      cu,
      cu,
      cid,
      cid,
      cid.toString(),
    ],
  );
}

/// Valor inicial quando não há histórico **desta conta** no SQLite.
const String kSyncEpoch = '2000-01-01T00:00:00.000Z';

Future<bool> _tableHasColumn(
  dynamic db,
  String table,
  String column,
) async {
  try {
    final pragma = await db.rawQuery('PRAGMA table_info($table)');
    return pragma.any((row) => row['name']?.toString() == column);
  } catch (_) {
    return false;
  }
}

/// Marca d'água incremental por **conta**: filtra por `created_by` = UUID do **tenant**
/// quando a coluna existe; senão `user_uuid`; senão epoch.
Future<String> lastSyncDateForCurrentCreator(String table) async {
  final db = await SQLiteManager.instance.database;
  final creator = FFAppState().creatorUuid.trim();
  if (creator.isEmpty) return kSyncEpoch;
  try {
    final hasUserUuid = await _tableHasColumn(db, table, 'user_uuid');
    final hasCreatedBy = await _tableHasColumn(db, table, 'created_by');
    final hasLastSync = await _tableHasColumn(db, table, 'last_sync_date');
    if (!hasLastSync) return kSyncEpoch;

    final Map<String, Object?> queryArgs = {
      'columns': ['last_sync_date'],
      'orderBy': 'last_sync_date DESC',
      'limit': 1,
    };
    if (hasCreatedBy) {
      queryArgs['where'] = "LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)";
      queryArgs['whereArgs'] = [creator];
    } else if (hasUserUuid) {
      queryArgs['where'] = 'user_uuid = ?';
      queryArgs['whereArgs'] = [creator];
    }

    final result = await db.query(
      table,
      columns: queryArgs['columns'] as List<String>,
      where: queryArgs['where'] as String?,
      whereArgs: queryArgs['whereArgs'] as List<Object?>?,
      orderBy: queryArgs['orderBy'] as String?,
      limit: queryArgs['limit'] as int?,
    );
    if (result.isNotEmpty && result.first['last_sync_date'] != null) {
      final s = result.first['last_sync_date'].toString();
      if (s.isNotEmpty) return s;
    }
  } catch (e) {
    print('lastSyncDateForCurrentCreator($table): $e');
  }
  return kSyncEpoch;
}

/// Tabela `users`: amarra pelo UUID do **tenant** (dono da equipe), não pelo user logado.
Future<String> lastSyncDateForUsersTable() async {
  final db = await SQLiteManager.instance.database;
  final creator = FFAppState().creatorUuid.trim();
  if (creator.isEmpty) return kSyncEpoch;
  try {
    final result = await db.query(
      'users',
      columns: ['last_sync_date'],
      where: 'created_by = ?',
      whereArgs: [creator],
      orderBy: 'last_sync_date DESC',
      limit: 1,
    );
    if (result.isNotEmpty && result.first['last_sync_date'] != null) {
      final s = result.first['last_sync_date'].toString();
      if (s.isNotEmpty) return s;
    }
  } catch (e) {
    print('lastSyncDateForUsersTable: $e');
  }
  return kSyncEpoch;
}

/// Equipamentos e demais tabelas sem `last_sync_date`: watermark por `updated_at` do tenant.
Future<String> updatedAtWatermarkForCurrentCreator(String table) async {
  final db = await SQLiteManager.instance.database;
  final creator = FFAppState().creatorUuid.trim();
  if (creator.isEmpty) return kSyncEpoch;
  try {
    final hasCreatedBy = await _tableHasColumn(db, table, 'created_by');
    final hasUserUuid = await _tableHasColumn(db, table, 'user_uuid');
    String? where;
    List<Object?>? whereArgs;
    if (hasCreatedBy) {
      where = "LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)";
      whereArgs = [creator];
    } else if (hasUserUuid) {
      where = 'user_uuid = ?';
      whereArgs = [creator];
    }
    final result = await db.query(
      table,
      columns: ['updated_at'],
      where: where,
      whereArgs: whereArgs,
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    if (result.isNotEmpty && result.first['updated_at'] != null) {
      final s = result.first['updated_at'].toString();
      if (s.isNotEmpty) return s;
    }
  } catch (e) {
    print('updatedAtWatermarkForCurrentCreator($table): $e');
  }
  return kSyncEpoch;
}

/// Prefixo das datas de full resync diário (calendário local).
const String _kDailyFullResyncPrefix = 'daily_full_resync_';

String _localDateStamp([DateTime? when]) {
  final n = when ?? DateTime.now();
  final y = n.year.toString().padLeft(4, '0');
  final m = n.month.toString().padLeft(2, '0');
  final d = n.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

/// True se ainda não houve full resync neste dia (hora local do aparelho).
///
/// Recupera registros que o watermark incremental deixou de fora
/// (mesmo sintoma de “só voltou depois de desinstalar”), sem nova versão do app.
Future<bool> shouldForceDailyFullResync(String scope) async {
  final key = '$_kDailyFullResyncPrefix${scope.trim()}';
  if (scope.trim().isEmpty) return true;
  try {
    final prefs = await SharedPreferences.getInstance();
    final last = (prefs.getString(key) ?? '').trim();
    return last != _localDateStamp();
  } catch (_) {
    return true;
  }
}

/// Marca o full resync do [scope] como feito hoje.
Future<void> markDailyFullResyncDone(String scope) async {
  final key = '$_kDailyFullResyncPrefix${scope.trim()}';
  if (scope.trim().isEmpty) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, _localDateStamp());
  } catch (_) {}
}

/// Escopos que participam do full resync diário / botão “Sincronização completa”.
const List<String> kDailyFullResyncScopes = [
  'obras',
  'obra_itens',
  'obra_etapas',
  'obra_etapa_tarefas',
  'checklists_templates',
  'checklists_template_obras',
  'checklists_preenchidos',
];

/// Preferências one-shot legadas — zerar força novo download completo.
const List<String> _kLegacyOneShotFullResyncPrefs = [
  'obra_itens_full_resync_v2',
  'obras_full_resync_v2',
  'obras_full_resync_v3',
  'obra_etapas_full_resync_v2',
  'obra_etapa_tarefas_full_resync_v2',
];

/// Prepara o próximo sync para baixar tudo de novo (como reinstalar o app).
/// Usado pelo botão “Sincronização completa” na tela de sincronização.
Future<void> requestForcedFullResync() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    for (final scope in kDailyFullResyncScopes) {
      await prefs.remove('$_kDailyFullResyncPrefix$scope');
    }
    for (final key in _kLegacyOneShotFullResyncPrefs) {
      await prefs.setBool(key, false);
    }
    // Zera watermarks locais de checklist para o próximo download trazer tudo.
    final db = await SQLiteManager.instance.database;
    for (final table in [
      'checklists_templates',
      'checklists_template_obras',
      'checklists_template_categorias',
      'checklists_preenchidos',
    ]) {
      try {
        await db.update(table, {'last_sync_date': null});
      } catch (_) {}
    }
  } catch (_) {}
}

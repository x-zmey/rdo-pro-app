import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import 'empresa_multi_tenant_sqlite.dart';

Future<Database> initializeDatabaseFromDbFile(
  String databaseName,
  String databaseAssetFilename,
) async {
  final databasesPath = await getDatabasesPath();
  final path = '$databaseName.db';
  final databasePath = join(databasesPath, path);
  // First, check if the database exists.
  final exists = await databaseExists(databasePath);
  if (!exists) {
    // Ensure parent directory exists.
    try {
      await Directory(dirname(databasePath)).create(recursive: true);
    } catch (_) {}
    // Copy the database file over to the working database directory.
    final databaseData = await rootBundle
        .load(join('assets', 'sqlite_db_files', databaseAssetFilename));
    final databaseBytes = databaseData.buffer.asUint8List(
      databaseData.offsetInBytes,
      databaseData.lengthInBytes,
    );
    await File(databasePath).writeAsBytes(databaseBytes, flush: true);
  }
  // Initialize the SQLite database.
  final database =   await openDatabase(databasePath);
  await _ensureRelatorioChildSituacaoColumns(database);
  await _ensureRelatorioEquipamentoRecebidoTimestampSyncColumns(database);
  await _ensureRelatorioAtividadesItensCreatedByColumn(database);
  await _ensureRelatorioAtividadesItensQtdProduzidaColumn(database);
  await _migrateObrasLegacyBlobColumnsIfNeeded(database);
  await _ensureObrasFotoLocalColumn(database);
  await _ensureMotivoSaidaCedoMaoObraPresenca(database);
  await _ensureRelatorioAtividadesOrdemColumns(database);
  await _ensureOrdensServicoStatusIdColumn(database);
  await _ensureRelatorioAtividadeFotosArquivoServidor(database);
  await repairRelatorioAtividadeFotosFkQuebrada(database);
  await ensureRelatoriosHaveUuid(database);
  await normalizeRelatorioAtividadesForUpload(database);
  await normalizeRelatorioAtividadesItensForUpload(database);
  await normalizeRelatorioAtividadeFotosForUpload(database);
  await normalizeRelatorioEquipamentoRecebidoForUpload(database);
  await _ensureObraItensCargoFuncaoColumn(database);
  await _ensureOrdemServicoCustosVinculoColumns(database);
  await _ensureRelatorioCustosQtdManualColumn(database);
  await _ensureFuncoesMaoObraTable(database);
  await _ensureSolucoesPlanosAnexosColumn(database);
  await ensureEmpresaMultiTenantTables(database);
  await ensureSyncUuidUniqueIndexes(database);
  return database;
}

Future<void> _ensureSolucoesPlanosAnexosColumn(Database database) async {
  try {
    final info = await database.rawQuery('PRAGMA table_info(solucoes_planos_acoes)');
    if (info.isEmpty) return;
    final has = info.any((r) => r['name'] == 'anexos');
    if (has) return;
    await database.execute(
      'ALTER TABLE solucoes_planos_acoes ADD COLUMN anexos TEXT',
    );
  } catch (e) {
    // ignore: avoid_print
    print('⚠️ _ensureSolucoesPlanosAnexosColumn: $e');
  }
}

/// Remove duplicatas por UUID (case-insensitive) e cria índice UNIQUE nas tabelas de sync.
///
/// Evita que o download reinsira o mesmo registro quando o match por `uuid` falha
/// por casing/espaços ou quando não havia constraint no SQLite.
Future<void> ensureSyncUuidUniqueIndexes(Database database) async {
  const tables = <String>[
    'relatorios',
    'relatorio_atividades',
    'relatorio_atividades_itens',
    'relatorio_atividade_fotos',
    'relatorio_custos',
    'relatorio_ordem_servico',
    'relatorio_mao_obra_presenca',
    'relatorio_comentarios',
    'relatorio_anexos',
    'relatorio_equipamento_recebido',
    'relatorio_ocorrencias',
    'obras',
    'clientes',
    'ordens_servico',
    'checklists_preenchidos',
    'planos_acoes',
  ];

  for (final table in tables) {
    try {
      final info = await database.rawQuery('PRAGMA table_info($table)');
      if (info.isEmpty) continue;
      final hasUuid = info.any((r) => r['name'] == 'uuid');
      if (!hasUuid) continue;

      // Normaliza casing/espaços antes do índice.
      await database.execute('''
UPDATE $table
SET uuid = LOWER(TRIM(uuid))
WHERE uuid IS NOT NULL
  AND TRIM(uuid) != ''
  AND LOWER(TRIM(uuid)) != 'null'
  AND uuid != LOWER(TRIM(uuid))
''');

      await _dedupeSyncTableByUuid(database, table);

      final indexName = 'idx_${table}_uuid_unique';
      await database.execute('''
CREATE UNIQUE INDEX IF NOT EXISTS $indexName
ON $table (LOWER(TRIM(uuid)))
WHERE uuid IS NOT NULL
  AND TRIM(uuid) != ''
  AND LOWER(TRIM(uuid)) != 'null'
''');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ ensureSyncUuidUniqueIndexes($table): $e');
    }
  }
}

Future<void> _dedupeSyncTableByUuid(Database database, String table) async {
  final groups = await database.rawQuery('''
SELECT LOWER(TRIM(uuid)) AS u, COUNT(*) AS c
FROM $table
WHERE uuid IS NOT NULL
  AND TRIM(uuid) != ''
  AND LOWER(TRIM(uuid)) != 'null'
GROUP BY LOWER(TRIM(uuid))
HAVING c > 1
''');
  if (groups.isEmpty) return;

  final hasSynced = (await database.rawQuery('PRAGMA table_info($table)'))
      .any((r) => r['name'] == 'synced');

  for (final g in groups) {
    final u = g['u']?.toString();
    if (u == null || u.isEmpty) continue;

    final rows = await database.rawQuery(
      '''
SELECT id${hasSynced ? ', synced' : ''}
FROM $table
WHERE LOWER(TRIM(COALESCE(uuid, ''))) = ?
ORDER BY ${hasSynced ? 'CASE WHEN synced = 1 THEN 0 ELSE 1 END, ' : ''}id DESC
''',
      [u],
    );
    if (rows.length < 2) continue;

    final keepId = rows.first['id'];
    if (keepId == null) continue;

    for (var i = 1; i < rows.length; i++) {
      final dropId = rows[i]['id'];
      if (dropId == null) continue;

      // Remapeia FKs de filhas quando a tabela for atividades.
      if (table == 'relatorio_atividades') {
        try {
          await database.rawUpdate(
            '''
UPDATE relatorio_atividades_itens
SET relatorio_atividade_id = ?
WHERE relatorio_atividade_id = ?
''',
            [keepId, dropId],
          );
          await database.rawUpdate(
            '''
UPDATE relatorio_atividade_fotos
SET relatorio_atividade_id = ?
WHERE relatorio_atividade_id = ?
''',
            [keepId, dropId],
          );
        } catch (_) {}
      }

      await database.delete(table, where: 'id = ?', whereArgs: [dropId]);
    }
  }
}

/// Override manual do realizado na OS (igual ao MySQL `relatorio_custos.qtd_manual`).
Future<void> _ensureRelatorioCustosQtdManualColumn(Database database) async {
  try {
    final info = await database.rawQuery('PRAGMA table_info(relatorio_custos)');
    if (info.isEmpty) return;
    final has = info.any((row) => row['name'] == 'qtd_manual');
    if (has) return;
    await database.execute(
      'ALTER TABLE relatorio_custos ADD COLUMN qtd_manual INTEGER NOT NULL DEFAULT 0',
    );
  } catch (_) {}
}

Future<void> _ensureFuncoesMaoObraTable(Database database) async {
  try {
    await database.execute('''
CREATE TABLE IF NOT EXISTS funcoes_mao_obra (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  created_by TEXT,
  situacao INTEGER NOT NULL DEFAULT 1,
  synced INTEGER NOT NULL DEFAULT 0,
  sync_try_count INTEGER DEFAULT 0,
  last_sync_date TEXT,
  created_at TEXT,
  updated_at TEXT,
  deleted_at TEXT
)
''');
  } catch (_) {}
}

/// Preenche `relatorio_atividades_itens.created_by` (UUID texto) a partir do relatório pai.
Future<void> backfillRelatorioAtividadesItensCreatedByFromRelatorio(
  Database database,
) async {
  try {
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades_itens AS i
SET created_by = (
  SELECT COALESCE(
    NULLIF(TRIM(COALESCE(ra.user_uuid, '')), ''),
    NULLIF(TRIM(COALESCE(r.user_uuid, '')), ''),
    NULLIF(TRIM(COALESCE(r.criador, '')), ''),
    NULLIF(TRIM(COALESCE(ra.created_by, '')), ''),
    NULLIF(TRIM(COALESCE(r.created_by, '')), ''),
    ''
  )
  FROM relatorio_atividades AS ra
  INNER JOIN relatorios AS r ON r.id = ra.relatorio_id
  WHERE (
    (i.relatorio_atividade_id IS NOT NULL AND ra.id = i.relatorio_atividade_id)
    OR (
      TRIM(COALESCE(i.relatorio_atividade_uuid, '')) != ''
      AND LOWER(TRIM(ra.uuid)) = LOWER(TRIM(i.relatorio_atividade_uuid))
    )
  )
  LIMIT 1
)
WHERE TRIM(COALESCE(i.created_by, '')) = ''
  AND EXISTS (
    SELECT 1 FROM relatorio_atividades AS ra2
    WHERE (
      ra2.id = i.relatorio_atividade_id
      OR (
        TRIM(COALESCE(i.relatorio_atividade_uuid, '')) != ''
        AND LOWER(TRIM(ra2.uuid)) = LOWER(TRIM(i.relatorio_atividade_uuid))
      )
    )
  )
''',
    );
  } catch (_) {}
}

/// Coluna [created_by] em [relatorio_atividades_itens] (alinhada ao MySQL; asset novo já traz a coluna).
Future<void> _ensureRelatorioAtividadesItensCreatedByColumn(
  Database database,
) async {
  try {
    final info = await database
        .rawQuery('PRAGMA table_info(relatorio_atividades_itens)');
    if (info.isEmpty) return;
    final has =
        info.any((row) => (row['name'] as String?) == 'created_by');
    if (!has) {
      await database.execute(
        "ALTER TABLE relatorio_atividades_itens ADD COLUMN created_by TEXT NOT NULL DEFAULT ''",
      );
    }
    await backfillRelatorioAtividadesItensCreatedByFromRelatorio(database);
  } catch (_) {}
}

/// Coluna [qtd_produzida] em [relatorio_atividades_itens] (alinhada ao MySQL;
/// asset novo já traz a coluna; apps instalados recebem via ALTER TABLE).
Future<void> _ensureRelatorioAtividadesItensQtdProduzidaColumn(
  Database database,
) async {
  try {
    final info = await database
        .rawQuery('PRAGMA table_info(relatorio_atividades_itens)');
    if (info.isEmpty) return;
    final has =
        info.any((row) => (row['name'] as String?) == 'qtd_produzida');
    if (has) return;
    await database.execute(
      'ALTER TABLE relatorio_atividades_itens ADD COLUMN qtd_produzida NUMERIC DEFAULT 0',
    );
  } catch (_) {}
}

/// Coluna [cargo_funcao] em [obra_itens] (mão de obra espelhada; DBs antigos não tinham).
Future<void> _ensureObraItensCargoFuncaoColumn(Database database) async {
  try {
    final info = await database.rawQuery('PRAGMA table_info(obra_itens)');
    if (info.isEmpty) return;
    final has =
        info.any((row) => (row['name'] as String?) == 'cargo_funcao');
    if (has) return;
    await database.execute(
      'ALTER TABLE obra_itens ADD COLUMN cargo_funcao TEXT',
    );
  } catch (_) {}
}

/// `origem`, `fixo` e vínculo com `obra_itens` em custos da OS (igual ao MySQL).
Future<void> _ensureOrdemServicoCustosVinculoColumns(Database database) async {
  try {
    final info =
        await database.rawQuery('PRAGMA table_info(ordem_servico_custos)');
    if (info.isEmpty) return;
    final names = info
        .map((row) => row['name'] as String?)
        .whereType<String>()
        .toSet();

    Future<void> add(String name, String def) async {
      if (names.contains(name)) return;
      await database.execute(
        'ALTER TABLE ordem_servico_custos ADD COLUMN $name $def',
      );
      names.add(name);
    }

    await add('origem', 'TEXT');
    await add('fixo', 'INTEGER NOT NULL DEFAULT 0');
    await add('obra_item_id', 'INTEGER');
    await add('obra_item_uuid', 'TEXT');
    await _backfillOrdemServicoCustosVinculos(database);
  } catch (_) {}
}

Future<void> _backfillOrdemServicoCustosVinculos(Database database) async {
  try {
    final custos = await database.rawQuery('''
SELECT osc.id, osc.descricao, osc.origem, osc.obra_item_id,
       os.obra_id, os.obra_uuid
FROM ordem_servico_custos AS osc
LEFT JOIN ordens_servico AS os
  ON os.uuid = osc.ordem_servico_uuid
  OR (osc.ordem_servico_id IS NOT NULL AND os.id = osc.ordem_servico_id)
WHERE (osc.obra_item_id IS NULL OR osc.obra_item_id = 0)
  AND TRIM(COALESCE(osc.descricao, '')) != ''
''');

    for (final row in custos) {
      final desc = (row['descricao'] as String? ?? '').trim().toLowerCase();
      if (desc.isEmpty) continue;
      final obraId = row['obra_id'];
      final obraUuid = (row['obra_uuid'] as String? ?? '').trim();

      List<Map<String, Object?>> matches = const [];
      if (obraId != null && obraId.toString() != '0') {
        matches = await database.rawQuery(
          '''
SELECT id, uuid, tipo FROM obra_itens
WHERE obra_id = ?
  AND LOWER(TRIM(descricao)) = ?
  AND tipo IN ('insumo', 'mao_obra', 'equipamento')
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != -2)
''',
          [obraId, desc],
        );
      } else if (obraUuid.isNotEmpty) {
        matches = await database.rawQuery(
          '''
SELECT id, uuid, tipo FROM obra_itens
WHERE obra_uuid = ?
  AND LOWER(TRIM(descricao)) = ?
  AND tipo IN ('insumo', 'mao_obra', 'equipamento')
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != -2)
''',
          [obraUuid, desc],
        );
      }
      if (matches.length != 1) continue;
      final m = matches.first;
      await database.update(
        'ordem_servico_custos',
        {
          'obra_item_id': m['id'],
          'obra_item_uuid': m['uuid'],
          'origem': m['tipo'],
        },
        where: 'id = ?',
        whereArgs: [row['id']],
      );
    }
  } catch (_) {}
}

/// Coluna alinhada ao MySQL `motivo_saida_cedo` (motivo da saída antes do horário do relatório).
Future<void> _ensureMotivoSaidaCedoMaoObraPresenca(Database database) async {
  try {
    final info =
        await database.rawQuery('PRAGMA table_info(relatorio_mao_obra_presenca)');
    final has =
        info.any((row) => (row['name'] as String?) == 'motivo_saida_cedo');
    if (has) return;
    await database.execute(
      'ALTER TABLE relatorio_mao_obra_presenca ADD COLUMN motivo_saida_cedo TEXT',
    );
  } catch (_) {}
}

/// Garante coluna [situacao] (soft delete: valor -2) onde o app lista/filtra registros.
Future<void> _ensureRelatorioChildSituacaoColumns(Database database) async {
  const tables = <String>[
    'modelo_relatorio_aprovadores',
    'obra_locais',
    'obras',
    'obras_grupos',
    'ordem_servico_custos',
    'ordem_servico_tarefas',
    'user_obras',
    'empresa_user_obra',
    'relatorio_anexos',
    'relatorio_comentarios',
    'relatorio_ocorrencias',
    'relatorio_equipamento_recebido',
    'relatorio_atividades',
    'relatorio_atividades_itens',
    'relatorio_atividade_fotos',
    'relatorio_ordem_servico',
    'relatorio_mao_obra_presenca',
    'relatorio_custos',
  ];
  for (final table in tables) {
    final info = await database.rawQuery('PRAGMA table_info($table)');
    final has = info.any((row) => (row['name'] as String?) == 'situacao');
    if (has) continue;
    try {
      await database.execute(
        'ALTER TABLE $table ADD COLUMN situacao INTEGER NOT NULL DEFAULT 1',
      );
    } catch (_) {
      // Tabela inexistente ou coluna já criada em corrida: ignorar.
    }
  }
  for (final table in tables) {
    try {
      await database.rawUpdate(
        'UPDATE $table SET situacao = 1 WHERE situacao IS NULL',
      );
    } catch (_) {}
  }
}

/// Bases antigas podem não ter [updated_at]/[synced]/[last_sync_date] em [relatorio_equipamento_recebido],
/// o que quebra o UPDATE de quantidade e deixa a fila de upload vazia.
Future<void> _ensureRelatorioEquipamentoRecebidoTimestampSyncColumns(
    Database database) async {
  try {
    final info = await database
        .rawQuery('PRAGMA table_info(relatorio_equipamento_recebido)');
    if (info.isEmpty) return;
    final names = info
        .map((r) => r['name'] as String?)
        .whereType<String>()
        .toSet();
    if (!names.contains('updated_at')) {
      await database.execute(
        'ALTER TABLE relatorio_equipamento_recebido ADD COLUMN updated_at TEXT',
      );
    }
    if (!names.contains('synced')) {
      await database.execute(
        'ALTER TABLE relatorio_equipamento_recebido ADD COLUMN synced INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (!names.contains('last_sync_date')) {
      await database.execute(
        'ALTER TABLE relatorio_equipamento_recebido ADD COLUMN last_sync_date TEXT',
      );
    }
  } catch (_) {}
}

/// Asset antigo guardava `situacao_id` e `synced` como BLOB; [situacao_id] deve ser INTEGER (FK lógica → [situacao_obras]).
Future<void> _migrateObrasLegacyBlobColumnsIfNeeded(Database database) async {
  try {
    final info = await database.rawQuery('PRAGMA table_info(obras)');
    if (info.isEmpty) return;

    String? sqliteType(String column) {
      for (final row in info) {
        if (row['name'] == column) {
          return row['type']?.toString().toUpperCase();
        }
      }
      return null;
    }

    final sid = sqliteType('situacao_id');
    final sync = sqliteType('synced');
    final nome = sqliteType('nome');
    final needsMigration =
        sid == 'BLOB' || sync == 'BLOB' || nome == 'BLOB';
    if (!needsMigration) return;

    await database.transaction((txn) async {
      await txn.execute('''
CREATE TABLE obras_new (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  uuid_pai TEXT,
  uuid TEXT NOT NULL,
  user_id INTEGER,
  user_uuid TEXT NOT NULL,
  cliente_id INTEGER,
  cliente_uuid TEXT NOT NULL,
  grupo_id INTEGER DEFAULT 0,
  grupo_uuid TEXT NOT NULL,
  nome TEXT NOT NULL,
  rua TEXT,
  numero TEXT,
  complemento TEXT,
  bairro TEXT,
  cidade TEXT,
  estado TEXT,
  engenheiro TEXT,
  data_inicio TEXT,
  data_final TEXT,
  contrato TEXT,
  foto TEXT,
  foto_local TEXT,
  created_by TEXT,
  situacao_id INTEGER,
  synced INTEGER NOT NULL DEFAULT 0,
  sync_try_count INTEGER DEFAULT 0,
  last_sync_date TEXT,
  created_at TEXT,
  updated_at TEXT,
  situacao INTEGER NOT NULL DEFAULT 1
)
''');
      await txn.execute('''
INSERT INTO obras_new (
  id, uuid_pai, uuid, user_id, user_uuid, cliente_id, cliente_uuid,
  grupo_id, grupo_uuid, nome, rua, numero, complemento, bairro, cidade, estado,
  engenheiro, data_inicio, data_final, contrato, foto, foto_local, created_by,
  situacao_id, synced, sync_try_count, last_sync_date, created_at, updated_at, situacao
)
SELECT
  id,
  uuid_pai,
  uuid,
  user_id,
  user_uuid,
  cliente_id,
  cliente_uuid,
  grupo_id,
  grupo_uuid,
  CAST(nome AS TEXT),
  rua,
  numero,
  complemento,
  bairro,
  cidade,
  estado,
  engenheiro,
  data_inicio,
  data_final,
  contrato,
  foto,
  NULL,
  created_by,
  CAST(situacao_id AS INTEGER),
  CAST(COALESCE(synced, 0) AS INTEGER),
  sync_try_count,
  last_sync_date,
  created_at,
  updated_at,
  COALESCE(situacao, 1)
FROM obras
''');
      await txn.execute('DROP TABLE obras');
      await txn.execute('ALTER TABLE obras_new RENAME TO obras');
    });

    try {
      final maxRows =
          await database.rawQuery('SELECT MAX(id) AS m FROM obras');
      final m = maxRows.first['m'];
      final maxId = m is int ? m : (m is num ? m.toInt() : null);
      if (maxId != null && maxId > 0) {
        await database.execute(
          "DELETE FROM sqlite_sequence WHERE name = 'obras'",
        );
        await database.rawInsert(
          'INSERT INTO sqlite_sequence(name, seq) VALUES (?, ?)',
          ['obras', maxId],
        );
      }
    } catch (_) {}
  } catch (_) {}
}

/// Caminho local do arquivo da foto da obra (download offline).
/// [obras.foto] continua com o path relativo do S3 vindo do servidor.
Future<void> _ensureObrasFotoLocalColumn(Database database) async {
  try {
    final info = await database.rawQuery('PRAGMA table_info(obras)');
    if (info.isEmpty) return;
    final has =
        info.any((row) => (row['name'] as String?) == 'foto_local');
    if (has) return;
    await database.execute(
      'ALTER TABLE obras ADD COLUMN foto_local TEXT',
    );
  } catch (_) {}
}

/// Colunas `ordem_id` / `ordem_uuid` alinhadas ao MySQL `relatorio_atividades.ordem_id`.
Future<void> _ensureRelatorioAtividadesOrdemColumns(Database database) async {
  try {
    final info = await database
        .rawQuery('PRAGMA table_info(relatorio_atividades)');
    final names = info
        .map((row) => row['name'] as String?)
        .whereType<String>()
        .toList();
    if (!names.contains('ordem_id')) {
      await database.execute(
        'ALTER TABLE relatorio_atividades ADD COLUMN ordem_id INTEGER',
      );
    }
    if (!names.contains('ordem_uuid')) {
      await database.execute(
        'ALTER TABLE relatorio_atividades ADD COLUMN ordem_uuid TEXT',
      );
    }
  } catch (_) {}
}

/// Alinha lista local com o fluxo da API (`status_id`); DBs antigos só tinham `situacao`.
Future<void> _ensureOrdensServicoStatusIdColumn(Database database) async {
  try {
    final info = await database.rawQuery('PRAGMA table_info(ordens_servico)');
    final has = info.any((row) => (row['name'] as String?) == 'status_id');
    if (has) return;
    await database.execute(
      'ALTER TABLE ordens_servico ADD COLUMN status_id INTEGER NOT NULL DEFAULT 1',
    );
  } catch (_) {}
}

/// URL no S3 após upload; [arquivo] permanece caminho local enquanto o arquivo existir e o RDO não estiver aprovado.
Future<void> _ensureRelatorioAtividadeFotosArquivoServidor(Database database) async {
  try {
    final info = await database
        .rawQuery('PRAGMA table_info(relatorio_atividade_fotos)');
    final has =
        info.any((row) => (row['name'] as String?) == 'arquivo_servidor');
    if (!has) {
      await database.execute(
        'ALTER TABLE relatorio_atividade_fotos ADD COLUMN arquivo_servidor TEXT',
      );
    }
    await database.rawUpdate(
      '''
UPDATE relatorio_atividade_fotos
SET arquivo_servidor = arquivo
WHERE (arquivo_servidor IS NULL OR TRIM(arquivo_servidor) = '')
  AND arquivo IS NOT NULL
  AND TRIM(arquivo) != ''
  AND (LOWER(arquivo) LIKE 'http://%' OR LOWER(arquivo) LIKE 'https://%')
''',
    );
  } catch (_) {}
}

/// Corrige FK local: `relatorio_atividade_id` inválido ou ausente; casa pelo UUID da atividade.
Future<void> repairRelatorioAtividadeFotosFkQuebrada(Database database) async {
  try {
    await database.rawUpdate(
      '''
UPDATE relatorio_atividade_fotos AS f
SET relatorio_atividade_id = (
  SELECT a.id FROM relatorio_atividades AS a
  WHERE LOWER(TRIM(a.uuid)) = LOWER(TRIM(f.relatorio_atividade_uuid))
  LIMIT 1
)
WHERE f.relatorio_atividade_uuid IS NOT NULL
  AND TRIM(f.relatorio_atividade_uuid) != ''
  AND NOT EXISTS (
    SELECT 1 FROM relatorio_atividades AS x WHERE x.id = f.relatorio_atividade_id
  )
''',
    );
  } catch (_) {}
}

/// Gera UUID em `relatorios` quando o campo veio vazio / `"null"` (upload de atividades depende disso).
Future<void> ensureRelatoriosHaveUuid(Database database) async {
  try {
    final rows = await database.rawQuery('''
SELECT id FROM relatorios
WHERE uuid IS NULL
   OR TRIM(uuid) = ''
   OR LOWER(TRIM(uuid)) = 'null'
''');
    const uuidGen = Uuid();
    for (final row in rows) {
      final id = row['id'];
      if (id == null) continue;
      await database.update(
        'relatorios',
        {'uuid': uuidGen.v4()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  } catch (_) {}
}

/// Gera UUID em `relatorio_atividades` quando veio vazio / `"null"` (upload de fotos exige `relatorio_atividade_uuid`).
Future<void> ensureRelatorioAtividadesHaveUuid(Database database) async {
  try {
    final rows = await database.rawQuery('''
SELECT id FROM relatorio_atividades
WHERE uuid IS NULL
   OR TRIM(uuid) = ''
   OR LOWER(TRIM(uuid)) = 'null'
''');
    const uuidGen = Uuid();
    for (final row in rows) {
      final id = row['id'];
      if (id == null) continue;
      await database.update(
        'relatorio_atividades',
        {'uuid': uuidGen.v4()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  } catch (_) {}
}

/// Gera UUID em `obra_itens` quando veio vazio / `"null"` (upload de itens de atividade exige `obra_item_uuid`).
Future<void> ensureObraItensHaveUuid(Database database) async {
  try {
    final rows = await database.rawQuery('''
SELECT id FROM obra_itens
WHERE uuid IS NULL
   OR TRIM(uuid) = ''
   OR LOWER(TRIM(uuid)) = 'null'
''');
    const uuidGen = Uuid();
    for (final row in rows) {
      final id = row['id'];
      if (id == null) continue;
      await database.update(
        'obra_itens',
        {'uuid': uuidGen.v4()},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  } catch (_) {}
}

/// Corrige FK local: `relatorio_atividade_id` inválido; casa pelo UUID armazenado no item.
Future<void> repairRelatorioAtividadesItensFkQuebrada(Database database) async {
  try {
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades_itens AS i
SET relatorio_atividade_id = (
  SELECT a.id FROM relatorio_atividades AS a
  WHERE LOWER(TRIM(a.uuid)) = LOWER(TRIM(i.relatorio_atividade_uuid))
  LIMIT 1
)
WHERE i.relatorio_atividade_uuid IS NOT NULL
  AND TRIM(i.relatorio_atividade_uuid) != ''
  AND NOT EXISTS (
    SELECT 1 FROM relatorio_atividades AS x WHERE x.id = i.relatorio_atividade_id
  )
''',
    );
  } catch (_) {}
}

/// Espelha UUIDs dos FKs em `relatorio_atividades` e marca pendentes de sync (`synced` nulo → 0).
/// [tarefa_uuid] só é preenchida quando existe [tarefa_id]; atividade avulsa mantém vazio.
Future<void> normalizeRelatorioAtividadesForUpload(Database database) async {
  try {
    await ensureRelatorioAtividadesHaveUuid(database);
    await database.rawUpdate(
      'UPDATE relatorio_atividades SET synced = 0 WHERE synced IS NULL',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades
SET relatorio_uuid = NULL
WHERE relatorio_uuid IS NOT NULL AND LOWER(TRIM(relatorio_uuid)) = 'null'
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades AS ra
SET relatorio_uuid = (
  SELECT r.uuid FROM relatorios AS r WHERE r.id = ra.relatorio_id LIMIT 1
)
WHERE ra.relatorio_id IS NOT NULL
  AND (ra.relatorio_uuid IS NULL OR TRIM(ra.relatorio_uuid) = '')
  AND EXISTS (SELECT 1 FROM relatorios AS r WHERE r.id = ra.relatorio_id)
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades AS ra
SET tarefa_uuid = (
  SELECT t.uuid FROM obra_etapa_tarefas AS t WHERE t.id = ra.tarefa_id LIMIT 1
)
WHERE ra.tarefa_id IS NOT NULL
  AND (ra.tarefa_uuid IS NULL OR TRIM(ra.tarefa_uuid) = '')
  AND EXISTS (SELECT 1 FROM obra_etapa_tarefas AS t WHERE t.id = ra.tarefa_id)
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades AS ra
SET user_uuid = (
  SELECT u.uuid FROM users AS u WHERE u.id = ra.user_id LIMIT 1
)
WHERE ra.user_id IS NOT NULL
  AND (ra.user_uuid IS NULL OR TRIM(ra.user_uuid) = '')
  AND EXISTS (SELECT 1 FROM users AS u WHERE u.id = ra.user_id)
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades AS ra
SET ordem_uuid = (
  SELECT o.uuid FROM ordens_servico AS o WHERE o.id = ra.ordem_id LIMIT 1
)
WHERE ra.ordem_id IS NOT NULL
  AND (ra.ordem_uuid IS NULL OR TRIM(ra.ordem_uuid) = '')
  AND EXISTS (SELECT 1 FROM ordens_servico AS o WHERE o.id = ra.ordem_id)
''',
    );
  } catch (_) {}
}

/// Espelha UUIDs em `relatorio_atividades_itens` a partir dos FKs locais (`synced` nulo → 0).
Future<void> normalizeRelatorioAtividadesItensForUpload(Database database) async {
  try {
    await repairRelatorioAtividadesItensFkQuebrada(database);
    await ensureRelatorioAtividadesHaveUuid(database);
    await ensureObraItensHaveUuid(database);
    await database.rawUpdate(
      'UPDATE relatorio_atividades_itens SET synced = 0 WHERE synced IS NULL',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades_itens
SET relatorio_atividade_uuid = NULL
WHERE relatorio_atividade_uuid IS NOT NULL
  AND LOWER(TRIM(relatorio_atividade_uuid)) = 'null'
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades_itens
SET obra_item_uuid = NULL
WHERE obra_item_uuid IS NOT NULL AND LOWER(TRIM(obra_item_uuid)) = 'null'
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades_itens AS i
SET relatorio_atividade_uuid = (
  SELECT a.uuid FROM relatorio_atividades AS a WHERE a.id = i.relatorio_atividade_id LIMIT 1
)
WHERE i.relatorio_atividade_id IS NOT NULL
  AND (i.relatorio_atividade_uuid IS NULL OR TRIM(i.relatorio_atividade_uuid) = '')
  AND EXISTS (
    SELECT 1 FROM relatorio_atividades AS a WHERE a.id = i.relatorio_atividade_id
  )
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades_itens AS i
SET obra_item_uuid = (
  SELECT oi.uuid FROM obra_itens AS oi WHERE oi.id = i.obra_item_id LIMIT 1
)
WHERE i.obra_item_id IS NOT NULL
  AND (i.obra_item_uuid IS NULL OR TRIM(i.obra_item_uuid) = '')
  AND EXISTS (
    SELECT 1 FROM obra_itens AS oi WHERE oi.id = i.obra_item_id
  )
''',
    );
    await backfillRelatorioAtividadesItensCreatedByFromRelatorio(database);
  } catch (_) {}
}

/// Garante fila de upload de fotos: `synced` nulo vira 0; UUID da atividade espelhado a partir do FK local.
Future<void> normalizeRelatorioAtividadeFotosForUpload(Database database) async {
  try {
    await repairRelatorioAtividadeFotosFkQuebrada(database);
    await ensureRelatorioAtividadesHaveUuid(database);
    await database.rawUpdate(
      'UPDATE relatorio_atividade_fotos SET synced = 0 WHERE synced IS NULL',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividade_fotos
SET relatorio_atividade_uuid = NULL
WHERE relatorio_atividade_uuid IS NOT NULL
  AND LOWER(TRIM(relatorio_atividade_uuid)) = 'null'
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividade_fotos AS f
SET relatorio_atividade_uuid = (
  SELECT a.uuid FROM relatorio_atividades AS a
  WHERE a.id = f.relatorio_atividade_id LIMIT 1
)
WHERE (f.relatorio_atividade_uuid IS NULL OR TRIM(f.relatorio_atividade_uuid) = '')
  AND EXISTS (
    SELECT 1 FROM relatorio_atividades AS a WHERE a.id = f.relatorio_atividade_id
  )
''',
    );
  } catch (_) {}
}

/// Espelha FKs do relatório em [relatorio_equipamento_recebido] e trata `synced` nulo.
/// O sync de upload usa só `created_by` (tenant); este helper ainda preenche UUIDs via [relatorios].
/// No SQLite, [relatorio_equipamento_recebido.created_by] é TEXT com o **UUID do tenant**
/// (dono da conta), não do usuário logado; preenche a partir do relatório pai se vazio ou legado.
Future<void> normalizeRelatorioEquipamentoRecebidoForUpload(Database database) async {
  try {
    await database.rawUpdate(
      'UPDATE relatorio_equipamento_recebido SET synced = 0 WHERE synced IS NULL',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_equipamento_recebido AS er
SET relatorio_uuid = (
  SELECT r.uuid FROM relatorios AS r WHERE r.id = er.relatorio_id LIMIT 1
)
WHERE COALESCE(er.relatorio_id, 0) > 0
  AND (er.relatorio_uuid IS NULL OR TRIM(er.relatorio_uuid) = '')
  AND EXISTS (SELECT 1 FROM relatorios AS r WHERE r.id = er.relatorio_id)
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_equipamento_recebido AS er
SET relatorio_id = (
  SELECT r.id FROM relatorios AS r
  WHERE LOWER(TRIM(r.uuid)) = LOWER(TRIM(er.relatorio_uuid))
  LIMIT 1
)
WHERE COALESCE(er.relatorio_id, 0) <= 0
  AND TRIM(COALESCE(er.relatorio_uuid, '')) != ''
  AND EXISTS (
    SELECT 1 FROM relatorios AS r
    WHERE LOWER(TRIM(r.uuid)) = LOWER(TRIM(er.relatorio_uuid))
  )
''',
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_equipamento_recebido AS er
SET created_by = (
  SELECT COALESCE(
    NULLIF(TRIM(COALESCE(r.user_uuid, '')), ''),
    NULLIF(TRIM(COALESCE(r.created_by, '')), ''),
    NULLIF(TRIM(COALESCE(r.criador, '')), ''),
    ''
  )
  FROM relatorios AS r
  WHERE r.id = er.relatorio_id
  LIMIT 1
)
WHERE (
  TRIM(COALESCE(er.created_by, '')) = ''
  OR INSTR(TRIM(er.created_by), '-') = 0
)
AND COALESCE(er.relatorio_id, 0) > 0
AND EXISTS (SELECT 1 FROM relatorios AS r2 WHERE r2.id = er.relatorio_id)
''',
    );
  } catch (_) {}
}

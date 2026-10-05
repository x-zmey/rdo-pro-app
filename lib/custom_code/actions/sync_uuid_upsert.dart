import 'package:sqflite/sqflite.dart';

/// Normaliza UUID de sync: trim + lower; rejeita vazio / `"null"`.
///
/// No **download**, nunca inventar UUID — se retornar `null`, pular o insert.
String? normalizeSyncUuid(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  if (s.toLowerCase() == 'null') return null;
  return s.toLowerCase();
}

int? syncServerId(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

/// Upsert em `sync_id_mapping` (PK: tabela + id_servidor).
Future<void> upsertSyncIdMapping(
  Database db, {
  required String tabela,
  required int idServidor,
  required String uuid,
}) async {
  final u = normalizeSyncUuid(uuid);
  if (u == null) return;
  try {
    final existing = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: [tabela, idServidor],
      limit: 1,
    );
    if (existing.isEmpty) {
      await db.insert('sync_id_mapping', {
        'tabela': tabela,
        'id_servidor': idServidor,
        'uuid': u,
        'created_at': DateTime.now().toIso8601String(),
      });
    } else {
      final cur = normalizeSyncUuid(existing.first['uuid']);
      if (cur != u) {
        await db.update(
          'sync_id_mapping',
          {'uuid': u},
          where: 'tabela = ? AND id_servidor = ?',
          whereArgs: [tabela, idServidor],
        );
      }
    }
  } catch (e) {
    // ignore: avoid_print
    print('⚠️ sync_id_mapping $tabela#$idServidor: $e');
  }
}

/// Localiza linha local para download: UUID normalizado, depois mapping id_servidor.
Future<Map<String, dynamic>?> resolveLocalRowForSyncDownload(
  Database db, {
  required String tabela,
  required String uuid,
  int? serverId,
}) async {
  final u = normalizeSyncUuid(uuid);
  if (u == null) return null;

  final byUuid = await db.rawQuery(
    'SELECT * FROM $tabela WHERE LOWER(TRIM(COALESCE(uuid, \'\'))) = ? LIMIT 1',
    [u],
  );
  if (byUuid.isNotEmpty) {
    return Map<String, dynamic>.from(byUuid.first);
  }

  if (serverId == null) return null;

  final mapRows = await db.query(
    'sync_id_mapping',
    columns: ['uuid'],
    where: 'tabela = ? AND id_servidor = ?',
    whereArgs: [tabela, serverId],
    limit: 1,
  );
  if (mapRows.isEmpty) return null;

  final mappedUuid = normalizeSyncUuid(mapRows.first['uuid']);
  if (mappedUuid == null) return null;

  final byMap = await db.rawQuery(
    'SELECT * FROM $tabela WHERE LOWER(TRIM(COALESCE(uuid, \'\'))) = ? LIMIT 1',
    [mappedUuid],
  );
  if (byMap.isEmpty) return null;
  return Map<String, dynamic>.from(byMap.first);
}

/// Garante que a linha local use o UUID canônico do servidor (lower).
Future<void> alignLocalUuidIfNeeded(
  Database db, {
  required String tabela,
  required int localId,
  required String canonicalUuid,
  required Map<String, dynamic> localRow,
}) async {
  final current = normalizeSyncUuid(localRow['uuid']);
  if (current == canonicalUuid) {
    // Ainda assim normaliza casing/espaços se diferirem na string bruta.
    final raw = localRow['uuid']?.toString() ?? '';
    if (raw == canonicalUuid) return;
  }
  try {
    await db.update(
      tabela,
      {'uuid': canonicalUuid},
      where: 'id = ?',
      whereArgs: [localId],
    );
  } catch (e) {
    // Conflito de UNIQUE: já existe outra linha com esse uuid — caller trata update nela.
    // ignore: avoid_print
    print('⚠️ align uuid $tabela#$localId → $canonicalUuid: $e');
  }
}

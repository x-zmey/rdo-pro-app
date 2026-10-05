import 'package:flutter/foundation.dart';

import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/situacao_soft_delete.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/custom_code/actions/download_obra_foto_local.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';

class _AllowedObraRef {
  const _AllowedObraRef({
    required this.serverId,
    this.uuid = '',
    this.raw,
  });

  final int serverId;
  final String uuid;
  final Map<String, dynamic>? raw;
}

/// Zera cache de obras permitidas (prefs + memória). Usar na troca de tenant.
void clearAllowedObrasCache() {
  FFAppState().allowedObraIds = [];
  FFAppState().allowedObraLocalIds = [];
  FFAppState().allowedObraUuids = [];
  MembershipAccess.persistToPrefs();
}

/// IDs de obras vinculadas ao usuário no tenant ativo (API = IDs do servidor).
Future<List<int>> fetchAllowedObraIdsForUser(int userId) async {
  final refs = await _fetchAllowedObraRefs(userId);
  if (refs == null) return [];
  return refs.map((r) => r.serverId).toList();
}

/// `null` = falha de rede/API (manter cache do **mesmo** tenant); lista (mesmo
/// vazia) = resposta autoritativa do servidor.
Future<List<_AllowedObraRef>?> _fetchAllowedObraRefs(int userId) async {
  if (userId <= 0) return null;

  final token = FFAppState().UserToken.trim();
  if (token.isEmpty) return null;

  try {
    final res = await GetUsuarioObrasVinculadasCall.call(
      usuarioId: userId,
      token: token,
    );
    if (!res.succeeded) {
      debugPrint('fetchAllowedObraRefs: HTTP/status falhou');
      return null;
    }
    return _parseObraRefsFromBody(res.jsonBody);
  } catch (e) {
    debugPrint('fetchAllowedObraRefs: $e');
    return null;
  }
}

List<_AllowedObraRef> _parseObraRefsFromBody(dynamic body) {
  dynamic list;
  if (body is List) {
    list = body;
  } else if (body is Map) {
    list = body['obras'] ?? body['value'] ?? body['data'];
  } else if (body is String && body.trim().isNotEmpty) {
    try {
      return _parseObraRefsFromBody(jsonDecode(body));
    } catch (_) {
      return [];
    }
  }
  if (list is! List) return [];

  final out = <_AllowedObraRef>[];
  for (final o in list) {
    if (o is! Map) continue;
    final map = Map<String, dynamic>.from(o);
    final id = int.tryParse(map['id']?.toString() ?? '') ?? 0;
    if (id <= 0) continue;
    final uuid = (map['uuid']?.toString() ?? '').trim();
    out.add(_AllowedObraRef(serverId: id, uuid: uuid, raw: map));
  }
  return out;
}

/// Resolve ID do servidor → uuid / id local via `sync_id_mapping`.
Future<({String? uuid, int? localId})> resolveObraServerToLocal(
  int serverObraId,
) async {
  if (serverObraId <= 0) return (uuid: null, localId: null);
  try {
    final db = SQLiteManager.instance.database;
    final maps = await db.query(
      'sync_id_mapping',
      columns: ['uuid'],
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: ['obras', serverObraId],
      limit: 1,
    );
    if (maps.isEmpty) return (uuid: null, localId: null);
    final uuid = (maps.first['uuid']?.toString() ?? '').trim();
    if (uuid.isEmpty) return (uuid: null, localId: null);

    final obras = await db.query(
      'obras',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    final localId = obras.isEmpty ? null : (obras.first['id'] as int?);
    return (uuid: uuid, localId: localId);
  } catch (e) {
    debugPrint('resolveObraServerToLocal: $e');
    return (uuid: null, localId: null);
  }
}

Future<void> _salvarMapeamentoObra(int idServidor, String uuid) async {
  if (idServidor <= 0 || uuid.isEmpty) return;
  try {
    final db = SQLiteManager.instance.database;
    await db.insert('sync_id_mapping', {
      'tabela': 'obras',
      'id_servidor': idServidor,
      'uuid': uuid,
      'created_at': DateTime.now().toIso8601String(),
    });
  } catch (e) {
    if (!e.toString().contains('UNIQUE constraint')) {
      debugPrint('_salvarMapeamentoObra: $e');
    }
  }
}

/// Garante que obras permitidas existam no SQLite (insere a partir da API se faltar).
Future<void> ensureAllowedObrasPresentLocally(
  List<_AllowedObraRef> refs,
) async {
  if (refs.isEmpty) return;
  final db = SQLiteManager.instance.database;
  final creatorUuid = FFAppState().creatorUuid.trim();
  final now = DateTime.now().toUtc().toIso8601String();

  for (final ref in refs) {
    var uuid = ref.uuid;
    if (uuid.isEmpty) {
      final resolved = await resolveObraServerToLocal(ref.serverId);
      uuid = resolved.uuid ?? '';
    }
    if (uuid.isEmpty) continue;

    await _salvarMapeamentoObra(ref.serverId, uuid);

    final exists = await db.query(
      'obras',
      columns: ['id'],
      where: 'uuid = ?',
      whereArgs: [uuid],
      limit: 1,
    );
    if (exists.isNotEmpty) continue;

    final raw = ref.raw ?? const <String, dynamic>{};
    final userUuid = (raw['user_uuid']?.toString() ?? '').trim().isNotEmpty
        ? (raw['user_uuid']?.toString() ?? '').trim()
        : creatorUuid;

    try {
      await db.insert('obras', {
        'uuid': uuid,
        'uuid_pai': raw['uuid_pai'],
        'user_id': raw['user_id'],
        'user_uuid': userUuid,
        'cliente_id': raw['cliente_id'],
        'cliente_uuid': raw['cliente_uuid']?.toString(),
        'grupo_id': raw['grupo_id'] ?? 0,
        'grupo_uuid': raw['grupo_uuid']?.toString() ?? '',
        'nome': raw['nome']?.toString() ?? 'Obra ${ref.serverId}',
        'rua': raw['rua']?.toString(),
        'numero': raw['numero']?.toString(),
        'complemento': raw['complemento']?.toString(),
        'bairro': raw['bairro']?.toString(),
        'cidade': raw['cidade']?.toString(),
        'estado': raw['estado']?.toString(),
        'engenheiro': raw['engenheiro']?.toString(),
        'data_inicio': raw['data_inicio']?.toString(),
        'data_final': raw['data_final']?.toString(),
        'contrato': raw['contrato']?.toString(),
        'foto': raw['foto']?.toString(),
        'created_by': creatorUuid.isNotEmpty
            ? creatorUuid
            : (raw['created_by']?.toString() ?? ''),
        'situacao_id': raw['situacao_id'],
        'situacao': int.tryParse(raw['situacao']?.toString() ?? '') ??
            kSituacaoAtivo,
        'synced': 1,
        'created_at': raw['created_at']?.toString() ?? now,
        'updated_at': raw['updated_at']?.toString() ?? now,
      });
      debugPrint(
        'ensureAllowedObrasPresentLocally: inseriu obra $uuid (server ${ref.serverId})',
      );
      await downloadObraFotoLocal(
        obraUuid: uuid,
        fotoServidor: raw['foto']?.toString(),
        fotoUrl: raw['foto_url']?.toString(),
      );
    } catch (e) {
      debugPrint('ensureAllowedObrasPresentLocally insert: $e');
    }
  }
}

/// Atualiza cache de IDs locais a partir dos IDs de servidor em [allowedObraIds].
Future<List<int>> refreshAllowedObraLocalIdsCache() async {
  final serverIds = FFAppState().allowedObraIds;
  final localIds = <int>[];
  final uuids = <String>{
    ...FFAppState().allowedObraUuids.where((u) => u.trim().isNotEmpty),
  };

  for (final sid in serverIds) {
    final resolved = await resolveObraServerToLocal(sid);
    if (resolved.localId != null && resolved.localId! > 0) {
      localIds.add(resolved.localId!);
    }
    if (resolved.uuid != null && resolved.uuid!.isNotEmpty) {
      uuids.add(resolved.uuid!);
    }
  }

  // Também resolve uuid → id local quando a API já trouxe o uuid.
  if (localIds.length < uuids.length) {
    final db = SQLiteManager.instance.database;
    final owner = FFAppState().creatorUuid.trim();
    for (final uuid in uuids) {
      final rows = owner.isEmpty
          ? await db.query(
              'obras',
              columns: ['id'],
              where: 'uuid = ?',
              whereArgs: [uuid],
              limit: 1,
            )
          : await db.query(
              'obras',
              columns: ['id'],
              where: 'uuid = ? AND user_uuid = ?',
              whereArgs: [uuid, owner],
              limit: 1,
            );
      if (rows.isEmpty) continue;
      final id = rows.first['id'] as int?;
      if (id != null && id > 0 && !localIds.contains(id)) {
        localIds.add(id);
      }
    }
  }

  // Descarta UUIDs que não pertencem ao tenant ativo (SQLite misturado).
  final pruned = await _pruneUuidsToCurrentTenant(uuids.toList());
  FFAppState().allowedObraLocalIds = localIds;
  FFAppState().allowedObraUuids = pruned;
  return localIds;
}

/// Mantém só UUIDs de obras com `user_uuid` = tenant ativo.
Future<List<String>> _pruneUuidsToCurrentTenant(List<String> uuids) async {
  final owner = FFAppState().creatorUuid.trim();
  if (owner.isEmpty || uuids.isEmpty) return uuids;
  final db = SQLiteManager.instance.database;
  final kept = <String>[];
  for (final uuid in uuids) {
    final u = uuid.trim();
    if (u.isEmpty) continue;
    final rows = await db.query(
      'obras',
      columns: ['id'],
      where: 'uuid = ? AND user_uuid = ?',
      whereArgs: [u, owner],
      limit: 1,
    );
    if (rows.isNotEmpty) kept.add(u);
  }
  return kept;
}

/// Atualiza [FFAppState.allowedObraIds] quando obra_travada está ativa.
Future<void> refreshAllowedObraIdsIfNeeded() async {
  if (!MembershipAccess.obraTravada) {
    clearAllowedObrasCache();
    return;
  }

  final userId = FFAppState().UserID;
  if (userId <= 0) return;

  final refs = await _fetchAllowedObraRefs(userId);

  if (refs == null) {
    // Falha de rede: não reutilizar IDs de outro tenant — só poda o cache atual.
    final pruned =
        await _pruneUuidsToCurrentTenant(FFAppState().allowedObraUuids);
    if (pruned.length != FFAppState().allowedObraUuids.length) {
      FFAppState().allowedObraUuids = pruned;
    }
    MembershipAccess.persistToPrefs();
    await refreshAllowedObraLocalIdsCache();
    return;
  }

  if (refs.isNotEmpty) {
    FFAppState().allowedObraIds = refs.map((r) => r.serverId).toList();
    final apiUuids =
        refs.map((r) => r.uuid).where((u) => u.isNotEmpty).toList();
    FFAppState().allowedObraUuids = apiUuids.isNotEmpty
        ? await _pruneUuidsToCurrentTenant(apiUuids)
        : <String>[];
    await ensureAllowedObrasPresentLocally(refs);
  } else {
    // Resposta autoritativa: usuário sem obras neste tenant.
    FFAppState().allowedObraIds = [];
    FFAppState().allowedObraUuids = [];
    FFAppState().allowedObraLocalIds = [];
  }

  MembershipAccess.persistToPrefs();
  await ensureLocalUserObraLinksFromAllowedIds();
  await refreshAllowedObraLocalIdsCache();
}

/// Espelha [allowedObraIds] (servidor) em `user_obras` com id/uuid **locais**.
Future<void> ensureLocalUserObraLinksFromAllowedIds() async {
  if (!MembershipAccess.obraTravada) return;

  final serverIds = FFAppState().allowedObraIds;
  if (serverIds.isEmpty) return;

  final userId = FFAppState().UserID;
  final userUuid = FFAppState().UserUuid.trim();
  if (userId <= 0 && userUuid.isEmpty) return;

  final knownUuids = FFAppState().allowedObraUuids;
  try {
    final db = SQLiteManager.instance.database;
    for (var i = 0; i < serverIds.length; i++) {
      final serverObraId = serverIds[i];
      if (serverObraId <= 0) continue;

      final resolved = await resolveObraServerToLocal(serverObraId);
      var obraUuid = resolved.uuid ?? '';
      if (obraUuid.isEmpty && i < knownUuids.length) {
        obraUuid = knownUuids[i];
      }
      if (obraUuid.isEmpty) {
        for (final u in knownUuids) {
          // UUID conhecido sem índice 1:1 — tenta achar pelo mapping reverso.
          final maps = await db.query(
            'sync_id_mapping',
            columns: ['id_servidor'],
            where: 'tabela = ? AND uuid = ?',
            whereArgs: ['obras', u],
            limit: 1,
          );
          if (maps.isEmpty) continue;
          final sid =
              int.tryParse(maps.first['id_servidor']?.toString() ?? '') ?? 0;
          if (sid == serverObraId) {
            obraUuid = u;
            break;
          }
        }
      }

      final localObraId = resolved.localId;
      int? resolvedLocalId = localObraId;
      if (resolvedLocalId == null && obraUuid.isNotEmpty) {
        final rows = await db.query(
          'obras',
          columns: ['id'],
          where: 'uuid = ?',
          whereArgs: [obraUuid],
          limit: 1,
        );
        if (rows.isNotEmpty) {
          resolvedLocalId = rows.first['id'] as int?;
        }
      }

      if (obraUuid.isEmpty && resolvedLocalId == null) {
        continue;
      }

      List<Map<String, Object?>> existe = const [];
      if (userUuid.isNotEmpty && obraUuid.isNotEmpty) {
        existe = await db.query(
          'user_obras',
          where: 'user_uuid = ? AND obra_uuid = ?',
          whereArgs: [userUuid, obraUuid],
          limit: 1,
        );
      }
      if (existe.isEmpty && userId > 0 && resolvedLocalId != null) {
        existe = await db.query(
          'user_obras',
          where: 'user_id = ? AND obra_id = ?',
          whereArgs: [userId, resolvedLocalId],
          limit: 1,
        );
      }
      if (existe.isNotEmpty) {
        if (resolvedLocalId != null &&
            (existe.first['obra_id'] as int?) != resolvedLocalId) {
          await db.update(
            'user_obras',
            {
              'obra_id': resolvedLocalId,
              if (obraUuid.isNotEmpty) 'obra_uuid': obraUuid,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            where: 'id = ?',
            whereArgs: [existe.first['id']],
          );
        }
        continue;
      }

      await db.insert('user_obras', {
        'user_id': userId > 0 ? userId : null,
        'obra_id': resolvedLocalId ?? serverObraId,
        'user_uuid': userUuid.isEmpty ? null : userUuid,
        'obra_uuid': obraUuid.isEmpty ? null : obraUuid,
        'permissao': 'visualizar',
        'situacao': 1,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    }
  } catch (e) {
    debugPrint('ensureLocalUserObraLinksFromAllowedIds: $e');
  }
}

Future<List<CarregaObrasRow>> _queryObrasByUuids(List<String> uuids) async {
  if (uuids.isEmpty) return [];
  final owner = FFAppState().creatorUuid.trim();
  if (owner.isEmpty) return [];
  final db = SQLiteManager.instance.database;
  final placeholders = List.filled(uuids.length, '?').join(',');
  final rows = await db.rawQuery(
    '''
SELECT o.*
FROM obras AS o
WHERE o.uuid IN ($placeholders)
  AND o.user_uuid = ?
  AND (o.situacao IS NULL OR CAST(o.situacao AS INTEGER) != $kSituacaoExcluidoLogico)
ORDER BY o.nome
''',
    [...uuids, owner],
  );
  return rows.map(CarregaObrasRow.new).toList();
}

Future<List<CarregaObrasRow>> _queryObrasByServerIds(List<int> serverIds) async {
  if (serverIds.isEmpty) return [];
  final owner = FFAppState().creatorUuid.trim();
  if (owner.isEmpty) return [];
  final db = SQLiteManager.instance.database;
  final placeholders = List.filled(serverIds.length, '?').join(',');
  final rows = await db.rawQuery(
    '''
SELECT o.*
FROM obras AS o
INNER JOIN sync_id_mapping AS m
  ON m.tabela = 'obras' AND m.uuid = o.uuid
WHERE CAST(m.id_servidor AS INTEGER) IN ($placeholders)
  AND o.user_uuid = ?
  AND (o.situacao IS NULL OR CAST(o.situacao AS INTEGER) != $kSituacaoExcluidoLogico)
ORDER BY o.nome
''',
    [...serverIds, owner],
  );
  return rows.map(CarregaObrasRow.new).toList();
}

/// Lista de obras acessíveis (respeita obra_travada + allowed_obra_ids do servidor).
Future<List<CarregaObrasRow>> loadAccessibleObras() async {
  // Espelha a API antes de listar o SQLite (mesma falha da mão de obra / OS).
  try {
    final online = await actions.checkInternetConnection();
    if (online) {
      await actions.syncObras();
    }
  } catch (_) {}

  if (!MembershipAccess.obraTravada) {
    return SQLiteManager.instance.carregaObras(
      creatorUuid: FFAppState().creatorUuid,
      currentUserUuid: FFAppState().UserUuid,
      tenantUserId: FFAppState().activeTenantUserId,
      forceObraTravada: false,
    );
  }

  await refreshAllowedObraIdsIfNeeded();

  final serverIds = FFAppState().allowedObraIds;
  var uuids = FFAppState().allowedObraUuids;
  var localIds = FFAppState().allowedObraLocalIds;

  if (uuids.isNotEmpty) {
    final byUuid = await _queryObrasByUuids(uuids);
    if (byUuid.isNotEmpty) return byUuid;
  }

  if (serverIds.isNotEmpty) {
    final byServer = await _queryObrasByServerIds(serverIds);
    if (byServer.isNotEmpty) {
      FFAppState().allowedObraUuids = byServer.map((o) => o.uuid).toList();
      FFAppState().allowedObraLocalIds = byServer.map((o) => o.id).toList();
      return byServer;
    }
  }

  // Re-tenta após garantir vínculos / cache.
  await ensureLocalUserObraLinksFromAllowedIds();
  await refreshAllowedObraLocalIdsCache();
  uuids = FFAppState().allowedObraUuids;
  localIds = FFAppState().allowedObraLocalIds;

  if (uuids.isNotEmpty) {
    final byUuid = await _queryObrasByUuids(uuids);
    if (byUuid.isNotEmpty) return byUuid;
  }

  return SQLiteManager.instance.carregaObras(
    creatorUuid: FFAppState().creatorUuid,
    currentUserUuid: FFAppState().UserUuid,
    tenantUserId: FFAppState().activeTenantUserId,
    allowedObraIds: localIds.isNotEmpty ? localIds : null,
    forceObraTravada: true,
  );
}

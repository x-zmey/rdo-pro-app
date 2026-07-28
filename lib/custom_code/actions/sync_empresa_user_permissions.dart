import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'sync_tenant_headers.dart';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

void _updateSyncStatus(bool success, String message, int downloaded) {
  try {
    FFAppState().update(() {
      FFAppState().syncSuccess = success;
      FFAppState().syncMessage = message;
      FFAppState().syncUploadedCount = 0;
      FFAppState().syncDownloadedCount = downloaded;
      FFAppState().lastSyncTime = DateTime.now().toIso8601String();
    });
  } catch (e) {
    print('❌ Erro ao atualizar AppState: $e');
  }
}

Future<void> _purgeTenantPermissionsBeforeFullSync(
  Database db,
  int tenantId,
) async {
  try {
    await db.rawDelete(
      '''
DELETE FROM empresa_user_permission
WHERE empresa_user_id_server IN (
  SELECT COALESCE(id_server, id) FROM empresa_users WHERE tenant_user_id = ?
)
OR empresa_user_id_server = ?
''',
      [tenantId, tenantId],
    );
  } catch (e) {
    print('⚠️ purge permissões tenant: $e');
  }
}

Future syncEmpresaUserPermissions() async {
  try {
    final token = FFAppState().UserToken;
    if (token.isEmpty) {
      _updateSyncStatus(false, 'Usuário não autenticado para sync permissões.', 0);
      return;
    }

    final db = await SQLiteManager.instance.database;
    final tenantId = FFAppState().activeTenantUserId;

    // Sempre full sync: remoção de permissão no servidor (DELETE) não aparece
    // no incremental e o app continuava liberando generate_rdo / view_clientes.
    const lastSync = '2000-01-01T00:00:00.000Z';
    if (tenantId > 0) {
      await _purgeTenantPermissionsBeforeFullSync(db, tenantId);
    }

    final response = await http.post(
      Uri.parse(
        'https://api.rdopro.com.br/api/v1/sync/empresa-user-permissions/download',
      ),
      headers: syncAuthHeaders(),
      body: json.encode({'ultima_sync': lastSync, 'force_full': true}),
    );

    if (response.statusCode == 401) {
      _updateSyncStatus(false, 'Token expirado. Faça login novamente.', 0);
      return;
    }
    if (response.statusCode != 200) {
      _updateSyncStatus(
        false,
        'Erro ao baixar permissões: ${response.statusCode}',
        0,
      );
      return;
    }

    final jsonBody = json.decode(response.body) as Map<String, dynamic>;
    final dadosRaw = jsonBody['dados'];
    final dados = dadosRaw is List ? dadosRaw : <dynamic>[];

    var count = 0;
    for (final item in dados) {
      if (item is Map<String, dynamic>) {
        await upsertEmpresaUserPermissionFromServer(db, item);
        count++;
      }
    }

    await refreshAppStatePermissoesFromSqlite();

    _updateSyncStatus(
      true,
      'Sync permissões concluída: ↓$count',
      count,
    );
  } catch (e) {
    _updateSyncStatus(false, 'Erro geral sync permissões: $e', 0);
  }
}

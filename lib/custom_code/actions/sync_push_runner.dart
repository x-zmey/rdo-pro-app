import '/auth/apply_membership_auth.dart';
import '/auth/fetch_allowed_obras.dart';
import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import 'index.dart' as actions;

/// Mesma sequência usada no carregamento inicial do [InicioWidget], para ser
/// disparada por push (foreground/background) quando o payload pedir sync.
Future<void>? _runningFullSync;

Future<void> runFullSyncPipelineFromPush() async {
  final current = _runningFullSync;
  if (current != null) {
    await current;
    return;
  }

  final future = _runFullSyncPipelineInternal();
  _runningFullSync = future;
  try {
    await future;
  } finally {
    if (identical(_runningFullSync, future)) {
      _runningFullSync = null;
    }
  }
}

Future<void> _runFullSyncPipelineInternal() async {
  final syncId = await actions.startSyncHistory();
  try {
    await actions.checkSyncStatus();
    await actions.syncClientes();
    await actions.syncUsers();
    // Obras antes dos vínculos: sync_id_mapping precisa existir para mapear obra_id.
    await actions.syncGruposObras();
    await actions.syncObras();
    await refreshAllowedObraIdsIfNeeded();
    await actions.syncUserObras();
    await actions.syncEmpresaUserPermissions();
    await refreshAppStatePermissoesFromSqlite();
    // Sessão da API prevalece (evita permissões revogadas que ficaram no SQLite).
    await refreshSessionFromServer();
    // Após vínculos + obras: UUIDs da API e user_obras locais.
    await refreshAllowedObraIdsIfNeeded();
    await actions.syncEquipamentos();
    await actions.syncInsumos();
    await actions.syncLocais();
    await actions.syncFuncoesMaoObra();
    await actions.syncMaoObra();
    await actions.syncTipoOcorrencias();
    await actions.syncModelosRelatorios();
    await actions.syncObrasEtapas();
    await actions.syncObrasTarefas();
    await actions.syncObrasItens();
    await actions.syncObraLocais();
    await actions.syncOrdens();
    await actions.syncOrdensTarefas();
    await actions.syncOrdensCustos();
    await actions.syncOrdensAssinaturas();
    await actions.syncRelatorios();
    await actions.syncRelatoriosAtividades();
    await actions.syncRelatoriosAtividadesItens();
    await actions.syncRelatorioAtividadesFotos();
    await actions.synRelatoriosOrdens();
    await actions.syncRelatoriosCustos();
    await actions.synRelatoriosMaoObraPresenca();
    await actions.synRelatoriosComentarios();
    await actions.synRelatoriosAnexos();
    await actions.synRelatorioEquipamentoRecebido();
    await actions.syncRelatorioOcorrencias();
    await actions.syncChecklistTemplates();
    await actions.syncChecklistsPreenchidos();
    await actions.syncPlanosAcoes();
    await actions.syncSolucoesPlanosAcoes();
    await actions.finishSuccessSync(syncId);
  } catch (_) {
    await actions.finishErrorSync(syncId);
    rethrow;
  }
}

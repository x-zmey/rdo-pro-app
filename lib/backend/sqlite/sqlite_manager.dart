import 'package:flutter/foundation.dart';

import '/backend/sqlite/init.dart';
import '/backend/sqlite/sincronizar_custos_os_uso.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'queries/read.dart';
import 'queries/update.dart';

import 'package:sqflite/sqflite.dart';
export 'queries/read.dart';
export 'queries/update.dart';
export 'situacao_soft_delete.dart';

class SQLiteManager {
  SQLiteManager._();

  static SQLiteManager? _instance;
  static SQLiteManager get instance => _instance ??= SQLiteManager._();

  static late Database _database;
  Database get database => _database;

  static Future initialize() async {
    if (kIsWeb) {
      return;
    }
    _database = await initializeDatabaseFromDbFile(
      'banconovomold6',
      'banco-novo-mold-6.db',
    );
  }

  /// START READ QUERY CALLS

  /// Namespace do tenant ativo (dono SaaS). Leituras/escritas usam como default.
  String get _tenantOwnerUuid => FFAppState().creatorUuid.trim();

  String _ownerOr(String? accountOwnerUuid) {
    final explicit = (accountOwnerUuid ?? '').trim();
    return explicit.isNotEmpty ? explicit : _tenantOwnerUuid;
  }


  Future<List<CarregaObrasRow>> carregaObras({
    String? creatorUuid,
    String? currentUserUuid,
    int? tenantUserId,
    List<int>? allowedObraIds,
    bool? forceObraTravada,
  }) =>
      performCarregaObras(
        _database,
        creatorUuid: _ownerOr(creatorUuid),
        currentUserUuid: currentUserUuid,
        tenantUserId: tenantUserId,
        allowedObraIds: allowedObraIds,
        forceObraTravada: forceObraTravada,
      );

  Future<List<CarregaPlanosRow>> carregaPlanos() => performCarregaPlanos(
        _database,
      );

  Future<List<ObraDetalhesRow>> obraDetalhes({
    String? uuid,
    int? userId,
    String? accountOwnerUuid,
  }) =>
      performObraDetalhes(
        _database,
        uuid: uuid,
        userId: userId,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future updateObra({
    String? uuid,
    int? grupoId,
    String? grupoUuid,
    int? clienteId,
    String? clienteUuid,
    String? nome,
    String? rua,
    String? numero,
    String? complemento,
    String? bairro,
    String? cidade,
    String? estado,
    String? engenheiro,
    String? dataInicio,
    String? dataFinal,
    String? contrato,
  }) =>
      performUpdateObra(
        _database,
        uuid: uuid,
        grupoId: grupoId,
        grupoUuid: grupoUuid,
        clienteId: clienteId,
        clienteUuid: clienteUuid,
        nome: nome,
        rua: rua,
        numero: numero,
        complemento: complemento,
        bairro: bairro,
        cidade: cidade,
        estado: estado,
        engenheiro: engenheiro,
        dataInicio: dataInicio,
        dataFinal: dataFinal,
        contrato: contrato,
      );

  Future<List<RelatoriosObraRow>> relatoriosObra({
    String? obraUuid,
    String? accountOwnerUuid,
    int? limit,
    int? offset,
  }) =>
      performRelatoriosObra(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
        limit: limit,
        offset: offset,
      );

  Future<List<RelatoriosGeraisRow>> relatoriosGerais({
    required int limit,
    required int offset,
    String? accountOwnerUuid,
    List<String>? allowedObraUuids,
  }) =>
      performRelatoriosGerais(
        _database,
        limit: limit,
        offset: offset,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
        allowedObraUuids: allowedObraUuids,
      );

  Future<List<RelatorioDetalhesRow>> relatorioDetalhes({
    String? uuid,
    String? userUuid,
    String? accountOwnerUuid,
  }) =>
      performRelatorioDetalhes(
        _database,
        uuid: uuid,
        userUuid: userUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<ModelosRelatoriosRow>> modelosRelatorios({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performModelosRelatorios(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaUltimoRelatorioRow>> carregaUltimoRelatorio({
    String? accountOwnerUuid,
    String? obraUuid,
  }) =>
      performCarregaUltimoRelatorio(
        _database,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
        obraUuid: obraUuid,
      );

  Future<List<ListaComentariosRelatoriosRow>> listaComentariosRelatorios({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performListaComentariosRelatorios(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaOcorrenciasRelatorioRow>> carregaOcorrenciasRelatorio({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performCarregaOcorrenciasRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaItensObraRow>> carregaItensObra({
    String? tipo,
    int? obraId,
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performCarregaItensObra(
        _database,
        tipo: tipo,
        obraId: obraId,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaComentariosObraRow>> carregaComentariosObra({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performCarregaComentariosObra(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaOcorrenciasObraRow>> carregaOcorrenciasObra({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performCarregaOcorrenciasObra(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<ListaEtapasObraRow>> listaEtapasObra({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performListaEtapasObra(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<ListaTarefasEtapasObraRow>> listaTarefasEtapasObra({
    String? etapaUuid,
    String? accountOwnerUuid,
  }) =>
      performListaTarefasEtapasObra(
        _database,
        etapaUuid: etapaUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  /// Todas as linhas da etapa (tarefa, insumo, equipamento, mão de obra) para árvore de planejamento.
  Future<List<ListaTarefasEtapasObraRow>> listaPlanejamentoEtapasObra({
    String? etapaUuid,
    String? accountOwnerUuid,
  }) =>
      performListaPlanejamentoEtapasObra(
        _database,
        etapaUuid: etapaUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<UltimosRelatoriosObraRow>> ultimosRelatoriosObra({
    int? obraId,
    int? userId,
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performUltimosRelatoriosObra(
        _database,
        obraId: obraId,
        userId: userId,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaAnexosRelatorioRow>> carregaAnexosRelatorio({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performCarregaAnexosRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<EquipamentosRecebidosObraRow>> equipamentosRecebidosObra({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performEquipamentosRecebidosObra(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<DetalhesMaterialRecebidoRow>> detalhesMaterialRecebido({
    String? uuid,
    String? accountOwnerUuid,
  }) =>
      performDetalhesMaterialRecebido(
        _database,
        uuid: uuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaUltimaAtividadeRelatorioRow>>
      carregaUltimaAtividadeRelatorio() =>
          performCarregaUltimaAtividadeRelatorio(
            _database,
          );

  Future<List<GetitensdaobraRow>> getitensdaobra({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performGetitensdaobra(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetItensAtividadeRow>> getItensAtividade({
    String? atividadeUuid,
    String? tipo,
    String? accountOwnerUuid,
  }) =>
      performGetItensAtividade(
        _database,
        atividadeUuid: atividadeUuid,
        tipo: tipo,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<CarregaFotosAtividadeRow>> carregaFotosAtividade({
    int? atividadeId,
    String? accountOwnerUuid,
  }) =>
      performCarregaFotosAtividade(
        _database,
        atividadeId: atividadeId,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetFotosAtividadeRow>> getFotosAtividade({
    String? atividadeUuid,
    int? atividadeId,
    String? accountOwnerUuid,
  }) =>
      performGetFotosAtividade(
        _database,
        atividadeUuid: atividadeUuid,
        atividadeId: atividadeId,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetDadosAtividadeRow>> getDadosAtividade({
    String? uuid,
    String? accountOwnerUuid,
  }) =>
      performGetDadosAtividade(
        _database,
        uuid: uuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetAtividadesRelatorioRow>> getAtividadesRelatorio({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performGetAtividadesRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetOrdensServicoRow>> getOrdensServico({
    String? obraUuid,
    int? userId,
    String? accountOwnerUuid,
  }) =>
      performGetOrdensServico(
        _database,
        obraUuid: obraUuid,
        userId: userId,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetTarefasOrdemRow>> getTarefasOrdem({
    String? ordemUuid,
    String? accountOwnerUuid,
  }) =>
      performGetTarefasOrdem(
        _database,
        ordemUuid: ordemUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetDetalhesTarefaRow>> getDetalhesTarefa({
    String? uuid,
    String? accountOwnerUuid,
  }) =>
      performGetDetalhesTarefa(
        _database,
        uuid: uuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetTarefasOrdemDetalhesRow>> getTarefasOrdemDetalhes({
    int? tarefaId,
    int? ordemId,
    String? obraEtapaTarefaUuid,
    String? ordemServicoUuid,
  }) =>
      performGetTarefasOrdemDetalhes(
        _database,
        tarefaId: tarefaId,
        ordemId: ordemId,
        obraEtapaTarefaUuid: obraEtapaTarefaUuid,
        ordemServicoUuid: ordemServicoUuid,
      );

  Future<List<GetGruposObrasRow>> getGruposObras({
    String? userUuid,
  }) =>
      performGetGruposObras(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<GetClientesRow>> getClientes({
    String? userUuid,
  }) =>
      performGetClientes(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<GetModelosChecklistRow>> getModelosChecklist({
    int? obraId,
    String? accountOwnerUuid,
  }) =>
      performGetModelosChecklist(
        _database,
        obraId: obraId,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetChecklistsPreenchidosRow>> getChecklistsPreenchidos({
    int? obraId,
    String? accountOwnerUuid,
  }) =>
      performGetChecklistsPreenchidos(
        _database,
        obraId: obraId,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetMaoObraRelatorioRow>> getMaoObraRelatorio({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performGetMaoObraRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetMaoObraRelatorioDetalhesRow>> getMaoObraRelatorioDetalhes({
    String? uuid,
    String? accountOwnerUuid,
  }) =>
      performGetMaoObraRelatorioDetalhes(
        _database,
        uuid: uuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetOrdensServicoRelatorioRow>> getOrdensServicoRelatorio({
    String? relatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performGetOrdensServicoRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetCustosOrdensRelatoriosRow>> getCustosOrdensRelatorios({
    String? ordemRelatorioUuid,
    String? accountOwnerUuid,
  }) =>
      performGetCustosOrdensRelatorios(
        _database,
        ordemRelatorioUuid: ordemRelatorioUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<DetalhesComentarioRow>> detalhesComentario({
    int? id,
    String? accountOwnerUuid,
  }) =>
      performDetalhesComentario(
        _database,
        id: id,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<DetalhesOcorrenciaRow>> detalhesOcorrencia({
    String? uuid,
    String? accountOwnerUuid,
  }) =>
      performDetalhesOcorrencia(
        _database,
        uuid: uuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetDetalhesItemAtividadeRow>> getDetalhesItemAtividade({
    String? uuid,
    String? accountOwnerUuid,
  }) =>
      performGetDetalhesItemAtividade(
        _database,
        uuid: uuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<GetTipoOcorrenciaDetalhesRow>> getTipoOcorrenciaDetalhes({
    int? id,
  }) =>
      performGetTipoOcorrenciaDetalhes(
        _database,
        id: id,
      );

  Future<List<GetTipoUserDetalhesCopyRow>> getTipoUserDetalhesCopy({
    int? idserver,
  }) =>
      performGetTipoUserDetalhesCopy(
        _database,
        idserver: idserver,
      );

  Future<List<GetStatusRelatorioDetalhesRow>> getStatusRelatorioDetalhes({
    int? id,
  }) =>
      performGetStatusRelatorioDetalhes(
        _database,
        id: id,
      );

  Future<List<GetIdServidorRow>> getIdServidor({
    String? tabela,
    String? uuid,
  }) =>
      performGetIdServidor(
        _database,
        tabela: tabela,
        uuid: uuid,
      );

  Future<List<GetEquipamentosRow>> getEquipamentos({
    String? userUuid,
  }) =>
      performGetEquipamentos(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<GetInsumosRow>> getInsumos({
    String? userUuid,
  }) =>
      performGetInsumos(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<GetLocaisRow>> getLocais({
    String? userUuid,
  }) =>
      performGetLocais(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<GetFuncoesMaoObraRow>> getFuncoesMaoObra({
    String? userUuid,
  }) =>
      performGetFuncoesMaoObra(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<GetMaoObraRow>> getMaoObra({
    String? userUuid,
  }) =>
      performGetMaoObra(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<GetUsuariosRow>> getUsuarios({
    String? userUuid,
    int? tenantUserId,
  }) =>
      performGetUsuarios(
        _database,
        userUuid: userUuid,
        tenantUserId: tenantUserId,
      );

  Future<List<SituacaoObraRow>> situacaoObra({
    int? id,
  }) =>
      performSituacaoObra(
        _database,
        id: id,
      );

  Future<List<SituacaoObraRow>> listaSituacaoObras() =>
      performListaSituacaoObras(_database);

  Future<List<GetTipoOcorrenciasRow>> getTipoOcorrencias({
    String? userUuid,
  }) =>
      performGetTipoOcorrencias(
        _database,
        userUuid: _ownerOr(userUuid),
      );

  Future<List<RelatorioDetalhesCopyRow>> relatorioDetalhesCopy({
    String? uuid,
    String? userUuid,
    String? accountOwnerUuid,
  }) =>
      performRelatorioDetalhesCopy(
        _database,
        uuid: uuid,
        userUuid: userUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid ?? userUuid),
      );

  Future<List<RelatoriosObraUltimosRow>> relatoriosObraUltimos({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performRelatoriosObraUltimos(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<ObraLocaisRow>> obraLocais({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performObraLocais(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: _ownerOr(accountOwnerUuid),
      );

  Future<List<SyncHistoryRecentRow>> syncHistoryRecent({
    String? userUuid,
    int? userId,
    int limit = 10,
  }) =>
      performSyncHistoryRecent(
        _database,
        userUuid: userUuid,
        userId: userId,
        limit: limit,
      );

  /// END READ QUERY CALLS

  /// START UPDATE QUERY CALLS

  Future cadastrarObra({
    int? userId,
    String? nome,
  }) =>
      performCadastrarObra(
        _database,
        userId: userId,
        nome: nome,
      );

  Future cadastrarRelatorio({
    int? userId,
    int? obraId,
    int? modeloId,
    String? dataexecutado,
    String? dataInicio,
    String? dataFinal,
    String? criador,
    int? numero,
    String? uuid,
    String? creatorUuid,
    String? userUuid,
    String? obraUuid,
    String? modeloUuid,
  }) =>
      performCadastrarRelatorio(
        _database,
        userId: userId,
        obraId: obraId,
        modeloId: modeloId,
        dataexecutado: dataexecutado,
        dataInicio: dataInicio,
        dataFinal: dataFinal,
        criador: criador,
        numero: numero,
        uuid: uuid,
        creatorUuid: creatorUuid,
        userUuid: userUuid,
        obraUuid: obraUuid,
        modeloUuid: modeloUuid,
      );

  Future addComentarioRelatorio({
    int? relatorioId,
    String? texto,
    String? createdBy,
    String? createdAt,
    String? relatorioUuid,
    String? uuid,
  }) =>
      performAddComentarioRelatorio(
        _database,
        relatorioId: relatorioId,
        texto: texto,
        createdBy: createdBy,
        createdAt: createdAt,
        relatorioUuid: relatorioUuid,
        uuid: uuid,
      );

  Future addOcorrenciaRelatorio({
    int? userId,
    int? relatorioId,
    String? descricao,
    String? horaInicio,
    String? horaFim,
    String? relatorioUuid,
    String? uuid,
    String? creatorUuid,
    String? userUuid,
    String? tipoUuid,
    int? situacao,
  }) =>
      performAddOcorrenciaRelatorio(
        _database,
        userId: userId,
        relatorioId: relatorioId,
        descricao: descricao,
        horaInicio: horaInicio,
        horaFim: horaFim,
        relatorioUuid: relatorioUuid,
        uuid: uuid,
        creatorUuid: creatorUuid,
        userUuid: userUuid,
        tipoUuid: tipoUuid,
        situacao: situacao,
      );

  Future addAnexoRelatorio({
    int? relatorioId,
    String? nome,
    String? createdBy,
    String? createdAt,
    String? arquivo,
    String? relatorioUuid,
    String? uuid,
  }) =>
      performAddAnexoRelatorio(
        _database,
        relatorioId: relatorioId,
        nome: nome,
        createdBy: createdBy,
        createdAt: createdAt,
        arquivo: arquivo,
        relatorioUuid: relatorioUuid,
        uuid: uuid,
      );

  Future updateAnexoRelatorioNome({
    required String uuid,
    required String nome,
  }) =>
      performUpdateAnexoRelatorioNome(
        _database,
        uuid: uuid,
        nome: nome,
      );

  Future cadastraEquipamentoRecebidoRelatorio({
    int? relatorioId,
    int? equipamentoId,
    num? quantidade,
    String? createdBy,
    String? relatorioUuid,
    String? equipamentoUuid,
    String? uuid,
  }) =>
      performCadastraEquipamentoRecebidoRelatorio(
        _database,
        relatorioId: relatorioId,
        equipamentoId: equipamentoId,
        quantidade: quantidade,
        createdBy: createdBy,
        relatorioUuid: relatorioUuid,
        equipamentoUuid: equipamentoUuid,
        uuid: uuid,
      );

  Future insertAtividadeRelatorio({
    int? userId,
    int? relatorioId,
    String? createdBy,
    String? local,
    String? descricao,
    int? quantidade,
    num? qtdRealizada,
    String? unidade,
    String? item,
    int? tarefaId,
    int? ordemId,
    String? ordemUuid,
    String? relatorioUuid,
    String? uuid,
    String? userUuid,
    String? tarefaUuid,
  }) =>
      performInsertAtividadeRelatorio(
        _database,
        userId: userId,
        relatorioId: relatorioId,
        createdBy: createdBy,
        local: local,
        descricao: descricao,
        quantidade: quantidade,
        qtdRealizada: qtdRealizada,
        unidade: unidade,
        item: item,
        tarefaId: tarefaId,
        ordemId: ordemId,
        ordemUuid: ordemUuid,
        relatorioUuid: relatorioUuid,
        uuid: uuid,
        userUuid: userUuid,
        tarefaUuid: tarefaUuid,
      );

  Future setItemAtividade({
    int? relatorioAtividadeId,
    String? tipo,
    int? obraItemId,
    String? relatorioAtividadeUuid,
    String? uuid,
    String? obraItemUuid,
    String? createdBy,
  }) =>
      performSetItemAtividade(
        _database,
        relatorioAtividadeId: relatorioAtividadeId,
        tipo: tipo,
        obraItemId: obraItemId,
        relatorioAtividadeUuid: relatorioAtividadeUuid,
        uuid: uuid,
        obraItemUuid: obraItemUuid,
        createdBy: (createdBy != null && createdBy.trim().isNotEmpty)
            ? createdBy.trim()
            : FFAppState().creatorUuid.trim(),
      );

  Future updateItemAtividade({
    num? qtdRealizada,
    String? uuid,
    num? qtdUtilizada,
    num? qtdProduzida,
  }) =>
      performUpdateItemAtividade(
        _database,
        qtdRealizada: qtdRealizada,
        uuid: uuid,
        qtdUtilizada: qtdUtilizada,
        qtdProduzida: qtdProduzida,
      );

  Future deleteItemAtividade({
    int? id,
  }) =>
      performDeleteItemAtividade(
        _database,
        id: id,
      );

  Future updateAtividade({
    required String uuid,
    String? local,
    String? descricao,
    num? qtdRealizada,
    String? unidade,
    int? situacao,
    int? ordemId,
    String? ordemUuid,
    bool updateOrdemVinculo = false,
  }) =>
      performUpdateAtividade(
        _database,
        uuid: uuid,
        local: local,
        descricao: descricao,
        qtdRealizada: qtdRealizada,
        unidade: unidade,
        situacao: situacao,
        ordemId: ordemId,
        ordemUuid: ordemUuid,
        updateOrdemVinculo: updateOrdemVinculo,
      );

  Future updateRelatorio({
    String? dataExecutado,
    String? horas,
    String? id,
    String? entradaManha,
    String? inicioIntervalo,
    String? fimIntervalo,
    String? saidaTarde,
  }) =>
      performUpdateRelatorio(
        _database,
        dataExecutado: dataExecutado,
        horas: horas,
        id: id,
        entradaManha: entradaManha,
        inicioIntervalo: inicioIntervalo,
        fimIntervalo: fimIntervalo,
        saidaTarde: saidaTarde,
      );

  Future setMaoObraRelatorio({
    int? relatorioId,
    int? companyId,
    int? obraItemId,
    String? dataReferencia,
    String? statusPresenca,
    String? horaEntrada,
    String? horaSaida,
    String? intervaloInicio,
    String? intervaloFim,
    String? horasTrabalhadas,
    String? createdBy,
    String? createdAt,
    String? relatorioUuid,
    String? uuid,
    String? companyUuid,
    String? obraItemUuid,
  }) =>
      performSetMaoObraRelatorio(
        _database,
        relatorioId: relatorioId,
        companyId: companyId,
        obraItemId: obraItemId,
        dataReferencia: dataReferencia,
        statusPresenca: statusPresenca,
        horaEntrada: horaEntrada,
        horaSaida: horaSaida,
        intervaloInicio: intervaloInicio,
        intervaloFim: intervaloFim,
        horasTrabalhadas: horasTrabalhadas,
        createdBy: createdBy,
        createdAt: createdAt,
        relatorioUuid: relatorioUuid,
        uuid: uuid,
        companyUuid: companyUuid,
        obraItemUuid: obraItemUuid,
      );

  Future updateMaoObraRelatorio({
    String? status,
    String? horaEntrada,
    String? horaSaida,
    String? intervaloInicio,
    String? intervaloFim,
    String? horasTrabalhadas,
    String? motivoAusencia,
    String? motivoSaidaCedo,
    String? motivoAtraso,
    String? uuid,
  }) =>
      performUpdateMaoObraRelatorio(
        _database,
        status: status,
        horaEntrada: horaEntrada,
        horaSaida: horaSaida,
        intervaloInicio: intervaloInicio,
        intervaloFim: intervaloFim,
        horasTrabalhadas: horasTrabalhadas,
        motivoAusencia: motivoAusencia,
        motivoSaidaCedo: motivoSaidaCedo,
        motivoAtraso: motivoAtraso,
        uuid: uuid,
      );

  Future setOrdemRelatorio({
    int? relatorioId,
    int? ordemId,
    int? userId,
    String? relatorioUuid,
  }) =>
      performSetOrdemRelatorio(
        _database,
        relatorioId: relatorioId,
        ordemId: ordemId,
        userId: userId,
        relatorioUuid: relatorioUuid,
      );

  Future setCustosOrdemRelatorio({
    int? relatorioId,
    int? ordemId,
    int? relatorioOrdemServicoId,
    int? ordemServicoCustoId,
    double? qtdRealizada,
    double? valorUnitario,
    double? valorTotal,
    String? observacao,
    int? userId,
    String? relatorioUuid,
    String? relatorioOrdemServicoUuid,
    String? ordemServicoCustoUuid,
  }) =>
      performSetCustosOrdemRelatorio(
        _database,
        relatorioId: relatorioId,
        ordemId: ordemId,
        relatorioOrdemServicoId: relatorioOrdemServicoId,
        ordemServicoCustoId: ordemServicoCustoId,
        qtdRealizada: qtdRealizada,
        valorUnitario: valorUnitario,
        valorTotal: valorTotal,
        observacao: observacao,
        userId: userId,
        relatorioUuid: relatorioUuid,
        relatorioOrdemServicoUuid: relatorioOrdemServicoUuid,
        ordemServicoCustoUuid: ordemServicoCustoUuid,
      );

  Future<void> updateRelatorioCustoQtdRealizada({
    String? uuid,
    double? qtdRealizada,
  }) =>
      performUpdateRelatorioCustoQtdRealizada(
        _database,
        uuid: uuid,
        qtdRealizada: qtdRealizada,
      );

  Future<void> sincronizarCustosOsComUsoAtividades({
    int? relatorioId,
    String? relatorioUuid,
  }) =>
      performSincronizarCustosOsComUsoAtividades(
        _database,
        relatorioId: relatorioId,
        relatorioUuid: relatorioUuid,
      );

  Future updateEquipamentoRecebido({
    num? qtd,
    String? uuid,
  }) =>
      performUpdateEquipamentoRecebido(
        _database,
        qtd: qtd,
        uuid: uuid,
      );

  Future deleteAnexoRelatorio({
    String? uuid,
  }) =>
      performDeleteAnexoRelatorio(
        _database,
        uuid: uuid,
      );

  Future deleteEquipamentoRecebido({
    String? uuid,
  }) =>
      performDeleteEquipamentoRecebido(
        _database,
        uuid: uuid,
      );

  Future deleteOcorrenciasRelatorio({
    String? uuid,
  }) =>
      performDeleteOcorrenciasRelatorio(
        _database,
        uuid: uuid,
      );

  Future deleteComentarioelatorio({
    String? uuid,
  }) =>
      performDeleteComentarioelatorio(
        _database,
        uuid: uuid,
      );

  Future deleteAtividadeRelatorio({
    int? id,
  }) =>
      performDeleteAtividadeRelatorio(
        _database,
        id: id,
      );

  Future deleteOrdemRelatorio({
    String? uuid,
  }) =>
      performDeleteOrdemRelatorio(
        _database,
        uuid: uuid,
      );

  Future deleteMaoObraRelatorio({
    String? uuid,
  }) =>
      performDeleteMaoObraRelatorio(
        _database,
        uuid: uuid,
      );

  Future softDeleteRelatorio({
    String? uuid,
  }) =>
      performSoftDeleteRelatorio(
        _database,
        uuid: uuid,
      );

  Future updateComentario({
    String? uuid,
    String? texto,
  }) =>
      performUpdateComentario(
        _database,
        uuid: uuid,
        texto: texto,
      );

  Future updateOcorrencia({
    String? uuid,
    String? descricao,
    String? horaInicio,
    String? horaFim,
    int? situacao,
  }) =>
      performUpdateOcorrencia(
        _database,
        uuid: uuid,
        descricao: descricao,
        horaInicio: horaInicio,
        horaFim: horaFim,
        situacao: situacao,
      );

  Future alterarStatusRelatorio({
    String? id,
    int? status,
  }) =>
      performAlterarStatusRelatorio(
        _database,
        id: id,
        status: status,
      );

  /// Marca o relatório como alterado localmente (`updated_at`, `synced = 0`).
  /// Use após gravar em tabelas filhas fora de [perform*] (ex.: fotos da atividade).
  Future touchRelatorioModificadoLocal({int? relatorioId}) =>
      performTouchRelatorioModificadoLocal(_database, relatorioId: relatorioId);

  /// END UPDATE QUERY CALLS
}

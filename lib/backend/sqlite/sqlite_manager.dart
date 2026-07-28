import 'package:flutter/foundation.dart';

import '/backend/sqlite/init.dart';
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

  Future<List<CarregaObrasRow>> carregaObras({
    String? creatorUuid,
    String? currentUserUuid,
    int? tenantUserId,
    List<int>? allowedObraIds,
    bool? forceObraTravada,
  }) =>
      performCarregaObras(
        _database,
        creatorUuid: creatorUuid,
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
        accountOwnerUuid: accountOwnerUuid,
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
        accountOwnerUuid: accountOwnerUuid,
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
        accountOwnerUuid: accountOwnerUuid,
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
        accountOwnerUuid: accountOwnerUuid,
      );

  Future<List<ModelosRelatoriosRow>> modelosRelatorios({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performModelosRelatorios(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: accountOwnerUuid,
      );

  Future<List<CarregaUltimoRelatorioRow>> carregaUltimoRelatorio({
    String? accountOwnerUuid,
  }) =>
      performCarregaUltimoRelatorio(
        _database,
        accountOwnerUuid: accountOwnerUuid,
      );

  Future<List<ListaComentariosRelatoriosRow>> listaComentariosRelatorios({
    String? relatorioUuid,
  }) =>
      performListaComentariosRelatorios(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<CarregaOcorrenciasRelatorioRow>> carregaOcorrenciasRelatorio({
    String? relatorioUuid,
  }) =>
      performCarregaOcorrenciasRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<CarregaItensObraRow>> carregaItensObra({
    String? tipo,
    int? obraId,
    String? obraUuid,
  }) =>
      performCarregaItensObra(
        _database,
        tipo: tipo,
        obraId: obraId,
        obraUuid: obraUuid,
      );

  Future<List<CarregaComentariosObraRow>> carregaComentariosObra({
    String? obraUuid,
  }) =>
      performCarregaComentariosObra(
        _database,
        obraUuid: obraUuid,
      );

  Future<List<CarregaOcorrenciasObraRow>> carregaOcorrenciasObra({
    String? obraUuid,
  }) =>
      performCarregaOcorrenciasObra(
        _database,
        obraUuid: obraUuid,
      );

  Future<List<ListaEtapasObraRow>> listaEtapasObra({
    String? obraUuid,
  }) =>
      performListaEtapasObra(
        _database,
        obraUuid: obraUuid,
      );

  Future<List<ListaTarefasEtapasObraRow>> listaTarefasEtapasObra({
    String? etapaUuid,
  }) =>
      performListaTarefasEtapasObra(
        _database,
        etapaUuid: etapaUuid,
      );

  /// Todas as linhas da etapa (tarefa, insumo, equipamento, mão de obra) para árvore de planejamento.
  Future<List<ListaTarefasEtapasObraRow>> listaPlanejamentoEtapasObra({
    String? etapaUuid,
  }) =>
      performListaPlanejamentoEtapasObra(
        _database,
        etapaUuid: etapaUuid,
      );

  Future<List<UltimosRelatoriosObraRow>> ultimosRelatoriosObra({
    int? obraId,
    int? userId,
  }) =>
      performUltimosRelatoriosObra(
        _database,
        obraId: obraId,
        userId: userId,
      );

  Future<List<CarregaAnexosRelatorioRow>> carregaAnexosRelatorio({
    String? relatorioUuid,
  }) =>
      performCarregaAnexosRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<EquipamentosRecebidosObraRow>> equipamentosRecebidosObra({
    String? relatorioUuid,
  }) =>
      performEquipamentosRecebidosObra(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<DetalhesMaterialRecebidoRow>> detalhesMaterialRecebido({
    String? uuid,
  }) =>
      performDetalhesMaterialRecebido(
        _database,
        uuid: uuid,
      );

  Future<List<CarregaUltimaAtividadeRelatorioRow>>
      carregaUltimaAtividadeRelatorio() =>
          performCarregaUltimaAtividadeRelatorio(
            _database,
          );

  Future<List<GetitensdaobraRow>> getitensdaobra({
    String? relatorioUuid,
  }) =>
      performGetitensdaobra(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<GetItensAtividadeRow>> getItensAtividade({
    String? atividadeUuid,
    String? tipo,
  }) =>
      performGetItensAtividade(
        _database,
        atividadeUuid: atividadeUuid,
        tipo: tipo,
      );

  Future<List<CarregaFotosAtividadeRow>> carregaFotosAtividade({
    int? atividadeId,
  }) =>
      performCarregaFotosAtividade(
        _database,
        atividadeId: atividadeId,
      );

  Future<List<GetFotosAtividadeRow>> getFotosAtividade() =>
      performGetFotosAtividade(
        _database,
      );

  Future<List<GetDadosAtividadeRow>> getDadosAtividade({
    String? uuid,
  }) =>
      performGetDadosAtividade(
        _database,
        uuid: uuid,
      );

  Future<List<GetAtividadesRelatorioRow>> getAtividadesRelatorio({
    String? relatorioUuid,
  }) =>
      performGetAtividadesRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<GetOrdensServicoRow>> getOrdensServico({
    String? obraUuid,
    int? userId,
  }) =>
      performGetOrdensServico(
        _database,
        obraUuid: obraUuid,
        userId: userId,
      );

  Future<List<GetTarefasOrdemRow>> getTarefasOrdem({
    String? ordemUuid,
  }) =>
      performGetTarefasOrdem(
        _database,
        ordemUuid: ordemUuid,
      );

  Future<List<GetDetalhesTarefaRow>> getDetalhesTarefa({
    String? uuid,
  }) =>
      performGetDetalhesTarefa(
        _database,
        uuid: uuid,
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
        userUuid: userUuid,
      );

  Future<List<GetClientesRow>> getClientes({
    String? userUuid,
  }) =>
      performGetClientes(
        _database,
        userUuid: userUuid,
      );

  Future<List<GetModelosChecklistRow>> getModelosChecklist({
    int? obraId,
  }) =>
      performGetModelosChecklist(
        _database,
        obraId: obraId,
      );

  Future<List<GetMaoObraRelatorioRow>> getMaoObraRelatorio({
    String? relatorioUuid,
  }) =>
      performGetMaoObraRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<GetMaoObraRelatorioDetalhesRow>> getMaoObraRelatorioDetalhes({
    String? uuid,
  }) =>
      performGetMaoObraRelatorioDetalhes(
        _database,
        uuid: uuid,
      );

  Future<List<GetOrdensServicoRelatorioRow>> getOrdensServicoRelatorio({
    String? relatorioUuid,
  }) =>
      performGetOrdensServicoRelatorio(
        _database,
        relatorioUuid: relatorioUuid,
      );

  Future<List<GetCustosOrdensRelatoriosRow>> getCustosOrdensRelatorios({
    String? ordemRelatorioUuid,
  }) =>
      performGetCustosOrdensRelatorios(
        _database,
        ordemRelatorioUuid: ordemRelatorioUuid,
      );

  Future<List<DetalhesComentarioRow>> detalhesComentario({
    int? id,
  }) =>
      performDetalhesComentario(
        _database,
        id: id,
      );

  Future<List<DetalhesOcorrenciaRow>> detalhesOcorrencia({
    String? uuid,
  }) =>
      performDetalhesOcorrencia(
        _database,
        uuid: uuid,
      );

  Future<List<GetDetalhesItemAtividadeRow>> getDetalhesItemAtividade({
    String? uuid,
  }) =>
      performGetDetalhesItemAtividade(
        _database,
        uuid: uuid,
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
        userUuid: userUuid,
      );

  Future<List<GetInsumosRow>> getInsumos({
    String? userUuid,
  }) =>
      performGetInsumos(
        _database,
        userUuid: userUuid,
      );

  Future<List<GetLocaisRow>> getLocais({
    String? userUuid,
  }) =>
      performGetLocais(
        _database,
        userUuid: userUuid,
      );

  Future<List<GetFuncoesMaoObraRow>> getFuncoesMaoObra({
    String? userUuid,
  }) =>
      performGetFuncoesMaoObra(
        _database,
        userUuid: userUuid,
      );

  Future<List<GetMaoObraRow>> getMaoObra({
    String? userUuid,
  }) =>
      performGetMaoObra(
        _database,
        userUuid: userUuid,
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
        userUuid: userUuid,
      );

  Future<List<RelatorioDetalhesCopyRow>> relatorioDetalhesCopy({
    String? uuid,
    String? userUuid,
  }) =>
      performRelatorioDetalhesCopy(
        _database,
        uuid: uuid,
        userUuid: userUuid,
      );

  Future<List<RelatoriosObraUltimosRow>> relatoriosObraUltimos({
    String? obraUuid,
    String? accountOwnerUuid,
  }) =>
      performRelatoriosObraUltimos(
        _database,
        obraUuid: obraUuid,
        accountOwnerUuid: accountOwnerUuid,
      );

  Future<List<ObraLocaisRow>> obraLocais({
    String? obraUuid,
  }) =>
      performObraLocais(
        _database,
        obraUuid: obraUuid,
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
    int? qtdRealizada,
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
    int? qtdRealizada,
    String? uuid,
    int? qtdUtilizada,
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
    int? qtdRealizada,
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

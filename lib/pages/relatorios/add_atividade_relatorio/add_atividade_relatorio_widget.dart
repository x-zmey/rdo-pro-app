import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/equipamentos_atividade_relatorio/equipamentos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/fotos_atividade/fotos_atividade_widget.dart';
import '/componentes/atividades_relatorios/insumos_atividade_relatorio/insumos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/mao_obra_atividade_relatorio/mao_obra_atividade_relatorio_widget.dart';
import '/componentes/dialogs/cadastrar_equipamento_obra/cadastrar_equipamento_obra_dialog.dart';
import '/componentes/dialogs/cadastrar_insumo_obra/cadastrar_insumo_obra_dialog.dart';
import '/componentes/dialogs/cadastrar_mao_obra_obra/cadastrar_mao_obra_obra_dialog.dart';
import '/componentes/relatorios/includes/botao_cadastro_obra_atalho/botao_cadastro_obra_atalho_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'add_atividade_relatorio_model.dart';
export 'add_atividade_relatorio_model.dart';
import 'dart:math' as math;

/// Rótulo do select: descrição + cargo/função em [obra_itens], quando houver.
String _labelMaoObraRelatorioPresente(GetMaoObraRelatorioRow e) {
  final d = (e.descricao ?? '').trim();
  final c = (e.cargoFuncao ?? '').trim();
  if (d.isEmpty && c.isEmpty) return 'Mão de obra';
  if (c.isEmpty) return d;
  if (d.isEmpty) return c;
  return '$d — $c';
}

double _parseQuantidade(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  final t = v.toString().trim().replaceAll(',', '.');
  if (t.isEmpty) return 0;
  return double.tryParse(t) ?? 0;
}

/// Quantidade planejada na obra: valor na atividade ou, se ausente/zero, planejamento da tarefa.
double _qtdPlanejadaObra(
  GetDadosAtividadeRow row,
  GetDetalhesTarefaRow? detalhesTarefa,
) {
  final q = _parseQuantidade(row.quantidade);
  if (q > 0) return q;
  return _parseQuantidade(detalhesTarefa?.qtd);
}

Color _corBarraProgresso(BuildContext context, double porcentagem) {
  final t = FlutterFlowTheme.of(context);
  if (porcentagem >= 100) return t.success;
  if (porcentagem >= 75) return t.primary;
  if (porcentagem >= 50) return t.tertiary;
  return t.error;
}

class _DadosPaginaAtividade {
  const _DadosPaginaAtividade({
    required this.atividadeRows,
    required this.locais,
    required this.ordensServico,
    this.detalhesTarefa,
    this.linhaOrdemServico,
  });

  final List<GetDadosAtividadeRow> atividadeRows;
  final List<ObraLocaisRow> locais;
  final List<GetOrdensServicoRow> ordensServico;
  final GetDetalhesTarefaRow? detalhesTarefa;
  final GetTarefasOrdemDetalhesRow? linhaOrdemServico;
}

class AddAtividadeRelatorioWidget extends StatefulWidget {
  const AddAtividadeRelatorioWidget({
    super.key,
    required this.relatorioId,
    required this.obraId,
    required this.atividadeId,
    required this.atividadeUuid,
    required this.relatorioUuid,
    required this.obraUuid,
  });

  final int? relatorioId;
  final int? obraId;
  final int? atividadeId;
  final String? atividadeUuid;
  final String? relatorioUuid;
  final String? obraUuid;

  static String routeName = 'addAtividadeRelatorio';
  static String routePath = '/addAtividadeRelatorio';

  @override
  State<AddAtividadeRelatorioWidget> createState() =>
      _AddAtividadeRelatorioWidgetState();
}

class _AddAtividadeRelatorioWidgetState
    extends State<AddAtividadeRelatorioWidget> {
  late AddAtividadeRelatorioModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  late final Future<_DadosPaginaAtividade> _futureDadosPagina;

  Future<_DadosPaginaAtividade> _carregarDadosPagina() async {
    final atividadeRows = await SQLiteManager.instance.getDadosAtividade(
      uuid: widget.atividadeUuid!,
    );
    final locais = await SQLiteManager.instance.obraLocais(
      obraUuid: widget.obraUuid!,
    );
    final ordensServico =
        (widget.obraUuid != null && widget.obraUuid!.trim().isNotEmpty)
            ? await SQLiteManager.instance.getOrdensServico(
                obraUuid: widget.obraUuid,
              )
            : <GetOrdensServicoRow>[];

    final row = atividadeRows.firstOrNull;
    GetDetalhesTarefaRow? detalhes;
    GetTarefasOrdemDetalhesRow? linhaOs;
    if (row != null && !row.isAtividadeAvulsa) {
      final tu = row.tarefaUuid?.trim();
      if (tu != null && tu.isNotEmpty) {
        final d = await SQLiteManager.instance.getDetalhesTarefa(uuid: tu);
        detalhes = d.firstOrNull;
      }
      final tid = row.tarefaId;
      var oid = row.ordemId;
      final ou = row.ordemUuid?.trim();
      if ((oid == null || oid <= 0) &&
          ou != null &&
          ou.isNotEmpty) {
        oid = ordensServico
            .where((o) => o.uuid == ou)
            .firstOrNull
            ?.id;
      }
      final temTarefa =
          (tid != null && tid > 0) || (tu != null && tu.isNotEmpty);
      final temOrdem =
          (oid != null && oid > 0) || (ou != null && ou.isNotEmpty);
      if (temTarefa && temOrdem) {
        final lo = await SQLiteManager.instance.getTarefasOrdemDetalhes(
          tarefaId: tid,
          ordemId: oid,
          obraEtapaTarefaUuid: tu,
          ordemServicoUuid: ou,
        );
        linhaOs = lo.firstOrNull;
      }
    }

    return _DadosPaginaAtividade(
      atividadeRows: atividadeRows,
      locais: locais,
      ordensServico: ordensServico,
      detalhesTarefa: detalhes,
      linhaOrdemServico: linhaOs,
    );
  }

  int _insumosObraReloadToken = 0;
  int _equipamentosObraReloadToken = 0;
  int _maoObraRelatorioReloadToken = 0;
  int _listasItensAtividadeRefresh = 0;

  late Future<List<CarregaItensObraRow>> _futureItensObraInsumo;
  late Future<List<CarregaItensObraRow>> _futureItensObraEquipamento;
  late Future<List<GetMaoObraRelatorioRow>> _futureMaoObraPresente;

  Future<List<CarregaItensObraRow>> _loadItensObraInsumo() {
    return SQLiteManager.instance.carregaItensObra(
      tipo: 'insumo',
      obraId: widget.obraId,
      obraUuid: widget.obraUuid!,
    );
  }

  Future<List<CarregaItensObraRow>> _loadItensObraEquipamento() {
    return SQLiteManager.instance.carregaItensObra(
      tipo: 'equipamento',
      obraId: widget.obraId,
      obraUuid: widget.obraUuid!,
    );
  }

  Future<List<GetMaoObraRelatorioRow>> _loadMaoObraPresenteRelatorio() async {
    final rows = await SQLiteManager.instance.getMaoObraRelatorio(
      relatorioUuid: widget.relatorioUuid!,
    );
    final seen = <String>{};
    final out = <GetMaoObraRelatorioRow>[];
    for (final e in rows) {
      if (e.statusPresenca.trim().toLowerCase() != 'presente') continue;
      final u = (e.obraItemUuid ?? '').trim();
      if (u.isEmpty) continue;
      if (seen.add(u)) out.add(e);
    }
    return out;
  }

  void _reloadInsumosObraDropdown() {
    setState(() {
      _insumosObraReloadToken++;
      _futureItensObraInsumo = _loadItensObraInsumo();
    });
  }

  void _reloadEquipamentosObraDropdown() {
    setState(() {
      _equipamentosObraReloadToken++;
      _futureItensObraEquipamento = _loadItensObraEquipamento();
    });
  }

  void _reloadMaoObraDropdown() {
    setState(() {
      _maoObraRelatorioReloadToken++;
      _futureMaoObraPresente = _loadMaoObraPresenteRelatorio();
    });
  }

  void _atualizarListasItensAtividade() {
    if (!mounted) return;
    setState(() => _listasItensAtividadeRefresh++);
  }

  String _hhmmFromRelatorioField(String? raw, String fallback) {
    final t = (raw ?? '').trim();
    if (t.isEmpty) return fallback;
    final m = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(t);
    if (m == null) return fallback;
    final h = (int.tryParse(m.group(1)!) ?? 0).clamp(0, 23);
    return '${h.toString().padLeft(2, '0')}:${m.group(2)}';
  }

  Future<bool> _itemJaVinculadoNaAtividade({
    required String tipo,
    required String obraItemUuid,
  }) async {
    final u = obraItemUuid.trim();
    if (u.isEmpty || u == '0') return false;
    final itens = await SQLiteManager.instance.getItensAtividade(
      atividadeUuid: widget.atividadeUuid!,
      tipo: tipo,
    );
    return itens.any(
      (e) => (e.obraItemUuid ?? '').trim().toLowerCase() == u.toLowerCase(),
    );
  }

  Future<void> _vincularItemAtividade({
    required String tipo,
    required String obraItemUuid,
  }) async {
    if (obraItemUuid.trim().isEmpty || obraItemUuid == '0') return;
    if (await _itemJaVinculadoNaAtividade(
      tipo: tipo,
      obraItemUuid: obraItemUuid,
    )) {
      return;
    }
    final itemUuid = await actions.generateUuid();
    await SQLiteManager.instance.setItemAtividade(
      relatorioAtividadeId: widget.atividadeId!,
      tipo: tipo,
      obraItemId: 0,
      relatorioAtividadeUuid: widget.atividadeUuid,
      obraItemUuid: obraItemUuid,
      uuid: itemUuid,
    );
    _atualizarListasItensAtividade();
  }

  void _atualizarSelecaoDropdown({
    required String uuid,
    required void Function(String?) setDropDownValue,
    required void Function(String?) setSelected,
    required void Function(FormFieldController<String>?) setController,
  }) {
    setDropDownValue(uuid);
    setSelected(uuid);
    setController(FormFieldController<String>(uuid));
  }

  Future<void> _inserirMaterialRecebidoRelatorio(String obraItemUuid) async {
    final uuid = await actions.generateUuid();
    await SQLiteManager.instance.cadastraEquipamentoRecebidoRelatorio(
      relatorioId: 0,
      equipamentoId: 0,
      quantidade: 1,
      createdBy: FFAppState().creatorUuid,
      relatorioUuid: widget.relatorioUuid,
      equipamentoUuid: obraItemUuid,
      uuid: uuid,
    );
  }

  Future<void> _inserirMaoObraPresenteRelatorio(String obraItemUuid) async {
    final relRows = await SQLiteManager.instance.relatorioDetalhes(
      uuid: widget.relatorioUuid!,
      userUuid: FFAppState().creatorUuid,
      accountOwnerUuid: FFAppState().creatorUuid,
    );
    final relDet = relRows.firstOrNull;
    if (relDet?.dataExecutado == null) return;

    final uuid = await actions.generateUuid();
    await SQLiteManager.instance.setMaoObraRelatorio(
      relatorioId: 0,
      companyId: FFAppState().creatorId,
      obraItemId: 0,
      dataReferencia: relDet!.dataExecutado!,
      statusPresenca: 'presente',
      horaEntrada: _hhmmFromRelatorioField(relDet.entradaManha, '08:00'),
      horaSaida: _hhmmFromRelatorioField(relDet.saidaTarde, '17:00'),
      intervaloInicio: _hhmmFromRelatorioField(relDet.inicioIntervalo, '11:00'),
      intervaloFim: _hhmmFromRelatorioField(relDet.fimIntervalo, '13:00'),
      horasTrabalhadas: '8',
      createdBy: FFAppState().creatorUuid,
      createdAt: valueOrDefault<String>(
        dateTimeFormat('d/M/y', getCurrentTimestamp),
        '13/1/2026',
      ),
      relatorioUuid: widget.relatorioUuid,
      uuid: uuid,
      companyUuid: FFAppState().creatorUuid,
      obraItemUuid: obraItemUuid,
    );
  }

  Future<void> _cadastrarEVincularInsumo() async {
    final novoUuid = await showCadastrarInsumoObraDialog(
      context: context,
      obraUuid: widget.obraUuid!,
      obraId: widget.obraId,
    );
    if (!mounted || novoUuid == null || novoUuid.trim().isEmpty) return;

    await _inserirMaterialRecebidoRelatorio(novoUuid);
    await _vincularItemAtividade(tipo: 'insumo', obraItemUuid: novoUuid);
    safeSetState(() {
      _atualizarSelecaoDropdown(
        uuid: novoUuid,
        setDropDownValue: (v) => _model.dropDownInsumoValue = v,
        setSelected: (v) => _model.insumoSelected = v,
        setController: (c) => _model.dropDownInsumoValueController = c,
      );
    });
    _reloadInsumosObraDropdown();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Insumo cadastrado na obra, registrado no relatório e vinculado à atividade.',
          style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  Future<void> _cadastrarEVincularEquipamento() async {
    final novoUuid = await showCadastrarEquipamentoObraDialog(
      context: context,
      obraUuid: widget.obraUuid!,
      obraId: widget.obraId,
    );
    if (!mounted || novoUuid == null || novoUuid.trim().isEmpty) return;

    await _vincularItemAtividade(tipo: 'equipamento', obraItemUuid: novoUuid);
    safeSetState(() {
      _atualizarSelecaoDropdown(
        uuid: novoUuid,
        setDropDownValue: (v) => _model.dropDownEquipamentosValue = v,
        setSelected: (v) => _model.equipamentoSelected = v,
        setController: (c) => _model.dropDownEquipamentosValueController = c,
      );
    });
    _reloadEquipamentosObraDropdown();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Equipamento cadastrado na obra e vinculado à atividade.',
          style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  Future<void> _cadastrarEVincularMaoObra() async {
    final novoUuid = await showCadastrarMaoObraObraDialog(
      context: context,
      obraUuid: widget.obraUuid!,
      obraId: widget.obraId,
    );
    if (!mounted || novoUuid == null || novoUuid.trim().isEmpty) return;

    await _inserirMaoObraPresenteRelatorio(novoUuid);
    await _vincularItemAtividade(tipo: 'mao_obra', obraItemUuid: novoUuid);
    safeSetState(() {
      _atualizarSelecaoDropdown(
        uuid: novoUuid,
        setDropDownValue: (v) => _model.dropDownMaoObraValue = v,
        setSelected: (v) => _model.maoObraSelected = v,
        setController: (c) => _model.dropDownMaoObraValueController = c,
      );
    });
    _reloadMaoObraDropdown();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Mão de obra cadastrada na obra, marcada presente no relatório e vinculada à atividade.',
          style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
        ),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
  }

  Widget _blocosProgressoTarefaOs({
    required BuildContext context,
    required GetDadosAtividadeRow row,
    required GetDetalhesTarefaRow? detalhes,
    required GetTarefasOrdemDetalhesRow? linhaOs,
  }) {
    if (row.isAtividadeAvulsa) {
      return const SizedBox.shrink();
    }
    final controller = _model.textFieldQtdRealizadaTextController;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final raw = controller.text.trim();
        final realizadaParsed =
            double.tryParse(raw.replaceAll(',', '.'));
        final qtdPlObra = _qtdPlanejadaObra(row, detalhes);
        final unidadeObra =
            (row.unidade ?? detalhes?.unidade ?? '').trim();
        final inputValido =
            raw.isNotEmpty && realizadaParsed != null;
        final showObra = qtdPlObra > 0 && inputValido;
        final realizada = realizadaParsed ?? 0;
        double pctObra = 0;
        String hintObra = '';
        if (showObra) {
          pctObra = math.min((realizada / qtdPlObra) * 100, 100);
          pctObra = (pctObra * 10).roundToDouble() / 10;
          if (realizada > qtdPlObra) {
            hintObra =
                '⚠️ Quantidade realizada excede a planejada em ${realizada - qtdPlObra}$unidadeObra';
          } else {
            final falta = qtdPlObra - realizada;
            if (falta > 0) {
              hintObra =
                  '📋 Faltam $falta$unidadeObra para concluir a atividade.';
            } else {
              hintObra =
                  '✅ Concluído! $realizada$unidadeObra realizados';
            }
          }
        }

        final qtdProgOs = _parseQuantidade(linhaOs?.qtdProgramada);
        final showOsBar =
            linhaOs != null && qtdProgOs > 0 && inputValido;
        double pctOs = 0;
        String hintOs = '';
        if (showOsBar) {
          final lo = linhaOs;
          final form = realizadaParsed;
          final acum = _parseQuantidade(lo.qtdRealizada);
          final baseline = _parseQuantidade(row.qtdRealizada);
          final persistiuAtividade = widget.atividadeId != null &&
              widget.atividadeId! > 0;
          final executadoOrdem = persistiuAtividade
              ? acum - baseline + form
              : acum + form;
          pctOs = qtdProgOs > 0
              ? math.min(
                  ((executadoOrdem / qtdProgOs) * 100).roundToDouble(),
                  100,
                )
              : 0;
          final uOs =
              (lo.unidade ?? detalhes?.unidade ?? row.unidade ?? '').trim();
          if (executadoOrdem > qtdProgOs) {
            hintOs =
                '⚠️ Na OS: ${executadoOrdem - qtdProgOs} $uOs acima do planejado';
          } else {
            final falta = qtdProgOs - executadoOrdem;
            if (falta > 0) {
              hintOs = '📋 Na OS: faltam $falta $uOs';
            } else {
              hintOs = '✅ Ordem: meta atingida';
            }
          }
        }

        if (!showObra && !showOsBar) {
          return const SizedBox.shrink();
        }

        final theme = FlutterFlowTheme.of(context);
        Widget miniBar({
          required String titulo,
          required double porcentagem,
          required String textoPorcentagem,
          required Color cor,
          required String hint,
        }) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.labelMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: FontWeight.w600,
                            fontStyle: theme.labelMedium.fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      textoPorcentagem,
                      style: theme.bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          color: cor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (porcentagem / 100).clamp(0.0, 1.0),
                    minHeight: 8,
                    backgroundColor: theme.alternate,
                    color: cor,
                  ),
                ),
                if (hint.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    hint,
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: theme.bodySmall.override(
                      font: GoogleFonts.inter(
                        fontStyle: theme.bodySmall.fontStyle,
                      ),
                      color: theme.secondaryText,
                    ),
                  ),
                ],
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 4.0, bottom: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showObra)
                miniBar(
                  titulo: 'Progresso vs orçamento (obra)',
                  porcentagem: pctObra,
                  textoPorcentagem: '${pctObra.toStringAsFixed(1)}%',
                  cor: _corBarraProgresso(context, pctObra),
                  hint: hintObra,
                ),
              if (showOsBar)
                miniBar(
                  titulo: 'Progresso vs planejado na ordem',
                  porcentagem: pctOs,
                  textoPorcentagem: '${pctOs.round()}%',
                  cor: _corBarraProgresso(context, pctOs),
                  hint: hintOs,
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddAtividadeRelatorioModel());

    _futureDadosPagina = _carregarDadosPagina();
    _futureItensObraInsumo = _loadItensObraInsumo();
    _futureItensObraEquipamento = _loadItensObraEquipamento();
    _futureMaoObraPresente = _loadMaoObraPresenteRelatorio();

    _model.switchOrdemValue = false;

    _model.textFieldDescricaoFocusNode ??= FocusNode();

    _model.textFieldQtdRealizadaFocusNode ??= FocusNode();

    _model.textFieldUnidadeFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DadosPaginaAtividade>(
      future: _futureDadosPagina,
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: Center(
              child: LinearProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
          );
        }
        final bundle = snapshot.data!;
        final addAtividadeRelatorioGetDadosAtividadeRowList =
            bundle.atividadeRows;
        final locaisObraList = bundle.locais;
        final ordensServicoList = bundle.ordensServico;
        final rowAtividadeTipo =
            addAtividadeRelatorioGetDadosAtividadeRowList.firstOrNull;
        final mostrarVinculoOrdemAvulsa =
            rowAtividadeTipo?.isAtividadeAvulsa ?? true;
        final locaisVinculados = locaisObraList
            .where((e) => (e.nome ?? '').trim().isNotEmpty)
            .toList();
        final locaisNomes = locaisVinculados
            .map((e) => (e.nome ?? '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
        const statusOptions = <int>[1, 0, 2];
        final situacaoDb = addAtividadeRelatorioGetDadosAtividadeRowList
            .firstOrNull
            ?.situacao;
        final situacaoInicial = (situacaoDb != null &&
                statusOptions.contains(situacaoDb))
            ? situacaoDb
            : 1;

        if (_model.dropDownStatusValueController == null) {
          _model.dropDownStatusValue ??= situacaoInicial;
          _model.statusSelected ??= situacaoInicial;
          _model.dropDownStatusValueController =
              FormFieldController<int>(_model.dropDownStatusValue);
        }

        if (_model.dropDownLocalValueController == null) {
          final rowAtividade =
              addAtividadeRelatorioGetDadosAtividadeRowList.firstOrNull;
          final rawLocal = rowAtividade?.local?.trim();
          String? initialLocalNome;
          if (rawLocal != null && rawLocal.isNotEmpty) {
            final parsed = int.tryParse(rawLocal);
            if (parsed != null &&
                locaisObraList.any((e) => e.localIdServidor == parsed)) {
              initialLocalNome = locaisObraList
                  .where((e) => e.localIdServidor == parsed)
                  .firstOrNull
                  ?.nome
                  ?.trim();
            } else {
              final byNome = locaisNomes.where((e) => e == rawLocal).firstOrNull;
              initialLocalNome = byNome;
            }
          }
          _model.dropDownLocalValue = initialLocalNome;
          _model.dropDownLocalValueController =
              FormFieldController<String>(initialLocalNome);
        }

        if (mostrarVinculoOrdemAvulsa &&
            _model.dropDownOrdemUuidValueController == null) {
          final rowOrdem =
              addAtividadeRelatorioGetDadosAtividadeRowList.firstOrNull;
          final savedOrdemUuid = rowOrdem?.ordemUuid?.trim();
          final hasSavedOrdem = savedOrdemUuid != null &&
              savedOrdemUuid.isNotEmpty &&
              ordensServicoList.any((o) => o.uuid == savedOrdemUuid);
          _model.switchOrdemValue = hasSavedOrdem;
          _model.dropDownOrdemUuidValue =
              hasSavedOrdem ? savedOrdemUuid : null;
          _model.dropDownOrdemUuidValueController =
              FormFieldController<String>(_model.dropDownOrdemUuidValue);
        }

        Widget localSelectorWidget() {
          if (locaisVinculados.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Nenhum local vinculado a esta obra. '
                'Vincule locais na obra para selecionar aqui.',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).error,
                      letterSpacing: 0.0,
                    ),
              ),
            );
          }
          return FlutterFlowDropDown<String>(
            controller: _model.dropDownLocalValueController!,
            options: locaisNomes,
            optionLabels: locaisNomes,
            onChanged: (val) async {
              safeSetState(() => _model.dropDownLocalValue = val);
            },
            width: double.infinity,
            height: 46.0,
            textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  fontStyle:
                      FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
            hintText: 'Selecione o local',
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            fillColor: FlutterFlowTheme.of(context).primaryBackground,
            elevation: 0.0,
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderWidth: 1.0,
            borderRadius: 8.0,
            margin: EdgeInsetsDirectional.zero,
            hidesUnderline: true,
            isSearchable: true,
            isMultiSelect: false,
            labelText: 'Local *',
            labelTextStyle: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight:
                        FlutterFlowTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).labelMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).labelMedium.fontStyle,
                ),
          );
        }

        Widget ordemSelectorWidget() {
          if (!_model.switchOrdemValue!) {
            return const SizedBox.shrink();
          }
          if (ordensServicoList.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 0.0),
              child: Text(
                'Nenhuma ordem de serviço encontrada para esta obra no app. Sincronize as ordens ou cadastre na web.',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).warning,
                      letterSpacing: 0.0,
                    ),
              ),
            );
          }
          return FlutterFlowDropDown<String>(
            controller: _model.dropDownOrdemUuidValueController ??=
                FormFieldController<String>(_model.dropDownOrdemUuidValue),
            options: ordensServicoList.map((o) => o.uuid).toList(),
            optionLabels: ordensServicoList.map((o) {
              final nome = (o.nome ?? '').trim();
              return nome.isNotEmpty ? '${o.codigo} — $nome' : o.codigo;
            }).toList(),
            onChanged: (val) async {
              safeSetState(() => _model.dropDownOrdemUuidValue = val);
            },
            width: double.infinity,
            height: 46.0,
            textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  fontStyle:
                      FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
            hintText: 'Referência no RDO',
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            fillColor: FlutterFlowTheme.of(context).primaryBackground,
            elevation: 0.0,
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderWidth: 1.0,
            borderRadius: 8.0,
            margin: EdgeInsetsDirectional.zero,
            hidesUnderline: true,
            isSearchable: true,
            isMultiSelect: false,
            labelText: 'Ordem de serviço',
            labelTextStyle: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight:
                        FlutterFlowTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).labelMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).labelMedium.fontStyle,
                ),
          );
        }

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            appBar: AppBar(
              backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
              automaticallyImplyLeading: false,
              leading: FlutterFlowIconButton(
                borderRadius: 20.0,
                buttonSize: 40.0,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 24.0,
                ),
                onPressed: () async {
                  context.pushNamed(
                    ObraAddRelatorioWidget.routeName,
                    queryParameters: {
                      'id': serializeParam(
                        widget!.relatorioId,
                        ParamType.int,
                      ),
                      'uuid': serializeParam(
                        widget!.relatorioUuid,
                        ParamType.String,
                      ),
                    }.withoutNulls,
                  );
                },
              ),
              title: Text(
                'Gerenciar Atividade',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                      fontSize: 20.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
              ),
              actions: [
                FlutterFlowIconButton(
                  borderRadius: 20.0,
                  buttonSize: 40.0,
                  icon: Icon(
                    Icons.close_rounded,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                  onPressed: () async {
                    context.pushNamed(
                      ObraAddRelatorioWidget.routeName,
                      queryParameters: {
                        'id': serializeParam(
                          widget!.relatorioId,
                          ParamType.int,
                        ),
                        'uuid': serializeParam(
                          widget!.relatorioUuid,
                          ParamType.String,
                        ),
                      }.withoutNulls,
                    );
                  },
                ),
              ],
              centerTitle: true,
              elevation: 0.0,
            ),
            body: SafeArea(
              top: true,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dados da Atividade',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                              mostrarVinculoOrdemAvulsa
                                  ? Container(
                                width: MediaQuery.sizeOf(context).width * 1.0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(0.0),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Switch.adaptive(
                                          value: _model.switchOrdemValue!,
                                          onChanged: (newValue) async {
                                            safeSetState(() {
                                              _model.switchOrdemValue =
                                                  newValue!;
                                              if (newValue == false) {
                                                _model.dropDownOrdemUuidValue =
                                                    null;
                                                _model
                                                    .dropDownOrdemUuidValueController
                                                    ?.value = null;
                                              }
                                            });
                                          },
                                          activeColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          activeTrackColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          inactiveTrackColor:
                                              FlutterFlowTheme.of(context)
                                                  .alternate,
                                          inactiveThumbColor:
                                              FlutterFlowTheme.of(context)
                                                  .secondaryBackground,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Vincular ordem de serviço',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  fontSize: 18.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final narrow =
                                            constraints.maxWidth < 600;
                                        final localW = localSelectorWidget();
                                        if (!_model.switchOrdemValue!) {
                                          return localW;
                                        }
                                        final ordemW = ordemSelectorWidget();
                                        if (narrow) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              localW,
                                              SizedBox(height: 8.0),
                                              ordemW,
                                            ],
                                          );
                                        }
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: localW),
                                            SizedBox(width: 8.0),
                                            Expanded(child: ordemW),
                                          ],
                                        );
                                      },
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                                  )
                                  : localSelectorWidget(),
                              TextFormField(
                                controller:
                                    _model.textFieldDescricaoTextController ??=
                                        TextEditingController(
                                  text:
                                      addAtividadeRelatorioGetDadosAtividadeRowList
                                          .firstOrNull?.descricao,
                                ),
                                focusNode: _model.textFieldDescricaoFocusNode,
                                autofocus: false,
                                textInputAction: TextInputAction.next,
                                obscureText: false,
                                decoration: InputDecoration(
                                  isDense: true,
                                  labelText: 'Descrição *',
                                  labelStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                  hintText: 'Descreva a atividade realizada',
                                  hintStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  contentPadding:
                                      EdgeInsetsDirectional.fromSTEB(
                                          12.0, 16.0, 12.0, 16.0),
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                maxLines: 3,
                                minLines: 2,
                                cursorColor:
                                    FlutterFlowTheme.of(context).primary,
                                validator: _model
                                    .textFieldDescricaoTextControllerValidator
                                    .asValidator(context),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _model
                                              .textFieldQtdRealizadaTextController ??=
                                          TextEditingController(
                                        text:
                                            addAtividadeRelatorioGetDadosAtividadeRowList
                                                .firstOrNull?.qtdRealizada
                                                ?.toString(),
                                      ),
                                      focusNode:
                                          _model.textFieldQtdRealizadaFocusNode,
                                      autofocus: false,
                                      textInputAction: TextInputAction.next,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Quantidade *',
                                        labelStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                        hintText: '0',
                                        hintStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        filled: true,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        contentPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                12.0, 16.0, 12.0, 16.0),
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      keyboardType: TextInputType.number,
                                      cursorColor:
                                          FlutterFlowTheme.of(context).primary,
                                      validator: _model
                                          .textFieldQtdRealizadaTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _model
                                              .textFieldUnidadeTextController ??=
                                          TextEditingController(
                                        text:
                                            addAtividadeRelatorioGetDadosAtividadeRowList
                                                .firstOrNull?.unidade,
                                      ),
                                      focusNode:
                                          _model.textFieldUnidadeFocusNode,
                                      autofocus: false,
                                      textInputAction: TextInputAction.next,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        labelText: 'Unidade *',
                                        labelStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                        hintText: 'm², m³, kg...',
                                        hintStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        filled: true,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        contentPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                12.0, 16.0, 12.0, 16.0),
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      cursorColor:
                                          FlutterFlowTheme.of(context).primary,
                                      validator: _model
                                          .textFieldUnidadeTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ),
                                ].divide(SizedBox(width: 12.0)),
                              ),
                              if (addAtividadeRelatorioGetDadosAtividadeRowList
                                      .firstOrNull !=
                                  null)
                                _blocosProgressoTarefaOs(
                                  context: context,
                                  row: addAtividadeRelatorioGetDadosAtividadeRowList
                                      .firstOrNull!,
                                  detalhes: bundle.detalhesTarefa,
                                  linhaOs: bundle.linhaOrdemServico,
                                ),
                              FlutterFlowDropDown<int>(
                                controller:
                                    _model.dropDownStatusValueController!,
                                options: List<int>.from([1, 0, 2]),
                                optionLabels: [
                                  'Em andamento',
                                  'Paralizada',
                                  'Concluída'
                                ],
                                onChanged: (val) async {
                                  safeSetState(
                                      () => _model.dropDownStatusValue = val);
                                  _model.statusSelected =
                                      _model.dropDownStatusValue;
                                  safeSetState(() {});
                                },
                                width: double.infinity,
                                height: 46.0,
                                textStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                hintText: 'Selecione o status',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                                fillColor: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                elevation: 0.0,
                                borderColor:
                                    FlutterFlowTheme.of(context).alternate,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 12.0, 0.0),
                                hidesUnderline: true,
                                isSearchable: false,
                                isMultiSelect: false,
                                labelText: 'Status',
                                labelTextStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recursos Utilizados',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Insumos',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                        ),
                                  ),
                                  FutureBuilder<List<CarregaItensObraRow>>(
                                    key: ValueKey(
                                        'insumo_obra_$_insumosObraReloadToken'),
                                    future: _futureItensObraInsumo,
                                    builder: (context, snapshot) {
                                      // Customize what your widget looks like when it's loading.
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: LinearProgressIndicator(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        );
                                      }
                                      final dropDownInsumoCarregaItensObraRowList =
                                          snapshot.data!;

                                      return FlutterFlowDropDown<String>(
                                        controller: _model
                                                .dropDownInsumoValueController ??=
                                            FormFieldController<String>(
                                          _model.dropDownInsumoValue ??= '0',
                                        ),
                                        options: List<String>.from(
                                            dropDownInsumoCarregaItensObraRowList
                                                .map((e) => e.uuid)
                                                .toList()),
                                        optionLabels:
                                            dropDownInsumoCarregaItensObraRowList
                                                .map((e) => e.descricao)
                                                .toList(),
                                        onChanged: (val) async {
                                          final selected = val?.trim();
                                          if (selected == null ||
                                              selected.isEmpty ||
                                              selected == '0') {
                                            return;
                                          }
                                          if (await _itemJaVinculadoNaAtividade(
                                            tipo: 'insumo',
                                            obraItemUuid: selected,
                                          )) {
                                            safeSetState(() {
                                              _model.dropDownInsumoValue =
                                                  selected;
                                              _model.insumoSelected = selected;
                                            });
                                            return;
                                          }
                                          safeSetState(() {
                                            _model.dropDownInsumoValue =
                                                selected;
                                            _model.insumoSelected = selected;
                                          });
                                          _model.uuidResult =
                                              await actions.generateUuid();
                                          await SQLiteManager.instance
                                              .setItemAtividade(
                                            relatorioAtividadeId:
                                                widget!.atividadeId!,
                                            tipo: 'insumo',
                                            obraItemId: 0,
                                            relatorioAtividadeUuid:
                                                widget!.atividadeUuid,
                                            obraItemUuid: selected,
                                            uuid: _model.uuidResult,
                                          );
                                          _atualizarListasItensAtividade();
                                          safeSetState(() {});
                                        },
                                        width: double.infinity,
                                        height: 46.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText: 'Selecione um insumo',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        elevation: 0.0,
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderWidth: 1.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        isSearchable: false,
                                        isMultiSelect: false,
                                      );
                                    },
                                  ),
                                  BotaoCadastroObraAtalhoWidget(
                                    titulo: 'Novo insumo',
                                    subtitulo:
                                        'Cadastra na obra, registra no relatório e vincula à atividade',
                                    icon: Icons.inventory_2_outlined,
                                    onPressed: _cadastrarEVincularInsumo,
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      wrapWithModel(
                                        model: _model
                                            .insumosAtividadeRelatorioModel,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: InsumosAtividadeRelatorioWidget(
                                          relatorioUuid: widget!.relatorioUuid!,
                                          atividadeUuid: widget!.atividadeUuid!,
                                          listRefreshToken:
                                              _listasItensAtividadeRefresh,
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 12.0)),
                              ),
                              Divider(
                                thickness: 1.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Equipamentos',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                        ),
                                  ),
                                  FutureBuilder<List<CarregaItensObraRow>>(
                                    key: ValueKey(
                                        'equip_obra_$_equipamentosObraReloadToken'),
                                    future: _futureItensObraEquipamento,
                                    builder: (context, snapshot) {
                                      // Customize what your widget looks like when it's loading.
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: LinearProgressIndicator(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        );
                                      }
                                      final dropDownEquipamentosCarregaItensObraRowList =
                                          snapshot.data!;

                                      return FlutterFlowDropDown<String>(
                                        controller: _model
                                                .dropDownEquipamentosValueController ??=
                                            FormFieldController<String>(
                                          _model.dropDownEquipamentosValue ??=
                                              '0',
                                        ),
                                        options: List<String>.from(
                                            dropDownEquipamentosCarregaItensObraRowList
                                                .map((e) => e.uuid)
                                                .toList()),
                                        optionLabels:
                                            dropDownEquipamentosCarregaItensObraRowList
                                                .map((e) => e.descricao)
                                                .toList(),
                                        onChanged: (val) async {
                                          final selected = val?.trim();
                                          if (selected == null ||
                                              selected.isEmpty ||
                                              selected == '0') {
                                            return;
                                          }
                                          if (await _itemJaVinculadoNaAtividade(
                                            tipo: 'equipamento',
                                            obraItemUuid: selected,
                                          )) {
                                            safeSetState(() {
                                              _model.dropDownEquipamentosValue =
                                                  selected;
                                              _model.equipamentoSelected =
                                                  selected;
                                            });
                                            return;
                                          }
                                          safeSetState(() {
                                            _model.dropDownEquipamentosValue =
                                                selected;
                                            _model.equipamentoSelected =
                                                selected;
                                          });
                                          _model.uuidResultEquipamento =
                                              await actions.generateUuid();
                                          await SQLiteManager.instance
                                              .setItemAtividade(
                                            relatorioAtividadeId:
                                                widget!.atividadeId!,
                                            tipo: 'equipamento',
                                            obraItemId: 0,
                                            relatorioAtividadeUuid:
                                                widget!.atividadeUuid,
                                            obraItemUuid: selected,
                                            uuid: _model.uuidResultEquipamento,
                                          );
                                          _atualizarListasItensAtividade();
                                          safeSetState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Item cadastrado!',
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                ),
                                              ),
                                              duration:
                                                  Duration(milliseconds: 4000),
                                              backgroundColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                            ),
                                          );
                                        },
                                        width: double.infinity,
                                        height: 56.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText: 'Selecione um equipamento',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        elevation: 0.0,
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderWidth: 1.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        isSearchable: false,
                                        isMultiSelect: false,
                                      );
                                    },
                                  ),
                                  BotaoCadastroObraAtalhoWidget(
                                    titulo: 'Novo equipamento',
                                    subtitulo:
                                        'Cadastra na obra e vincula à atividade',
                                    icon: Icons.construction_outlined,
                                    onPressed: _cadastrarEVincularEquipamento,
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      wrapWithModel(
                                        model: _model
                                            .equipamentosAtividadeRelatorioModel,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child:
                                            EquipamentosAtividadeRelatorioWidget(
                                          relatorioUuid: widget!.relatorioUuid!,
                                          atividadeUuid: widget!.atividadeUuid!,
                                          listRefreshToken:
                                              _listasItensAtividadeRefresh,
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 12.0)),
                              ),
                              Divider(
                                thickness: 1.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mão de Obra',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                        ),
                                  ),
                                  FutureBuilder<List<GetMaoObraRelatorioRow>>(
                                    key: ValueKey(
                                        'mao_obra_rel_$_maoObraRelatorioReloadToken'),
                                    future: _futureMaoObraPresente,
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: LinearProgressIndicator(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        );
                                      }
                                      final maoObraPresenteNoRelatorio =
                                          snapshot.data!;
                                      final itensDropdown =
                                          maoObraPresenteNoRelatorio
                                              .where(
                                                (e) => (e.obraItemUuid ?? '')
                                                    .trim()
                                                    .isNotEmpty,
                                              )
                                              .toList();

                                      if (itensDropdown.isEmpty) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 8.0),
                                              child: Text(
                                                'Nenhuma mão de obra marcada como presente neste relatório. '
                                                'Registre presença no relatório para vincular aqui.',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodySmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodySmall
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .error,
                                                    ),
                                              ),
                                            ),
                                            BotaoCadastroObraAtalhoWidget(
                                              titulo: 'Nova mão de obra',
                                              subtitulo:
                                                  'Cadastra na obra, marca presença no relatório e vincula à atividade',
                                              icon: Icons
                                                  .person_add_alt_1_rounded,
                                              onPressed:
                                                  _cadastrarEVincularMaoObra,
                                            ),
                                          ],
                                        );
                                      }

                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          FlutterFlowDropDown<String>(
                                        controller: _model
                                                .dropDownMaoObraValueController ??=
                                            FormFieldController<String>(
                                          _model.dropDownMaoObraValue,
                                        ),
                                        options: itensDropdown
                                            .map((e) =>
                                                (e.obraItemUuid ?? '').trim())
                                            .toList(),
                                        optionLabels: itensDropdown
                                            .map(_labelMaoObraRelatorioPresente)
                                            .toList(),
                                        onChanged: (val) async {
                                          final selected = val?.trim();
                                          if (selected == null ||
                                              selected.isEmpty ||
                                              selected == '0') {
                                            return;
                                          }
                                          if (await _itemJaVinculadoNaAtividade(
                                            tipo: 'mao_obra',
                                            obraItemUuid: selected,
                                          )) {
                                            safeSetState(() {
                                              _model.dropDownMaoObraValue =
                                                  selected;
                                              _model.maoObraSelected =
                                                  selected;
                                            });
                                            return;
                                          }
                                          safeSetState(() {
                                            _model.dropDownMaoObraValue =
                                                selected;
                                            _model.maoObraSelected = selected;
                                          });
                                          _model.uuidResultMo =
                                              await actions.generateUuid();
                                          await SQLiteManager.instance
                                              .setItemAtividade(
                                            relatorioAtividadeId:
                                                widget!.atividadeId!,
                                            tipo: 'mao_obra',
                                            obraItemId: 0,
                                            relatorioAtividadeUuid:
                                                widget!.atividadeUuid,
                                            uuid: _model.uuidResultMo,
                                            obraItemUuid: selected,
                                          );
                                          _atualizarListasItensAtividade();
                                          safeSetState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Item cadastrado!',
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                ),
                                              ),
                                              duration:
                                                  Duration(milliseconds: 4000),
                                              backgroundColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                            ),
                                          );
                                        },
                                        width: double.infinity,
                                        height: 56.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText:
                                            'Selecione mão de obra (presente no relatório)',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        elevation: 0.0,
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderWidth: 1.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        isSearchable: true,
                                        isMultiSelect: false,
                                      ),
                                          BotaoCadastroObraAtalhoWidget(
                                            titulo: 'Nova mão de obra',
                                            subtitulo:
                                                'Cadastra na obra, marca presença no relatório e vincula à atividade',
                                            icon: Icons.person_add_alt_1_rounded,
                                            onPressed:
                                                _cadastrarEVincularMaoObra,
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      wrapWithModel(
                                        model: _model
                                            .maoObraAtividadeRelatorioModel,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: MaoObraAtividadeRelatorioWidget(
                                          relatorioUuid: widget!.relatorioUuid!,
                                          atividadeUuid: widget!.atividadeUuid!,
                                          listRefreshToken:
                                              _listasItensAtividadeRefresh,
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 12.0)),
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.fotosAtividadeModel,
                        updateCallback: () => safeSetState(() {}),
                        child: FotosAtividadeWidget(
                          parameter1: widget!.atividadeId!,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FFButtonWidget(
                            onPressed: () async {
                              context.pushNamed(
                                ObraAddRelatorioWidget.routeName,
                                queryParameters: {
                                  'id': serializeParam(
                                    widget!.relatorioId,
                                    ParamType.int,
                                  ),
                                  'uuid': serializeParam(
                                    widget!.relatorioUuid,
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                              );
                            },
                            text: 'Cancelar',
                            options: FFButtonOptions(
                              width: 120.0,
                              height: 48.0,
                              padding: EdgeInsets.all(8.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          FFButtonWidget(
                            onPressed: () async {
                              final descricao = _model
                                  .textFieldDescricaoTextController.text
                                  .trim();
                              final unidade = _model
                                  .textFieldUnidadeTextController.text
                                  .trim();
                              final qtdTxt = _model
                                  .textFieldQtdRealizadaTextController.text
                                  .trim();
                              final qtdParsed =
                                  qtdTxt.isEmpty ? null : int.tryParse(qtdTxt);
                              if (_model.dropDownLocalValue == null ||
                                  descricao.isEmpty ||
                                  unidade.isEmpty ||
                                  qtdParsed == null || qtdParsed < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _model.dropDownLocalValue == null
                                          ? 'Selecione o local da obra.'
                                          : 'Preencha descrição, quantidade e unidade da atividade.',
                                      style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .alternate,
                                      ),
                                    ),
                                    duration: Duration(milliseconds: 4000),
                                    backgroundColor:
                                        FlutterFlowTheme.of(context).error,
                                  ),
                                );
                                return;
                              }
                              if (mostrarVinculoOrdemAvulsa) {
                                if (_model.switchOrdemValue == true &&
                                    ordensServicoList.isNotEmpty &&
                                    (_model.dropDownOrdemUuidValue == null ||
                                        _model.dropDownOrdemUuidValue!
                                            .trim()
                                            .isEmpty)) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Selecione a ordem de serviço ou desligue a opção.',
                                        style: TextStyle(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                        ),
                                      ),
                                      backgroundColor:
                                          FlutterFlowTheme.of(context).error,
                                    ),
                                  );
                                  return;
                                }
                              }

                              int? ordemIdSave;
                              String? ordemUuidSave;
                              if (mostrarVinculoOrdemAvulsa &&
                                  _model.switchOrdemValue == true &&
                                  (_model.dropDownOrdemUuidValue != null &&
                                      _model.dropDownOrdemUuidValue!
                                          .trim()
                                          .isNotEmpty)) {
                                ordemUuidSave =
                                    _model.dropDownOrdemUuidValue!.trim();
                                ordemIdSave = ordensServicoList
                                    .where((o) => o.uuid == ordemUuidSave)
                                    .firstOrNull
                                    ?.id;
                              }

                              await SQLiteManager.instance.updateAtividade(
                                uuid: widget!.atividadeUuid!,
                                local: _model.dropDownLocalValue!.trim(),
                                descricao: descricao,
                                qtdRealizada: qtdParsed,
                                unidade: unidade,
                                situacao: _model.statusSelected ?? 1,
                                ordemId: ordemIdSave,
                                ordemUuid: ordemUuidSave,
                                updateOrdemVinculo: mostrarVinculoOrdemAvulsa,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Atividade atualizada!',
                                    style: TextStyle(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                    ),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                  backgroundColor:
                                      FlutterFlowTheme.of(context).secondary,
                                ),
                              );

                              context.pushNamed(
                                ObraAddRelatorioWidget.routeName,
                                queryParameters: {
                                  'id': serializeParam(
                                    widget!.relatorioId,
                                    ParamType.int,
                                  ),
                                  'uuid': serializeParam(
                                    widget!.relatorioUuid,
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  '__transition_info__': TransitionInfo(
                                    hasTransition: true,
                                    transitionType:
                                        PageTransitionType.topToBottom,
                                  ),
                                },
                              );
                            },
                            text: 'Salvar',
                            options: FFButtonOptions(
                              width: 120.0,
                              height: 48.0,
                              padding: EdgeInsets.all(8.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).info,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderSide: BorderSide(
                                color: Colors.transparent,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ].divide(SizedBox(width: 12.0)),
                      ),
                    ]
                        .divide(SizedBox(height: 24.0))
                        .addToStart(SizedBox(height: 16.0))
                        .addToEnd(SizedBox(height: 32.0)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

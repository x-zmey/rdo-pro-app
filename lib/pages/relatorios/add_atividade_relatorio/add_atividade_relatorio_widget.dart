import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/equipamentos_atividade_relatorio/equipamentos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/fotos_atividade/fotos_atividade_widget.dart';
import '/componentes/atividades_relatorios/insumos_atividade_relatorio/insumos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/mao_obra_atividade_relatorio/mao_obra_atividade_relatorio_widget.dart';
import '/componentes/dialogs/cadastrar_equipamento_obra/cadastrar_equipamento_obra_dialog.dart';
import '/componentes/dialogs/cadastrar_insumo_obra/cadastrar_insumo_obra_dialog.dart';
import '/componentes/dialogs/cadastrar_mao_obra_obra/cadastrar_mao_obra_obra_dialog.dart';
import '/componentes/relatorios/includes/botao_cadastro_obra_atalho/botao_cadastro_obra_atalho_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Aceita vírgula e ponto (o teclado decimal do Android varia conforme o locale)
/// e limita a 2 casas, que é a precisão gravada no servidor.
final List<TextInputFormatter> _formattersQuantidade = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
];

String _qtdRealizadaTexto(num? q) =>
    q == null ? '' : formatQuantidadeRelatorio(q);

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

/// Uuid vazio/duplicado derruba o DropdownButton2 (bloco cinza em release).
({List<String> options, List<String> labels}) _dropdownOpcoesUnicas(
  Iterable<String?> uuids,
  Iterable<String?> labels,
) {
  final uList = uuids.toList();
  final lList = labels.toList();
  final seen = <String>{};
  final options = <String>[];
  final optionLabels = <String>[];
  for (var i = 0; i < uList.length; i++) {
    final u = (uList[i] ?? '').trim();
    if (u.isEmpty || u == '0') continue;
    if (!seen.add(u)) continue;
    final label = i < lList.length ? (lList[i] ?? '').trim() : '';
    options.add(u);
    optionLabels.add(label.isEmpty ? u : label);
  }
  return (options: options, labels: optionLabels);
}

Widget _snapshotListaErroOuLoading(
  BuildContext context,
  AsyncSnapshot snapshot, {
  required Color loadingColor,
}) {
  if (snapshot.hasError) {
    return Text(
      'Não foi possível carregar esta lista. Tente sincronizar.',
      style: GoogleFonts.inter(
        fontSize: 12,
        color: FlutterFlowTheme.of(context).error,
      ),
    );
  }
  return LinearProgressIndicator(color: loadingColor);
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
    this.novaAtividade,
  });

  final int? relatorioId;
  final int? obraId;
  final int? atividadeId;
  final String? atividadeUuid;
  final String? relatorioUuid;
  final String? obraUuid;

  /// Atividade recém-criada pelo botão «+» do RDO: se o usuário sair sem
  /// salvar, o rascunho é descartado.
  final bool? novaAtividade;

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

  bool _salvouAtividade = false;

  late final Future<_DadosPaginaAtividade> _futureDadosPagina;

  Future<_DadosPaginaAtividade> _carregarDadosPagina() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isNotEmpty) {
      try {
        await actions.refreshOrdensPorObra(obraUuid: obraUuid);
      } catch (_) {}
    }
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

  Future<List<CarregaItensObraRow>> _loadItensObraInsumo() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) return <CarregaItensObraRow>[];
    try {
      await actions.refreshObraItensPorTipo(
        obraUuid: obraUuid,
        tipo: 'insumo',
      );
    } catch (_) {}
    return SQLiteManager.instance.carregaItensObra(
      tipo: 'insumo',
      obraId: widget.obraId,
      obraUuid: obraUuid,
    );
  }

  Future<List<CarregaItensObraRow>> _loadItensObraEquipamento() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) return <CarregaItensObraRow>[];
    try {
      await actions.refreshObraItensPorTipo(
        obraUuid: obraUuid,
        tipo: 'equipamento',
      );
    } catch (_) {}
    return SQLiteManager.instance.carregaItensObra(
      tipo: 'equipamento',
      obraId: widget.obraId,
      obraUuid: obraUuid,
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
    await _vincularVariosItensAtividade(
      tipo: tipo,
      obraItemUuids: [obraItemUuid],
      mostrarFeedback: false,
    );
  }

  /// Vincula vários itens de uma vez (multi-select). Já vinculados são ignorados.
  Future<int> _vincularVariosItensAtividade({
    required String tipo,
    required Iterable<String> obraItemUuids,
    bool mostrarFeedback = true,
  }) async {
    final candidatos = obraItemUuids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '0')
        .toSet()
        .toList();
    if (candidatos.isEmpty) return 0;

    var vinculados = 0;
    for (final obraItemUuid in candidatos) {
      if (await _itemJaVinculadoNaAtividade(
        tipo: tipo,
        obraItemUuid: obraItemUuid,
      )) {
        continue;
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
      vinculados++;
    }
    if (vinculados > 0) {
      _atualizarListasItensAtividade();
      if (mostrarFeedback && mounted) {
        final label = vinculados == 1
            ? '1 item vinculado à atividade'
            : '$vinculados itens vinculados à atividade';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              label,
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryBackground,
              ),
            ),
            duration: const Duration(milliseconds: 3000),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
      }
    }
    return vinculados;
  }

  void _atualizarSelecaoDropdown({
    required String uuid,
    required void Function(List<String>?) setDropDownValue,
    required void Function(String?) setSelected,
    required void Function(FormFieldController<List<String>?>?) setController,
    required FormFieldController<List<String>?>? currentController,
  }) {
    final atual = List<String>.from(currentController?.value ?? const []);
    if (!atual.contains(uuid)) {
      atual.add(uuid);
    }
    setDropDownValue(atual);
    setSelected(uuid);
    setController(FormFieldController<List<String>?>(atual));
  }

  Future<void> _onMultiSelectItensAtividade({
    required String tipo,
    required List<String>? selecionados,
    required void Function(List<String>?) setDropDownValue,
  }) async {
    final lista = (selecionados ?? [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '0')
        .toList();
    setDropDownValue(lista);
    if (lista.isEmpty) return;
    // Sem snackbar a cada checkbox: a lista abaixo já reflete o vínculo.
    await _vincularVariosItensAtividade(
      tipo: tipo,
      obraItemUuids: lista,
      mostrarFeedback: false,
    );
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
        currentController: _model.dropDownInsumoValueController,
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
        currentController: _model.dropDownEquipamentosValueController,
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
        currentController: _model.dropDownMaoObraValueController,
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
    _model.textFieldQtdRealizadaFocusNode!
        .addListener(_onQtdRealizadaFocusChange);

    _model.textFieldUnidadeFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.textFieldQtdRealizadaFocusNode
        ?.removeListener(_onQtdRealizadaFocusChange);
    _model.dispose();

    super.dispose();
  }

  num? _qtdRealizadaDoFormulario() {
    final txt =
        _model.textFieldQtdRealizadaTextController?.text.trim() ?? '';
    if (txt.isEmpty) return null;
    return tryParseQuantidadeRelatorio(txt);
  }

  void _onQtdRealizadaFocusChange() {
    final node = _model.textFieldQtdRealizadaFocusNode;
    if (node != null && !node.hasFocus) {
      _persistirQtdRealizadaParcial();
    }
  }

  /// Grava a quantidade do topo no SQLite assim que o usuário sai do campo,
  /// para a validação de produtividade (equip./mão de obra) ler o teto correto.
  Future<void> _persistirQtdRealizadaParcial() async {
    final uuid = widget.atividadeUuid;
    if (uuid == null || uuid.isEmpty) return;
    final qtd = _qtdRealizadaDoFormulario();
    if (qtd == null || qtd < 0) return;

    final rows = await SQLiteManager.instance.getDadosAtividade(uuid: uuid);
    final row = rows.firstOrNull;
    if (row == null) return;

    final localForm = (_model.dropDownLocalValue ?? '').trim();
    final descForm =
        (_model.textFieldDescricaoTextController?.text ?? '').trim();
    final unForm =
        (_model.textFieldUnidadeTextController?.text ?? '').trim();

    await SQLiteManager.instance.updateAtividade(
      uuid: uuid,
      local: localForm.isNotEmpty ? localForm : (row.local ?? ''),
      descricao: descForm.isNotEmpty ? descForm : (row.descricao ?? ''),
      qtdRealizada: qtd,
      unidade: unForm.isNotEmpty ? unForm : (row.unidade ?? ''),
      situacao: _model.statusSelected ?? row.situacao ?? 1,
    );
    if (!mounted) return;
    safeSetState(() => _listasItensAtividadeRefresh++);
  }

  /// Rótulo curto acima do campo, no padrão das tabelas do RDO.
  Widget _rotuloCampo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(texto.toUpperCase(), style: rdoColumnLabelStyle(context)),
      );

  void _irParaRelatorio() {
    context.pushNamed(
      ObraAddRelatorioWidget.routeName,
      queryParameters: {
        'id': serializeParam(widget.relatorioId, ParamType.int),
        'uuid': serializeParam(widget.relatorioUuid, ParamType.String),
      }.withoutNulls,
    );
  }

  Future<bool> _rascunhoTemConteudo() async {
    if (_model.textFieldDescricaoTextController.text.trim().isNotEmpty ||
        _model.textFieldUnidadeTextController.text.trim().isNotEmpty ||
        _model.textFieldQtdRealizadaTextController.text.trim().isNotEmpty ||
        (_model.dropDownLocalValue ?? '').trim().isNotEmpty) {
      return true;
    }

    for (final tipo in const ['insumo', 'equipamento', 'mao_obra']) {
      final itens = await SQLiteManager.instance.getItensAtividade(
        atividadeUuid: widget.atividadeUuid!,
        tipo: tipo,
      );
      if (itens.isNotEmpty) return true;
    }

    final fotos = await SQLiteManager.instance.carregaFotosAtividade(
      atividadeId: widget.atividadeId,
    );
    return fotos.isNotEmpty;
  }

  Future<bool> _confirmarDescarte() async {
    final theme = FlutterFlowTheme.of(context);
    final resposta = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.secondaryBackground,
        title: Text(
          'Descartar atividade?',
          style: GoogleFonts.interTight(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        content: Text(
          'Esta atividade ainda não foi salva. Se sair agora, ela e os itens '
          'vinculados a ela serão descartados.',
          style: GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Continuar editando',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: theme.error),
            child: Text(
              'Descartar',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return resposta ?? false;
  }

  /// A atividade é criada no banco antes desta tela abrir, então sair sem
  /// salvar precisa apagar o rascunho para ele não aparecer vazio no RDO.
  Future<void> _sairSemSalvar() async {
    final rascunho = widget.novaAtividade == true && !_salvouAtividade;
    if (rascunho) {
      if (await _rascunhoTemConteudo()) {
        if (!mounted) return;
        if (!await _confirmarDescarte()) return;
      }
      await SQLiteManager.instance.deleteAtividadeRelatorio(
        id: widget.atividadeId,
      );
    }
    if (!mounted) return;
    _irParaRelatorio();
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

        void voltarParaRelatorio() => _sairSemSalvar();

        final theme = FlutterFlowTheme.of(context);
        final descricaoAtividade = (rowAtividadeTipo?.descricao ?? '').trim();

        Widget avisoCampo(String texto, Color cor) => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                texto,
                style: GoogleFonts.inter(fontSize: 11.5, color: cor),
              ),
            );

        Widget localSelectorWidget() {
          if (locaisVinculados.isEmpty) {
            return avisoCampo(
              'Nenhum local vinculado a esta obra. '
              'Vincule locais na obra para selecionar aqui.',
              theme.error,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rotuloCampo('Local *'),
              FlutterFlowDropDown<String>(
                controller: _model.dropDownLocalValueController!,
                options: locaisNomes,
                optionLabels: locaisNomes,
                onChanged: (val) async {
                  safeSetState(() => _model.dropDownLocalValue = val);
                },
                width: double.infinity,
                height: 38.0,
                textStyle: rdoCompactFieldTextStyle(context),
                hintText: 'Selecione o local',
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.secondaryText,
                  size: 18.0,
                ),
                fillColor: theme.secondaryBackground,
                elevation: 0.0,
                borderColor: theme.alternate,
                borderWidth: 1.0,
                borderRadius: 8.0,
                margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                hidesUnderline: true,
                isSearchable: true,
                searchHintText: 'Buscar local...',
                isMultiSelect: false,
              ),
            ],
          );
        }

        Widget ordemSelectorWidget() {
          if (!_model.switchOrdemValue!) {
            return const SizedBox.shrink();
          }
          if (ordensServicoList.isEmpty) {
            return avisoCampo(
              'Nenhuma ordem de serviço encontrada para esta obra no app. '
              'Sincronize as ordens ou cadastre na web.',
              theme.warning,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rotuloCampo('Ordem de serviço'),
              FlutterFlowDropDown<String>(
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
                height: 38.0,
                textStyle: rdoCompactFieldTextStyle(context),
                hintText: 'Referência no RDO',
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.secondaryText,
                  size: 18.0,
                ),
                fillColor: theme.secondaryBackground,
                elevation: 0.0,
                borderColor: theme.alternate,
                borderWidth: 1.0,
                borderRadius: 8.0,
                margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                hidesUnderline: true,
                isSearchable: true,
                searchHintText: 'Buscar ordem...',
                isMultiSelect: false,
              ),
            ],
          );
        }

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) _sairSemSalvar();
            },
            child: Scaffold(
              key: scaffoldKey,
              backgroundColor: theme.primaryBackground,
              appBar: AppBar(
                backgroundColor: theme.primary,
                automaticallyImplyLeading: false,
                elevation: 0.0,
                scrolledUnderElevation: 0.0,
                surfaceTintColor: Colors.transparent,
                centerTitle: false,
                titleSpacing: 0.0,
                toolbarHeight: 58.0,
                iconTheme: const IconThemeData(color: Colors.white),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: voltarParaRelatorio,
                ),
                title: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Gerenciar Atividade',
                        style: GoogleFonts.interTight(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        descricaoAtividade.isEmpty
                            ? 'Atividade do RDO'
                            : descricaoAtividade,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    tooltip: 'Fechar sem salvar',
                    onPressed: voltarParaRelatorio,
                  ),
                  const SizedBox(width: 4),
                ],
              ),
              body: SafeArea(
                top: true,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RdoSectionCard(
                        title: 'Dados da Atividade',
                        icon: Icons.assignment_outlined,
                        margin: EdgeInsets.zero,
                        contentPadding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (mostrarVinculoOrdemAvulsa) ...[
                              Container(
                                padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
                                decoration: BoxDecoration(
                                  color: theme.primaryBackground
                                      .withValues(alpha: 0.5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: theme.alternate),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.link_rounded,
                                      size: 15,
                                      color: theme.secondaryText,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Vincular ordem de serviço',
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                          color: theme.primaryText,
                                        ),
                                      ),
                                    ),
                                    Transform.scale(
                                      scale: 0.75,
                                      child: Switch.adaptive(
                                        value: _model.switchOrdemValue!,
                                        onChanged: (newValue) async {
                                          safeSetState(() {
                                            _model.switchOrdemValue = newValue!;
                                            if (newValue == false) {
                                              _model.dropDownOrdemUuidValue =
                                                  null;
                                              _model
                                                  .dropDownOrdemUuidValueController
                                                  ?.value = null;
                                            }
                                          });
                                        },
                                        activeColor: theme.primary,
                                        activeTrackColor: theme.primary
                                            .withValues(alpha: 0.35),
                                        inactiveTrackColor: theme.alternate,
                                        inactiveThumbColor:
                                            theme.secondaryBackground,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final estreito = constraints.maxWidth < 600;
                                  final localW = localSelectorWidget();
                                  if (!_model.switchOrdemValue!) {
                                    return localW;
                                  }
                                  final ordemW = ordemSelectorWidget();
                                  if (estreito) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        localW,
                                        const SizedBox(height: 10),
                                        ordemW,
                                      ],
                                    );
                                  }
                                  return Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: localW),
                                      const SizedBox(width: 10),
                                      Expanded(child: ordemW),
                                    ],
                                  );
                                },
                              ),
                            ] else
                              localSelectorWidget(),
                            const SizedBox(height: 10),
                            _rotuloCampo('Descrição *'),
                            TextFormField(
                              controller:
                                  _model.textFieldDescricaoTextController ??=
                                      TextEditingController(
                                text: addAtividadeRelatorioGetDadosAtividadeRowList
                                    .firstOrNull?.descricao,
                              ),
                              focusNode: _model.textFieldDescricaoFocusNode,
                              autofocus: false,
                              textInputAction: TextInputAction.next,
                              obscureText: false,
                              decoration: rdoCompactFieldDecoration(
                                context,
                                hint: 'Descreva a atividade realizada',
                              ).copyWith(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 10),
                              ),
                              style: rdoCompactFieldTextStyle(context),
                              maxLines: 3,
                              minLines: 2,
                              cursorColor: theme.primary,
                              validator: _model
                                  .textFieldDescricaoTextControllerValidator
                                  .asValidator(context),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _rotuloCampo('Quantidade *'),
                                      TextFormField(
                                        controller: _model
                                                .textFieldQtdRealizadaTextController ??=
                                            TextEditingController(
                                          text: _qtdRealizadaTexto(
                                            addAtividadeRelatorioGetDadosAtividadeRowList
                                                .firstOrNull?.qtdRealizada,
                                          ),
                                        ),
                                        focusNode:
                                            _model.textFieldQtdRealizadaFocusNode,
                                        autofocus: false,
                                        textInputAction: TextInputAction.next,
                                        obscureText: false,
                                        decoration: rdoCompactFieldDecoration(
                                          context,
                                          hint: '0',
                                        ),
                                        style: rdoCompactFieldTextStyle(context),
                                        textAlign: TextAlign.center,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                                decimal: true),
                                        inputFormatters: _formattersQuantidade,
                                        cursorColor: theme.primary,
                                        onChanged: (_) => safeSetState(() {}),
                                        onFieldSubmitted: (_) =>
                                            _persistirQtdRealizadaParcial(),
                                        validator: _model
                                            .textFieldQtdRealizadaTextControllerValidator
                                            .asValidator(context),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      _rotuloCampo('Unidade *'),
                                      TextFormField(
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
                                        decoration: rdoCompactFieldDecoration(
                                          context,
                                          hint: 'm², m³, kg...',
                                        ),
                                        style: rdoCompactFieldTextStyle(context),
                                        textAlign: TextAlign.center,
                                        cursorColor: theme.primary,
                                        validator: _model
                                            .textFieldUnidadeTextControllerValidator
                                            .asValidator(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _rotuloCampo('Status'),
                            FlutterFlowDropDown<int>(
                              controller: _model.dropDownStatusValueController!,
                              options: List<int>.from([1, 0, 2]),
                              optionLabels: const [
                                'Em andamento',
                                'Paralizada',
                                'Concluída',
                              ],
                              onChanged: (val) async {
                                safeSetState(
                                    () => _model.dropDownStatusValue = val);
                                _model.statusSelected =
                                    _model.dropDownStatusValue;
                                safeSetState(() {});
                              },
                              width: double.infinity,
                              height: 38.0,
                              textStyle: rdoCompactFieldTextStyle(context),
                              hintText: 'Selecione o status',
                              icon: Icon(
                                Icons.keyboard_arrow_down_rounded,
                                color: theme.secondaryText,
                                size: 18.0,
                              ),
                              fillColor: theme.secondaryBackground,
                              elevation: 0.0,
                              borderColor: theme.alternate,
                              borderWidth: 1.0,
                              borderRadius: 8.0,
                              margin: const EdgeInsetsDirectional.fromSTEB(
                                  10, 0, 6, 0),
                              hidesUnderline: true,
                              isSearchable: false,
                              isMultiSelect: false,
                            ),
                            if (addAtividadeRelatorioGetDadosAtividadeRowList
                                    .firstOrNull !=
                                null) ...[
                              const SizedBox(height: 12),
                              _blocosProgressoTarefaOs(
                                context: context,
                                row: addAtividadeRelatorioGetDadosAtividadeRowList
                                    .firstOrNull!,
                                detalhes: bundle.detalhesTarefa,
                                linhaOs: bundle.linhaOrdemServico,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      RdoSectionCard(
                        title: 'Insumos',
                        icon: Icons.inventory_2_outlined,
                        margin: EdgeInsets.zero,
                        contentPadding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FutureBuilder<List<CarregaItensObraRow>>(
                              key: ValueKey(
                                  'insumo_obra_$_insumosObraReloadToken'),
                              future: _futureItensObraInsumo,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return _snapshotListaErroOuLoading(
                                    context,
                                    snapshot,
                                    loadingColor: theme.primary,
                                  );
                                }
                                final itens = snapshot.data!;
                                final opcoes = _dropdownOpcoesUnicas(
                                  itens.map((e) => e.uuid),
                                  itens.map((e) => e.descricao),
                                );

                                return FlutterFlowDropDown<String>(
                                  multiSelectController:
                                      _model.dropDownInsumoValueController ??=
                                          FormFieldController<List<String>?>(
                                    _model.dropDownInsumoValue ??= <String>[],
                                  ),
                                  options: opcoes.options,
                                  optionLabels: opcoes.labels,
                                  onMultiSelectChanged: (vals) async {
                                    await _onMultiSelectItensAtividade(
                                      tipo: 'insumo',
                                      selecionados: vals,
                                      setDropDownValue: (v) =>
                                          _model.dropDownInsumoValue = v,
                                    );
                                    safeSetState(() {});
                                  },
                                  width: double.infinity,
                                  height: 38.0,
                                  textStyle: rdoCompactFieldTextStyle(context),
                                  hintText: 'Selecione um ou mais insumos',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: theme.secondaryText,
                                    size: 18.0,
                                  ),
                                  fillColor: theme.secondaryBackground,
                                  elevation: 0.0,
                                  borderColor: theme.alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: const EdgeInsetsDirectional.fromSTEB(
                                      10, 0, 6, 0),
                                  hidesUnderline: true,
                                  isSearchable: true,
                                  searchHintText: 'Buscar insumo...',
                                  isMultiSelect: true,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            BotaoCadastroObraAtalhoWidget(
                              titulo: 'Novo insumo',
                              subtitulo:
                                  'Cadastra na obra, registra no relatório e vincula à atividade',
                              icon: Icons.inventory_2_outlined,
                              onPressed: _cadastrarEVincularInsumo,
                            ),
                            const SizedBox(height: 8),
                            wrapWithModel(
                              model: _model.insumosAtividadeRelatorioModel,
                              updateCallback: () => safeSetState(() {}),
                              child: InsumosAtividadeRelatorioWidget(
                                relatorioUuid: widget!.relatorioUuid!,
                                atividadeUuid: widget!.atividadeUuid!,
                                listRefreshToken: _listasItensAtividadeRefresh,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      RdoSectionCard(
                        title: 'Equipamentos',
                        icon: Icons.construction_outlined,
                        margin: EdgeInsets.zero,
                        contentPadding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FutureBuilder<List<CarregaItensObraRow>>(
                              key: ValueKey(
                                  'equip_obra_$_equipamentosObraReloadToken'),
                              future: _futureItensObraEquipamento,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return _snapshotListaErroOuLoading(
                                    context,
                                    snapshot,
                                    loadingColor: theme.primary,
                                  );
                                }
                                final itens = snapshot.data!;
                                final opcoes = _dropdownOpcoesUnicas(
                                  itens.map((e) => e.uuid),
                                  itens.map((e) => e.descricao),
                                );

                                return FlutterFlowDropDown<String>(
                                  multiSelectController: _model
                                          .dropDownEquipamentosValueController ??=
                                      FormFieldController<List<String>?>(
                                    _model.dropDownEquipamentosValue ??=
                                        <String>[],
                                  ),
                                  options: opcoes.options,
                                  optionLabels: opcoes.labels,
                                  onMultiSelectChanged: (vals) async {
                                    await _onMultiSelectItensAtividade(
                                      tipo: 'equipamento',
                                      selecionados: vals,
                                      setDropDownValue: (v) =>
                                          _model.dropDownEquipamentosValue = v,
                                    );
                                    safeSetState(() {});
                                  },
                                  width: double.infinity,
                                  height: 38.0,
                                  textStyle: rdoCompactFieldTextStyle(context),
                                  hintText: 'Selecione um ou mais equipamentos',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: theme.secondaryText,
                                    size: 18.0,
                                  ),
                                  fillColor: theme.secondaryBackground,
                                  elevation: 0.0,
                                  borderColor: theme.alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: const EdgeInsetsDirectional.fromSTEB(
                                      10, 0, 6, 0),
                                  hidesUnderline: true,
                                  isSearchable: true,
                                  searchHintText: 'Buscar equipamento...',
                                  isMultiSelect: true,
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            BotaoCadastroObraAtalhoWidget(
                              titulo: 'Novo equipamento',
                              subtitulo: 'Cadastra na obra e vincula à atividade',
                              icon: Icons.construction_outlined,
                              onPressed: _cadastrarEVincularEquipamento,
                            ),
                            const SizedBox(height: 8),
                            wrapWithModel(
                              model: _model.equipamentosAtividadeRelatorioModel,
                              updateCallback: () => safeSetState(() {}),
                              child: EquipamentosAtividadeRelatorioWidget(
                                relatorioUuid: widget!.relatorioUuid!,
                                atividadeUuid: widget!.atividadeUuid!,
                                listRefreshToken: _listasItensAtividadeRefresh,
                                qtdRealizadaAtividade: _qtdRealizadaDoFormulario,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      RdoSectionCard(
                        title: 'Mão de Obra',
                        icon: Icons.groups_2_outlined,
                        margin: EdgeInsets.zero,
                        contentPadding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FutureBuilder<List<GetMaoObraRelatorioRow>>(
                              key: ValueKey(
                                  'mao_obra_rel_$_maoObraRelatorioReloadToken'),
                              future: _futureMaoObraPresente,
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) {
                                  return _snapshotListaErroOuLoading(
                                    context,
                                    snapshot,
                                    loadingColor: theme.primary,
                                  );
                                }
                                final itensDropdown = snapshot.data!
                                    .where((e) =>
                                        (e.obraItemUuid ?? '').trim().isNotEmpty)
                                    .toList();

                                if (itensDropdown.isEmpty) {
                                  return Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      avisoCampo(
                                        'Nenhuma mão de obra marcada como presente neste relatório. '
                                        'Registre presença no relatório para vincular aqui.',
                                        theme.error,
                                      ),
                                      const SizedBox(height: 8),
                                      BotaoCadastroObraAtalhoWidget(
                                        titulo: 'Nova mão de obra',
                                        subtitulo:
                                            'Cadastra na obra, marca presença no relatório e vincula à atividade',
                                        icon: Icons.person_add_alt_1_rounded,
                                        onPressed: _cadastrarEVincularMaoObra,
                                      ),
                                    ],
                                  );
                                }

                                final opcoes = _dropdownOpcoesUnicas(
                                  itensDropdown.map(
                                      (e) => (e.obraItemUuid ?? '').trim()),
                                  itensDropdown
                                      .map(_labelMaoObraRelatorioPresente),
                                );

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    FlutterFlowDropDown<String>(
                                      multiSelectController:
                                          _model.dropDownMaoObraValueController ??=
                                              FormFieldController<List<String>?>(
                                        _model.dropDownMaoObraValue ??= <String>[],
                                      ),
                                      options: opcoes.options,
                                      optionLabels: opcoes.labels,
                                      onMultiSelectChanged: (vals) async {
                                        await _onMultiSelectItensAtividade(
                                          tipo: 'mao_obra',
                                          selecionados: vals,
                                          setDropDownValue: (v) =>
                                              _model.dropDownMaoObraValue = v,
                                        );
                                        safeSetState(() {});
                                      },
                                      width: double.infinity,
                                      height: 38.0,
                                      textStyle:
                                          rdoCompactFieldTextStyle(context),
                                      hintText:
                                          'Selecione uma ou mais mãos de obra',
                                      icon: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        color: theme.secondaryText,
                                        size: 18.0,
                                      ),
                                      fillColor: theme.secondaryBackground,
                                      elevation: 0.0,
                                      borderColor: theme.alternate,
                                      borderWidth: 1.0,
                                      borderRadius: 8.0,
                                      margin:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              10, 0, 6, 0),
                                      hidesUnderline: true,
                                      isSearchable: true,
                                      searchHintText: 'Buscar mão de obra...',
                                      isMultiSelect: true,
                                    ),
                                    const SizedBox(height: 8),
                                    BotaoCadastroObraAtalhoWidget(
                                      titulo: 'Nova mão de obra',
                                      subtitulo:
                                          'Cadastra na obra, marca presença no relatório e vincula à atividade',
                                      icon: Icons.person_add_alt_1_rounded,
                                      onPressed: _cadastrarEVincularMaoObra,
                                    ),
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            wrapWithModel(
                              model: _model.maoObraAtividadeRelatorioModel,
                              updateCallback: () => safeSetState(() {}),
                              child: MaoObraAtividadeRelatorioWidget(
                                relatorioUuid: widget!.relatorioUuid!,
                                atividadeUuid: widget!.atividadeUuid!,
                                listRefreshToken: _listasItensAtividadeRefresh,
                                qtdRealizadaAtividade: _qtdRealizadaDoFormulario,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      wrapWithModel(
                        model: _model.fotosAtividadeModel,
                        updateCallback: () => safeSetState(() {}),
                        child: FotosAtividadeWidget(
                          parameter1: widget!.atividadeId!,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: voltarParaRelatorio,
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Cancelar'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.secondaryText,
                                minimumSize: const Size(0, 40),
                                side: BorderSide(color: theme.alternate),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
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
                                final qtdParsed = qtdTxt.isEmpty
                                    ? null
                                    : tryParseQuantidadeRelatorio(qtdTxt);
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
                                _salvouAtividade = true;
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
                              icon: const Icon(Icons.check_rounded, size: 17),
                              label: const Text('Salvar atividade'),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.primary,
                                foregroundColor: theme.info,
                                minimumSize: const Size(0, 40),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                textStyle: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

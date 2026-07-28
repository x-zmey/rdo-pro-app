import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/brazilian_currency_input_formatter.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../planejamento_api_rows.dart';
import 'obra_tarefas_model.dart';
export 'obra_tarefas_model.dart';

// --- Agrupamento etapa → tarefas raiz → filhos (composições / subtarefas) ---

bool _isTarefaRaiz(
    ListaTarefasEtapasObraRow r, List<ListaTarefasEtapasObraRow> all) {
  if (r.tipo != 'tarefa') return false;
  final pu = r.tarefaPaiUuid;
  if (pu == null || pu.isEmpty) return true;
  return !all.any((x) => x.uuid == pu);
}

int _compareItem(String? a, String? b) {
  final aa = a ?? '';
  final bb = b ?? '';
  final pa = aa.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final pb = bb.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  for (var i = 0; i < pa.length || i < pb.length; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va != vb) return va.compareTo(vb);
  }
  return aa.compareTo(bb);
}

List<ListaTarefasEtapasObraRow> _raizesOrdenadas(
    List<ListaTarefasEtapasObraRow> all) {
  final roots = all.where((r) => _isTarefaRaiz(r, all)).toList()
    ..sort((a, b) => _compareItem(a.item, b.item));
  return roots;
}

List<ListaTarefasEtapasObraRow> _filhosDe(
  String parentUuid,
  List<ListaTarefasEtapasObraRow> all,
) {
  return all.where((r) => r.tarefaPaiUuid == parentUuid).toList()
    ..sort((a, b) => _compareItem(a.item, b.item));
}

Set<String> _uuidsEmArvore(List<ListaTarefasEtapasObraRow> roots,
    List<ListaTarefasEtapasObraRow> all) {
  final u = <String>{};
  for (final t in roots) {
    u.add(t.uuid);
    for (final f in _filhosDe(t.uuid, all)) {
      u.add(f.uuid);
    }
  }
  return u;
}

String _tipoLegenda(String? tipo) {
  switch (tipo) {
    case 'tarefa':
      return 'Tarefa';
    case 'insumo':
      return 'Insumo';
    case 'mao_obra':
      return 'Mão de obra';
    case 'equipamento':
      return 'Equipamento';
    default:
      return tipo ?? '—';
  }
}

Color _tipoChipColor(BuildContext context, String? tipo) {
  final t = FlutterFlowTheme.of(context);
  switch (tipo) {
    case 'insumo':
      return const Color(0xFF2E7D32);
    case 'mao_obra':
      return const Color(0xFF1565C0);
    case 'equipamento':
      return const Color(0xFFC62828);
    case 'tarefa':
      return t.primary;
    default:
      return t.secondaryText;
  }
}

class ObraTarefasWidget extends StatefulWidget {
  const ObraTarefasWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'obraTarefas';
  static String routePath = '/obraTarefas';

  @override
  State<ObraTarefasWidget> createState() => _ObraTarefasWidgetState();
}

class _ObraTarefasWidgetState extends State<ObraTarefasWidget> {
  static final _valorUnitarioMask = BrazilianCurrencyInputFormatter();
  late ObraTarefasModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// 1 = só etapas, 2 = etapas + tarefas, 3 = etapas + tarefas + composições (como no web).
  int _nivelExibicao = 3;

  static final NumberFormat _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ObraTarefasModel());
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.conexaoResult = await actions.checkInternetConnection();
      if (!mounted) return;
      if (_model.conexaoResult!) {
        FFAppState().isConnectedToInternet = false;
        safeSetState(() {});
      } else {
        FFAppState().isConnectedToInternet = false;
        safeSetState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Sem conexão',
              style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
            ),
            duration: const Duration(milliseconds: 4000),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) safeSetState(() {});
  }

  Future<List<ListaEtapasObraRow>> _carregarEtapasApi() async {
    final token = FFAppState().UserToken;
    if (token.isEmpty) return [];

    final resp = await ListarEtapasObraApiCall.call(
      token: token,
      obraServidorId: widget.obraId,
      obraUuid: widget.obraUuid,
    );
    if (resp.statusCode != 200) return [];

    return parseEtapasPlanejamento(resp.jsonBody);
  }

  Future<void> _editarEtapa(ListaEtapasObraRow etapa) async {
    if (!MembershipAccess.canPermission('edit_tarefas')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar tarefas.',
      );
      return;
    }
    final itemCtrl = TextEditingController(text: etapa.item ?? '');
    final nomeCtrl = TextEditingController(text: etapa.nome ?? '');
    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          title: const Text('Editar etapa'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: itemCtrl,
                  decoration: const InputDecoration(labelText: 'Item'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o item.'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: nomeCtrl,
                  decoration: const InputDecoration(labelText: 'Nome da etapa'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Informe o nome.'
                      : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: salvando
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      setStateDialog(() => salvando = true);
                      try {
                        final resp = await UpdateObraEtapaCall.call(
                          token: FFAppState().UserToken,
                          etapaServidorId: etapa.id,
                          etapaUuid: etapa.uuid,
                          item: itemCtrl.text.trim(),
                          nome: nomeCtrl.text.trim(),
                        );
                        if (resp.statusCode != 200) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Falha ao editar etapa.',
                                style: TextStyle(
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                ),
                              ),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).error,
                            ),
                          );
                          return;
                        }
                        await actions.syncObrasEtapas();
                        await actions.syncObrasTarefas();
                        if (!mounted) return;
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        _refresh();
                      } finally {
                        if (ctx.mounted) {
                          setStateDialog(() => salvando = false);
                        }
                      }
                    },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editarTarefa(ListaTarefasEtapasObraRow row) async {
    if (!MembershipAccess.canPermission('edit_tarefas')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar tarefas.',
      );
      return;
    }
    final itemCtrl = TextEditingController(text: row.item ?? '');
    final descricaoCtrl = TextEditingController(text: row.descricao ?? '');
    final unidadeCtrl = TextEditingController(text: row.unidade ?? '');
    final qtdCtrl = TextEditingController(
      text: row.qtd != null ? row.qtd!.toString() : '1',
    );
    final valorUnitCtrl = TextEditingController(
      text: formatBrazilianCurrencyInputFromDouble(row.valorUnitario ?? 0),
    );
    final metaCtrl = TextEditingController(
      text: row.meta != null ? row.meta!.toString() : '0',
    );
    final metaUnidadeCtrl = TextEditingController(text: row.metaUnidade ?? '');
    final formKey = GlobalKey<FormState>();
    bool salvando = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setStateDialog) => AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          title: const Text('Editar item'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: itemCtrl,
                      decoration: const InputDecoration(labelText: 'Item'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o item.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: descricaoCtrl,
                      decoration: const InputDecoration(labelText: 'Descricao'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a descricao.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: unidadeCtrl,
                      decoration: const InputDecoration(labelText: 'Unidade'),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a unidade.'
                          : null,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: qtdCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Quantidade prevista'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: valorUnitCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_valorUnitarioMask],
                      decoration: const InputDecoration(
                        labelText: 'Valor unitario',
                        prefixText: r'R$ ',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: metaCtrl,
                      decoration: const InputDecoration(labelText: 'Meta'),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: metaUnidadeCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Meta unidade'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: salvando ? null : () => Navigator.of(ctx).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: salvando
                  ? null
                  : () async {
                      if (formKey.currentState?.validate() != true) return;
                      final qtd = double.tryParse(
                        qtdCtrl.text.trim().replaceAll(',', '.'),
                      );
                      if (qtd == null || qtd < 0.01) return;
                      final vu =
                          parseBrazilianCurrencyInput(valorUnitCtrl.text);
                      final meta = double.tryParse(
                            metaCtrl.text.trim().replaceAll(',', '.'),
                          ) ??
                          0;

                      setStateDialog(() => salvando = true);
                      try {
                        final resp = await UpdateObraTarefaCall.call(
                          token: FFAppState().UserToken,
                          tarefaServidorId: row.id,
                          tarefaUuid: row.uuid,
                          item: itemCtrl.text.trim(),
                          tipo: row.tipo ?? 'tarefa',
                          descricao: descricaoCtrl.text.trim(),
                          qtd: qtd,
                          unidade: unidadeCtrl.text.trim(),
                          valorUnitario: vu,
                          meta: meta,
                          metaUnidade: metaUnidadeCtrl.text.trim(),
                        );
                        if (resp.statusCode != 200) {
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Falha ao editar item.',
                                style: TextStyle(
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                ),
                              ),
                              backgroundColor:
                                  FlutterFlowTheme.of(context).error,
                            ),
                          );
                          return;
                        }
                        await actions.syncObrasTarefas();
                        if (!mounted) return;
                        if (!ctx.mounted) return;
                        Navigator.of(ctx).pop();
                        _refresh();
                      } finally {
                        if (ctx.mounted) {
                          setStateDialog(() => salvando = false);
                        }
                      }
                    },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _excluirEtapa(ListaEtapasObraRow etapa) async {
    if (!MembershipAccess.canPermission('delete_tarefas')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir tarefas.',
      );
      return;
    }
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir etapa'),
            content: const Text('Deseja realmente excluir esta etapa?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou) return;

    final resp = await DeleteObraEtapaCall.call(
      token: FFAppState().UserToken,
      etapaServidorId: etapa.id,
      etapaUuid: etapa.uuid,
    );
    if (resp.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao excluir etapa.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    await actions.syncObrasEtapas();
    await actions.syncObrasTarefas();
    _refresh();
  }

  Future<void> _excluirTarefa(ListaTarefasEtapasObraRow row) async {
    if (!MembershipAccess.canPermission('delete_tarefas')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir tarefas.',
      );
      return;
    }
    final confirmou = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Excluir item'),
            content: const Text('Deseja realmente excluir este item?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Excluir'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmou) return;

    final resp = await DeleteObraTarefaCall.call(
      token: FFAppState().UserToken,
      tarefaServidorId: row.id,
      tarefaUuid: row.uuid,
    );
    if (resp.statusCode != 200) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Falha ao excluir item.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    await actions.syncObrasTarefas();
    _refresh();
  }

  String _pct(ListaTarefasEtapasObraRow r) {
    final p = r.porcentagem;
    if (p == null) return '0';
    return p.toStringAsFixed(0);
  }

  String? _totalLinha(ListaTarefasEtapasObraRow r) {
    final q = r.qtd;
    final vu = r.valorUnitario;
    if (q == null || vu == null) return null;
    return _moeda.format(q * vu);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final obraUuid = widget.obraUuid ?? '';
    final canCreate = MembershipAccess.canPermission('create_tarefas');
    final canEdit = MembershipAccess.canPermission('edit_tarefas');
    final canDelete = MembershipAccess.canPermission('delete_tarefas');

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primary,
          automaticallyImplyLeading: false,
          elevation: 0,
          title: Text(
            'Planejamento',
            style: theme.headlineMedium.override(
              font: GoogleFonts.interTight(
                fontWeight: theme.headlineMedium.fontWeight,
                fontStyle: theme.headlineMedium.fontStyle,
              ),
              color: theme.primaryBackground,
              fontSize: 22,
            ),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FlutterFlowIconButton(
                borderColor: Colors.transparent,
                borderRadius: 30,
                buttonSize: 42,
                icon: Icon(Icons.arrow_back,
                    color: theme.primaryBackground, size: 24),
                onPressed: () {
                  context.pushNamed(
                    DetalhesObraWidget.routeName,
                    queryParameters: {
                      'obraId': serializeParam(widget.obraId, ParamType.int),
                      'obraUuid': serializeParam(obraUuid, ParamType.String),
                    }.withoutNulls,
                    extra: <String, dynamic>{
                      '__transition_info__': TransitionInfo(
                        hasTransition: true,
                        transitionType: PageTransitionType.rightToLeft,
                      ),
                    },
                  );
                },
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  kBarraNavegacaoPrincipalReservaScroll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (canCreate) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Incluir no servidor',
                            style: theme.titleSmall.override(
                              font: GoogleFonts.interTight(
                                  fontWeight: FontWeight.w600),
                              color: theme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await context.pushNamed(
                                      ObraAddEtapaWidget.routeName,
                                      queryParameters: {
                                        'obraServidorId': serializeParam(
                                            widget.obraId, ParamType.int),
                                        'obraUuid': serializeParam(
                                            obraUuid, ParamType.String),
                                        'obraId': serializeParam(
                                            widget.obraId, ParamType.int),
                                      }.withoutNulls,
                                    );
                                    _refresh();
                                  },
                                  icon: Icon(
                                    Icons.add_chart_outlined,
                                    color: theme.primaryBackground,
                                    size: 18,
                                  ),
                                  label: Text(
                                    'Nova etapa',
                                    style: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: theme.primaryBackground,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.primary,
                                    foregroundColor: theme.primaryBackground,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () async {
                                    await context.pushNamed(
                                      ObraAddTarefaWidget.routeName,
                                      queryParameters: {
                                        'obraUuid': serializeParam(
                                            obraUuid, ParamType.String),
                                        'obraId': serializeParam(
                                            widget.obraId, ParamType.int),
                                      }.withoutNulls,
                                    );
                                    _refresh();
                                  },
                                  icon: Icon(Icons.add_task,
                                      color: theme.primaryBackground,
                                      size: 18),
                                  label: Text(
                                    'Nova tarefa',
                                    style: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      color: theme.primaryBackground,
                                    ),
                                  ),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: theme.primary,
                                    foregroundColor: theme.primaryBackground,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10, horizontal: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () async {
                              await context.pushNamed(
                                ObraAddComposicaoWidget.routeName,
                                queryParameters: {
                                  'obraUuid': serializeParam(
                                      obraUuid, ParamType.String),
                                  'obraId': serializeParam(
                                      widget.obraId, ParamType.int),
                                }.withoutNulls,
                              );
                              _refresh();
                            },
                            icon: Icon(
                              Icons.playlist_add_outlined,
                              color: theme.primaryBackground,
                              size: 18,
                            ),
                            label: Text(
                              'Nova composição',
                              style: GoogleFonts.interTight(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: theme.primaryBackground,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.primary,
                              foregroundColor: theme.primaryBackground,
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 8),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    Text(
                      'Detalhe da lista',
                      style: theme.titleSmall.override(
                        font:
                            GoogleFonts.interTight(fontWeight: FontWeight.w600),
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Nível 1: etapas. Nível 2: + tarefas. Nível 3: + insumos, equipamentos e mão de obra.',
                      style: theme.bodySmall.override(
                        font: GoogleFonts.inter(),
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(
                              vertical: 6, horizontal: 10),
                        ),
                        backgroundColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) => states.contains(WidgetState.selected)
                              ? theme.primary
                              : theme.primary.withValues(alpha: 0.10),
                        ),
                        foregroundColor:
                            WidgetStateProperty.resolveWith<Color?>(
                          (states) => states.contains(WidgetState.selected)
                              ? theme.primaryBackground
                              : theme.primary,
                        ),
                        side: WidgetStateProperty.resolveWith<BorderSide?>(
                          (states) => BorderSide(
                            color: states.contains(WidgetState.selected)
                                ? theme.primary
                                : theme.alternate,
                            width: 1,
                          ),
                        ),
                      ),
                      segments: const [
                        ButtonSegment(
                            value: 1, label: Text('1'), tooltip: 'Etapas'),
                        ButtonSegment(
                            value: 2,
                            label: Text('2'),
                            tooltip: 'Etapas e tarefas'),
                        ButtonSegment(
                            value: 3, label: Text('3'), tooltip: 'Tudo'),
                      ],
                      selected: {_nivelExibicao},
                      onSelectionChanged: (s) {
                        if (s.isEmpty) return;
                        safeSetState(() => _nivelExibicao = s.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    FutureBuilder<List<ListaEtapasObraRow>>(
                      future: _carregarEtapasApi(),
                      builder: (context, snap) {
                        if (!snap.hasData) {
                          return Center(
                              child: LinearProgressIndicator(
                                  color: theme.primary));
                        }
                        final etapas = snap.data!;
                        if (etapas.isEmpty) {
                          return _AvisoCard(
                            child: Text(
                              'Nenhuma etapa nesta obra.',
                              style: theme.bodyMedium,
                            ),
                          );
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: etapas.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, i) {
                            final etapa = etapas[i];
                            return _EtapaPlanejamentoCard(
                              etapa: etapa,
                              obraUuid: obraUuid,
                              obraId: widget.obraId,
                              nivel: _nivelExibicao,
                              theme: theme,
                              moeda: _moeda,
                              onRefresh: _refresh,
                              onEditEtapa: _editarEtapa,
                              onEditTarefa: _editarTarefa,
                              onDeleteEtapa: _excluirEtapa,
                              onDeleteTarefa: _excluirTarefa,
                              canCreate: canCreate,
                              canEdit: canEdit,
                              canDelete: canDelete,
                              pct: _pct,
                              totalLinha: _totalLinha,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }
}

class _AvisoCard extends StatelessWidget {
  const _AvisoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.alternate),
      ),
      child: child,
    );
  }
}

class _EtapaPlanejamentoCard extends StatelessWidget {
  const _EtapaPlanejamentoCard({
    required this.etapa,
    required this.obraUuid,
    required this.obraId,
    required this.nivel,
    required this.theme,
    required this.moeda,
    required this.onRefresh,
    required this.onEditEtapa,
    required this.onEditTarefa,
    required this.onDeleteEtapa,
    required this.onDeleteTarefa,
    required this.canCreate,
    required this.canEdit,
    required this.canDelete,
    required this.pct,
    required this.totalLinha,
  });

  final ListaEtapasObraRow etapa;
  final String obraUuid;
  final int? obraId;
  final int nivel;
  final FlutterFlowTheme theme;
  final NumberFormat moeda;
  final VoidCallback onRefresh;
  final Future<void> Function(ListaEtapasObraRow etapa) onEditEtapa;
  final Future<void> Function(ListaTarefasEtapasObraRow row) onEditTarefa;
  final Future<void> Function(ListaEtapasObraRow etapa) onDeleteEtapa;
  final Future<void> Function(ListaTarefasEtapasObraRow row) onDeleteTarefa;
  final bool canCreate;
  final bool canEdit;
  final bool canDelete;
  final String Function(ListaTarefasEtapasObraRow) pct;
  final String? Function(ListaTarefasEtapasObraRow) totalLinha;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.secondaryBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: theme.secondary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    valueOrDefault<String>(etapa.item, '—'),
                    style: theme.labelLarge.override(
                      font: GoogleFonts.interTight(fontWeight: FontWeight.w700),
                      color: theme.secondaryBackground,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    valueOrDefault<String>(etapa.nome, 'Etapa'),
                    style: theme.titleSmall.override(
                      font: GoogleFonts.interTight(fontWeight: FontWeight.w700),
                      color: theme.primaryBackground,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canEdit)
                  IconButton(
                    tooltip: 'Editar etapa',
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.edit_outlined,
                        color: theme.primaryBackground, size: 18),
                    onPressed: () async {
                      await onEditEtapa(etapa);
                    },
                  ),
                if (canEdit) const SizedBox(width: 4),
                if (canDelete)
                  IconButton(
                    tooltip: 'Excluir etapa',
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.delete_outline,
                        color: theme.primaryBackground, size: 18),
                    onPressed: () async {
                      await onDeleteEtapa(etapa);
                    },
                  ),
                if (canDelete) const SizedBox(width: 4),
                if (canCreate)
                  IconButton(
                    tooltip: 'Nova composição nesta etapa',
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.playlist_add_outlined,
                        color: theme.primaryBackground, size: 18),
                    onPressed: () async {
                      await context.pushNamed(
                        ObraAddComposicaoWidget.routeName,
                        queryParameters: {
                          'obraUuid': serializeParam(obraUuid, ParamType.String),
                          'obraId': serializeParam(obraId, ParamType.int),
                          'etapaUuidInicial':
                              serializeParam(etapa.uuid, ParamType.String),
                        }.withoutNulls,
                      );
                      onRefresh();
                    },
                  ),
                if (canCreate)
                  IconButton(
                    tooltip: 'Nova tarefa nesta etapa',
                    constraints:
                        const BoxConstraints(minWidth: 30, minHeight: 30),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: Icon(Icons.add_circle_outline,
                        color: theme.primaryBackground, size: 18),
                    onPressed: () async {
                      await context.pushNamed(
                        ObraAddTarefaWidget.routeName,
                        queryParameters: {
                          'obraUuid': serializeParam(obraUuid, ParamType.String),
                          'obraId': serializeParam(obraId, ParamType.int),
                          'etapaUuidInicial':
                              serializeParam(etapa.uuid, ParamType.String),
                        }.withoutNulls,
                      );
                      onRefresh();
                    },
                  ),
              ],
            ),
          ),
          if (nivel >= 2)
            Builder(
              builder: (context) {
                final all = etapa.tarefas;
                if (all.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Sem itens nesta etapa.',
                      style:
                          theme.bodySmall.override(color: theme.secondaryText),
                    ),
                  );
                }
                final roots = _raizesOrdenadas(all);
                final used = _uuidsEmArvore(roots, all);
                final orphans = all
                    .where((r) => !used.contains(r.uuid))
                    .toList()
                  ..sort((a, b) => _compareItem(a.item, b.item));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final t in roots) ...[
                      _LinhaPlanejamento(
                        row: t,
                        indent: 0,
                        theme: theme,
                        moeda: moeda,
                        pct: pct,
                        totalLinha: totalLinha,
                        destaque: true,
                        canEdit: canEdit,
                        canDelete: canDelete,
                        onEdit: onEditTarefa,
                        onDelete: onDeleteTarefa,
                      ),
                      if (nivel >= 3)
                        ..._filhosDe(t.uuid, all).map(
                          (f) => _LinhaPlanejamento(
                            row: f,
                            indent: 1,
                            theme: theme,
                            moeda: moeda,
                            pct: pct,
                            totalLinha: totalLinha,
                            destaque: false,
                            canEdit: canEdit,
                            canDelete: canDelete,
                            onEdit: onEditTarefa,
                            onDelete: onDeleteTarefa,
                          ),
                        ),
                    ],
                    if (orphans.isNotEmpty && nivel >= 2) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                        child: Text(
                          'Demais itens (sem vínculo à árvore)',
                          style: theme.labelMedium.override(
                            font:
                                GoogleFonts.inter(fontWeight: FontWeight.w600),
                            color: theme.warning,
                          ),
                        ),
                      ),
                      for (final o in orphans)
                        _LinhaPlanejamento(
                          row: o,
                          indent: 0,
                          theme: theme,
                          moeda: moeda,
                          pct: pct,
                          totalLinha: totalLinha,
                          destaque: false,
                          canEdit: canEdit,
                          canDelete: canDelete,
                          onEdit: onEditTarefa,
                          onDelete: onDeleteTarefa,
                        ),
                    ],
                  ],
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                'Aumente o nível para ver tarefas e composições.',
                style: theme.bodySmall.override(color: theme.secondaryText),
              ),
            ),
        ],
      ),
    );
  }
}

class _LinhaPlanejamento extends StatelessWidget {
  const _LinhaPlanejamento({
    required this.row,
    required this.indent,
    required this.theme,
    required this.moeda,
    required this.pct,
    required this.totalLinha,
    required this.destaque,
    required this.canEdit,
    required this.canDelete,
    required this.onEdit,
    required this.onDelete,
  });

  final ListaTarefasEtapasObraRow row;
  final bool canEdit;
  final bool canDelete;
  final int indent;
  final FlutterFlowTheme theme;
  final NumberFormat moeda;
  final String Function(ListaTarefasEtapasObraRow) pct;
  final String? Function(ListaTarefasEtapasObraRow) totalLinha;
  final bool destaque;
  final Future<void> Function(ListaTarefasEtapasObraRow row) onEdit;
  final Future<void> Function(ListaTarefasEtapasObraRow row) onDelete;

  @override
  Widget build(BuildContext context) {
    final chipColor = _tipoChipColor(context, row.tipo);
    final vu = row.valorUnitario;
    final q = row.qtd;
    final un = row.unidade ?? '—';
    final metaUn = row.metaUnidade?.trim() ?? '';
    final metaNum = row.meta;
    final String? metaLinha = (metaNum != null && metaNum > 0)
        ? (metaUn.isNotEmpty ? 'Meta: $metaNum $metaUn' : 'Meta: $metaNum')
        : (metaUn.isNotEmpty ? 'Meta: $metaUn' : null);

    return Material(
      color: destaque
          ? theme.primaryBackground
          : theme.secondaryBackground.withValues(alpha: 0.5),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.0 + indent * 16.0, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    valueOrDefault<String>(row.item, '—'),
                    style: theme.labelMedium.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w700),
                      color: theme.primaryText,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    valueOrDefault<String>(row.descricao, '—'),
                    style: (destaque ? theme.titleSmall : theme.bodyMedium)
                        .override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            destaque ? FontWeight.w600 : FontWeight.w400,
                      ),
                      fontSize: destaque ? 14 : 13,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: chipColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    _tipoLegenda(row.tipo),
                    style: theme.labelSmall.override(
                      font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      color: chipColor,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 3,
                    children: [
                      Text('Un: $un',
                          style: theme.bodySmall
                              .override(color: theme.secondaryText)),
                      Text(
                        'Qtd: ${q != null ? (q == q.roundToDouble() ? q.toInt().toString() : q.toStringAsFixed(2)) : '—'}',
                        style: theme.bodySmall
                            .override(color: theme.secondaryText),
                      ),
                      Text(
                        'V. unit.: ${vu != null ? moeda.format(vu) : '—'}',
                        style: theme.bodySmall
                            .override(color: theme.secondaryText),
                      ),
                      Text(
                        'Total: ${totalLinha(row) ?? '—'}',
                        style: theme.bodySmall
                            .override(color: theme.secondaryText),
                      ),
                      Text(
                        'Prog.: ${pct(row)}%',
                        style: theme.bodySmall.override(
                          font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                          color: theme.primaryText,
                        ),
                      ),
                      if (metaLinha != null)
                        Text(
                          metaLinha,
                          style: theme.bodySmall
                              .override(color: theme.secondaryText),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (canEdit || canDelete)
                  Container(
                    decoration: BoxDecoration(
                      color: theme.secondaryBackground,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.alternate),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (canEdit)
                          IconButton(
                            onPressed: () async => onEdit(row),
                            tooltip: 'Editar',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            icon: Icon(Icons.edit_outlined,
                                size: 14, color: theme.primary),
                          ),
                        if (canEdit && canDelete)
                          Container(
                            width: 1,
                            height: 12,
                            color: theme.alternate,
                          ),
                        if (canDelete)
                          IconButton(
                            onPressed: () async => onDelete(row),
                            tooltip: 'Excluir',
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                                minWidth: 28, minHeight: 28),
                            icon: Icon(Icons.delete_outline,
                                size: 14, color: theme.error),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart' show SQLiteManager;
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/brazilian_currency_input_formatter.dart';
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
  String _obraNome = '';
  late Future<List<ListaEtapasObraRow>> _etapasFuture;

  static final NumberFormat _moeda =
      NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ObraTarefasModel());
    _etapasFuture = _carregarEtapasApi();
    _carregarNomeObra();
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

  Future<void> _carregarNomeObra() async {
    final uuid = (widget.obraUuid ?? '').trim();
    if (uuid.isEmpty) return;
    try {
      final rows = await SQLiteManager.instance.obraDetalhes(
        uuid: uuid,
        userId: FFAppState().creatorId,
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      final nome = rows.firstOrNull?.nome.trim() ?? '';
      if (!mounted || nome.isEmpty) return;
      setState(() => _obraNome = nome);
    } catch (_) {}
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _etapasFuture = _carregarEtapasApi();
    });
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

  void _voltarParaDetalhes() {
    context.pushNamed(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(widget.obraId, ParamType.int),
        'obraUuid': serializeParam(widget.obraUuid ?? '', ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
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
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          toolbarHeight: 58,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _voltarParaDetalhes,
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Planejamento',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Etapas, tarefas e composições'
                      : _obraNome,
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
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 21),
              onPressed: _refresh,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: theme.primary,
                onRefresh: () async => _refresh(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    kBarraNavegacaoPrincipalReservaScroll,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (canCreate) ...[
                        RdoSectionCard(
                          title: 'Incluir no planejamento',
                          icon: Icons.add_circle_outline_rounded,
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildAcaoIncluir(
                                      theme,
                                      icon: Icons.add_chart_outlined,
                                      label: 'Nova etapa',
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
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildAcaoIncluir(
                                      theme,
                                      icon: Icons.add_task_rounded,
                                      label: 'Nova tarefa',
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
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              _buildAcaoIncluir(
                                theme,
                                icon: Icons.playlist_add_outlined,
                                label: 'Nova composição',
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
                              ),
                            ],
                          ),
                        ),
                      ],
                      RdoSectionCard(
                        title: 'Nível de detalhe',
                        icon: Icons.layers_outlined,
                        subtitle: 'Escolha o que exibir na árvore abaixo',
                        margin: const EdgeInsets.only(bottom: 10),
                        contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                        child: _buildNivelFiltro(theme),
                      ),
                      FutureBuilder<List<ListaEtapasObraRow>>(
                        future: _etapasFuture,
                        builder: (context, snap) {
                          if (snap.connectionState == ConnectionState.waiting &&
                              !snap.hasData) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Center(
                                child: SizedBox(
                                  width: 34,
                                  height: 34,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 3,
                                    color: theme.primary,
                                  ),
                                ),
                              ),
                            );
                          }
                          final etapas = snap.data ?? const <ListaEtapasObraRow>[];
                          if (etapas.isEmpty) {
                            return RdoSectionCard(
                              title: 'Etapas',
                              icon: Icons.account_tree_outlined,
                              margin: EdgeInsets.zero,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 12),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.inbox_outlined,
                                      size: 36,
                                      color: theme.secondaryText
                                          .withValues(alpha: 0.45),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Nenhuma etapa nesta obra.',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: [
                              for (var i = 0; i < etapas.length; i++) ...[
                                if (i > 0) const SizedBox(height: 10),
                                _EtapaPlanejamentoCard(
                                  etapa: etapas[i],
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
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _buildNivelFiltro(FlutterFlowTheme theme) {
    const opcoes = [
      (1, 'Etapas', 'Só etapas', Icons.folder_outlined),
      (2, 'Tarefas', 'Etapas + tarefas', Icons.account_tree_outlined),
      (3, 'Completo', 'Composições', Icons.list_alt_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: theme.primaryBackground.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.alternate),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (var i = 0; i < opcoes.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _buildNivelBotao(
                theme,
                valor: opcoes[i].$1,
                titulo: opcoes[i].$2,
                subtitulo: opcoes[i].$3,
                icon: opcoes[i].$4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNivelBotao(
    FlutterFlowTheme theme, {
    required int valor,
    required String titulo,
    required String subtitulo,
    required IconData icon,
  }) {
    final selecionado = _nivelExibicao == valor;
    return Material(
      color: selecionado ? theme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          if (_nivelExibicao == valor) return;
          safeSetState(() => _nivelExibicao = valor);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionado
                      ? Colors.white.withValues(alpha: 0.18)
                      : theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: selecionado
                      ? null
                      : Border.all(color: theme.alternate),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: selecionado ? Colors.white : theme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                titulo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selecionado ? Colors.white : theme.primaryText,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                subtitulo,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w500,
                  color: selecionado
                      ? Colors.white.withValues(alpha: 0.85)
                      : theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcaoIncluir(
    FlutterFlowTheme theme, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return FilledButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: theme.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

({Color accent, Color soft}) _coresNivelPlanejamento(
  FlutterFlowTheme theme,
  int nivel,
) {
  switch (nivel) {
    case 0:
      return (accent: theme.primary, soft: theme.primary.withValues(alpha: 0.08));
    case 1:
      return (
        accent: const Color(0xFF5C6BC0),
        soft: const Color(0xFF5C6BC0).withValues(alpha: 0.08),
      );
    default:
      return (
        accent: const Color(0xFF00897B),
        soft: const Color(0xFF00897B).withValues(alpha: 0.07),
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
    final cores = _coresNivelPlanejamento(theme, 0);
    final nItens = etapa.tarefas.length;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: rdoCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
            decoration: BoxDecoration(
              color: theme.primaryBackground.withValues(alpha: 0.55),
              border: Border(bottom: BorderSide(color: theme.alternate)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 3,
                  height: 34,
                  decoration: BoxDecoration(
                    color: cores.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cores.soft,
                    borderRadius: BorderRadius.circular(6),
                    border:
                        Border.all(color: cores.accent.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    valueOrDefault<String>(etapa.item, '—'),
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: cores.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        valueOrDefault<String>(etapa.nome, 'Etapa'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.primaryText,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nItens == 0
                            ? 'Sem itens vinculados'
                            : '$nItens item${nItens == 1 ? '' : 's'} vinculados',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canCreate || canEdit || canDelete)
                  PopupMenuButton<String>(
                    tooltip: 'Ações da etapa',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_vert_rounded,
                        size: 20, color: theme.secondaryText),
                    onSelected: (v) async {
                      switch (v) {
                        case 'edit':
                          await onEditEtapa(etapa);
                        case 'delete':
                          await onDeleteEtapa(etapa);
                        case 'tarefa':
                          await context.pushNamed(
                            ObraAddTarefaWidget.routeName,
                            queryParameters: {
                              'obraUuid':
                                  serializeParam(obraUuid, ParamType.String),
                              'obraId': serializeParam(obraId, ParamType.int),
                              'etapaUuidInicial': serializeParam(
                                  etapa.uuid, ParamType.String),
                            }.withoutNulls,
                          );
                          onRefresh();
                        case 'composicao':
                          await context.pushNamed(
                            ObraAddComposicaoWidget.routeName,
                            queryParameters: {
                              'obraUuid':
                                  serializeParam(obraUuid, ParamType.String),
                              'obraId': serializeParam(obraId, ParamType.int),
                              'etapaUuidInicial': serializeParam(
                                  etapa.uuid, ParamType.String),
                            }.withoutNulls,
                          );
                          onRefresh();
                      }
                    },
                    itemBuilder: (_) => [
                      if (canCreate)
                        const PopupMenuItem(
                          value: 'tarefa',
                          child: Text('Nova tarefa'),
                        ),
                      if (canCreate)
                        const PopupMenuItem(
                          value: 'composicao',
                          child: Text('Nova composição'),
                        ),
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar etapa'),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Excluir etapa',
                            style: TextStyle(color: theme.error),
                          ),
                        ),
                    ],
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
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 18),
                    child: Text(
                      'Sem itens nesta etapa.',
                      style: GoogleFonts.inter(
                        fontSize: 12.5,
                        color: theme.secondaryText,
                      ),
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
                    for (var i = 0; i < roots.length; i++) ...[
                      if (i > 0)
                        Divider(height: 1, thickness: 1, color: theme.alternate),
                      _LinhaPlanejamento(
                        row: roots[i],
                        indent: 0,
                        theme: theme,
                        moeda: moeda,
                        pct: pct,
                        totalLinha: totalLinha,
                        canEdit: canEdit,
                        canDelete: canDelete,
                        onEdit: onEditTarefa,
                        onDelete: onDeleteTarefa,
                      ),
                      if (nivel >= 3)
                        ..._filhosDe(roots[i].uuid, all).map(
                          (f) => Column(
                            children: [
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: theme.alternate),
                              _LinhaPlanejamento(
                                row: f,
                                indent: 1,
                                theme: theme,
                                moeda: moeda,
                                pct: pct,
                                totalLinha: totalLinha,
                                canEdit: canEdit,
                                canDelete: canDelete,
                                onEdit: onEditTarefa,
                                onDelete: onDeleteTarefa,
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (orphans.isNotEmpty && nivel >= 2) ...[
                      Divider(height: 1, color: theme.alternate),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                        child: Text(
                          'OUTROS ITENS',
                          style: rdoColumnLabelStyle(context).copyWith(
                            color: theme.warning,
                          ),
                        ),
                      ),
                      for (var i = 0; i < orphans.length; i++) ...[
                        if (i > 0)
                          Divider(height: 1, color: theme.alternate),
                        _LinhaPlanejamento(
                          row: orphans[i],
                          indent: 0,
                          theme: theme,
                          moeda: moeda,
                          pct: pct,
                          totalLinha: totalLinha,
                          canEdit: canEdit,
                          canDelete: canDelete,
                          onEdit: onEditTarefa,
                          onDelete: onDeleteTarefa,
                        ),
                      ],
                    ],
                  ],
                );
              },
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
              child: Text(
                'Selecione o nível 2 ou 3 para ver tarefas e composições.',
                style: GoogleFonts.inter(
                  fontSize: 12.5,
                  color: theme.secondaryText,
                ),
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
  final Future<void> Function(ListaTarefasEtapasObraRow row) onEdit;
  final Future<void> Function(ListaTarefasEtapasObraRow row) onDelete;

  @override
  Widget build(BuildContext context) {
    final nivel = indent + 1;
    final cores = _coresNivelPlanejamento(theme, nivel);
    final chipColor = _tipoChipColor(context, row.tipo);
    final vu = row.valorUnitario;
    final q = row.qtd;
    final un = (row.unidade ?? '').trim().isEmpty ? '—' : row.unidade!.trim();
    final metaUn = row.metaUnidade?.trim() ?? '';
    final metaNum = row.meta;
    final String? metaTxt = (metaNum != null && metaNum > 0)
        ? (metaUn.isNotEmpty ? '$metaNum $metaUn' : '$metaNum')
        : (metaUn.isNotEmpty ? metaUn : null);
    final qTxt = q == null
        ? '—'
        : (q == q.roundToDouble()
            ? q.toInt().toString()
            : q.toStringAsFixed(2));
    final total = totalLinha(row);
    final prog = double.tryParse(pct(row)) ?? 0;
    final isTarefa = indent == 0;

    return Material(
      color: isTarefa
          ? theme.secondaryBackground
          : theme.primaryBackground.withValues(alpha: 0.35),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12.0 + indent * 12.0, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 40,
                  margin: const EdgeInsets.only(top: 2, right: 10),
                  decoration: BoxDecoration(
                    color: cores.accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            valueOrDefault<String>(row.item, '—'),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: cores.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: chipColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _tipoLegenda(row.tipo).toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: chipColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        valueOrDefault<String>(row.descricao, '—'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isTarefa ? 13.5 : 13,
                          fontWeight:
                              isTarefa ? FontWeight.w600 : FontWeight.w500,
                          color: theme.primaryText,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canEdit || canDelete)
                  PopupMenuButton<String>(
                    tooltip: 'Ações',
                    padding: EdgeInsets.zero,
                    icon: Icon(Icons.more_horiz_rounded,
                        size: 20, color: theme.secondaryText),
                    onSelected: (v) async {
                      if (v == 'edit') await onEdit(row);
                      if (v == 'delete') await onDelete(row);
                    },
                    itemBuilder: (_) => [
                      if (canEdit)
                        const PopupMenuItem(
                          value: 'edit',
                          child: Text('Editar'),
                        ),
                      if (canDelete)
                        PopupMenuItem(
                          value: 'delete',
                          child: Text(
                            'Excluir',
                            style: TextStyle(color: theme.error),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: theme.primaryBackground.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.alternate),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _kpiCell(theme, 'UN', un),
                  ),
                  _kpiDiv(theme),
                  Expanded(
                    child: _kpiCell(theme, 'QTD', qTxt),
                  ),
                  _kpiDiv(theme),
                  Expanded(
                    flex: 2,
                    child: _kpiCell(
                      theme,
                      'V. UNIT.',
                      vu != null ? moeda.format(vu) : '—',
                    ),
                  ),
                  _kpiDiv(theme),
                  Expanded(
                    flex: 2,
                    child: _kpiCell(
                      theme,
                      'TOTAL',
                      total ?? '—',
                      destaque: true,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'PROGRESSO',
                            style: rdoColumnLabelStyle(context),
                          ),
                          const Spacer(),
                          Text(
                            '${pct(row)}%',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: theme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (prog / 100).clamp(0.0, 1.0),
                          minHeight: 5,
                          backgroundColor: theme.alternate,
                          color: theme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (metaTxt != null) ...[
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: theme.alternate),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('META', style: rdoColumnLabelStyle(context)),
                        const SizedBox(height: 2),
                        Text(
                          metaTxt,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiDiv(FlutterFlowTheme theme) => Container(
        width: 1,
        height: 28,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: theme.alternate,
      );

  Widget _kpiCell(
    FlutterFlowTheme theme,
    String label,
    String value, {
    bool destaque = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: destaque ? theme.primary : theme.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

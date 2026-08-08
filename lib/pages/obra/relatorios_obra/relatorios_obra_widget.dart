import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/relatorios/relatorio_list_item_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'relatorios_obra_model.dart';
export 'relatorios_obra_model.dart';

class RelatoriosObraWidget extends StatefulWidget {
  const RelatoriosObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'relatoriosObra';
  static String routePath = '/relatoriosObra';

  @override
  State<RelatoriosObraWidget> createState() => _RelatoriosObraWidgetState();
}

class _RelatoriosObraWidgetState extends State<RelatoriosObraWidget>
    with TickerProviderStateMixin {
  static const int _kRelatoriosPageSize = 20;

  late RelatoriosObraModel _model;
  late final AnimationController _shimmerController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  List<RelatoriosObraRow> _relatoriosObra = [];
  int _relatoriosObraOffset = 0;
  bool _relatoriosObraHasMore = true;
  bool _relatoriosObraInitialLoad = true;
  bool _relatoriosObraLoadMore = false;
  Object? _relatoriosObraError;
  String _obraNome = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RelatoriosObraModel());
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
    _carregarNomeObra();
    _carregarRelatoriosInicial();
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

  Future<List<RelatoriosObraRow>> _queryRelatoriosPage(int offset) {
    return SQLiteManager.instance.relatoriosObra(
      obraUuid: widget.obraUuid!,
      accountOwnerUuid: FFAppState().creatorUuid,
      limit: _kRelatoriosPageSize + 1,
      offset: offset,
    );
  }

  Future<void> _carregarRelatoriosInicial() async {
    if (!mounted) return;
    setState(() {
      _relatoriosObraInitialLoad = true;
      _relatoriosObraError = null;
      _relatoriosObra = [];
      _relatoriosObraOffset = 0;
      _relatoriosObraHasMore = true;
    });
    try {
      final page = await _queryRelatoriosPage(0);
      if (!mounted) return;
      setState(() {
        _relatoriosObraHasMore = page.length > _kRelatoriosPageSize;
        _relatoriosObra = _relatoriosObraHasMore
            ? page.sublist(0, _kRelatoriosPageSize)
            : page;
        _relatoriosObraOffset = _relatoriosObra.length;
        _relatoriosObraInitialLoad = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _relatoriosObraError = e;
        _relatoriosObraInitialLoad = false;
      });
    }
  }

  Future<void> _abrirRelatorioDetalhes(RelatoriosObraRow row) async {
    await context.pushNamed(
      RelatorioDetalhesWidget.routeName,
      queryParameters: {
        'id': serializeParam(row.id, ParamType.int),
        'uuid': serializeParam(row.uuid, ParamType.String),
      }.withoutNulls,
    );
    if (!mounted) return;
    await _carregarRelatoriosInicial();
  }

  Future<void> _abrirEdicaoRelatorio(RelatoriosObraRow row) async {
    await context.pushNamed(
      ObraAddRelatorioWidget.routeName,
      queryParameters: {
        'id': serializeParam(row.id, ParamType.int),
        'uuid': serializeParam(row.uuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
    if (!mounted) return;
    await _carregarRelatoriosInicial();
  }

  Future<void> _carregarMaisRelatorios() async {
    if (_relatoriosObraLoadMore || !_relatoriosObraHasMore) return;
    if (!mounted) return;
    setState(() => _relatoriosObraLoadMore = true);
    try {
      final page = await _queryRelatoriosPage(_relatoriosObraOffset);
      if (!mounted) return;
      setState(() {
        _relatoriosObraHasMore = page.length > _kRelatoriosPageSize;
        final toAdd = _relatoriosObraHasMore
            ? page.sublist(0, _kRelatoriosPageSize)
            : page;
        _relatoriosObra.addAll(toAdd);
        _relatoriosObraOffset += toAdd.length;
        _relatoriosObraLoadMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _relatoriosObraLoadMore = false);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar mais itens.',
            style: TextStyle(color: FlutterFlowTheme.of(context).info),
          ),
        ),
      );
    }
  }

  Future<void> _apagarRelatorio(RelatoriosObraRow row) async {
    final theme = FlutterFlowTheme.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar relatório'),
        content: const Text(
          'Deseja apagar este relatório? Esta ação será um soft delete.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;

    await SQLiteManager.instance.softDeleteRelatorio(uuid: row.uuid);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Relatório apagado.',
          style: TextStyle(color: theme.alternate),
        ),
        duration: const Duration(milliseconds: 3000),
        backgroundColor: theme.secondary,
      ),
    );
    await _carregarRelatoriosInicial();
  }

  void _voltarParaDetalhes() {
    context.pushNamed(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(widget.obraId, ParamType.int),
        'obraUuid': serializeParam(widget.obraUuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
  }

  Widget _shimmerBox(
    BuildContext context, {
    double? width,
    required double height,
    double radius = 6.0,
  }) {
    final t = FlutterFlowTheme.of(context);
    final base = t.alternate.withValues(alpha: 0.34);
    final highlight = t.alternate.withValues(alpha: 0.22);
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final v = _shimmerController.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.1 + (2.2 * v), -0.10),
              end: Alignment(1.1 + (2.2 * v), 0.10),
              colors: [base, highlight, base],
              stops: const [0.18, 0.5, 0.82],
            ),
          ),
        );
      },
    );
  }

  Widget _buildShimmerLista(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      children: List.generate(4, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 3 ? 0 : 6),
          child: Container(
            width: double.infinity,
            decoration: rdoCardDecoration(context),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3.5, color: theme.alternate),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _shimmerBox(context, width: 72, height: 14),
                              const Spacer(),
                              _shimmerBox(
                                context,
                                width: 64,
                                height: 18,
                                radius: 10,
                              ),
                              const SizedBox(width: 6),
                              _shimmerBox(
                                context,
                                width: 28,
                                height: 28,
                                radius: 7,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _shimmerBox(context, width: 160, height: 11),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildCarregarMaisButton(BuildContext context) {
    final t = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Center(
        child: _relatoriosObraLoadMore
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: t.primary,
                ),
              )
            : TextButton.icon(
                onPressed: _carregarMaisRelatorios,
                icon: Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: t.secondaryText,
                ),
                label: Text(
                  'Carregar mais',
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.secondaryText,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
      ),
    );
  }

  Widget _buildLista(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    if (_relatoriosObraInitialLoad) {
      return _buildShimmerLista(context);
    }

    if (_relatoriosObraError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: theme.error),
            const SizedBox(height: 10),
            Text(
              'Não foi possível carregar os relatórios.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.error,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _carregarRelatoriosInicial,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (_relatoriosObra.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        child: Column(
          children: [
            Icon(
              Icons.description_outlined,
              size: 44,
              color: theme.secondaryText.withValues(alpha: 0.45),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhum relatório nesta obra ainda.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < _relatoriosObra.length; i++)
          RelatorioListItemWidget(
            numero: _relatoriosObra[i].numero,
            dataLabel: () {
              final dataExec = formatDataResumoRelatorio(
                _relatoriosObra[i].dataExecutado,
              );
              return dataExec.isNotEmpty
                  ? dataExec
                  : _relatoriosObra[i].dataExecutado;
            }(),
            statusId: _relatoriosObra[i].statusId,
            statusLabel: labelRelatorioStatus(
              statusId: _relatoriosObra[i].statusId,
              statusNome: _relatoriosObra[i].statusNome,
            ),
            criador: nomeExibicaoCriadorRelatorio(
              _relatoriosObra[i].criadorNome,
              _relatoriosObra[i].criador,
            ),
            marginBottom: i == _relatoriosObra.length - 1 && !_relatoriosObraHasMore
                ? 0
                : 6,
            onTap: () => _abrirRelatorioDetalhes(_relatoriosObra[i]),
            onVisualizar: () => _abrirRelatorioDetalhes(_relatoriosObra[i]),
            onEditar: () => _abrirEdicaoRelatorio(_relatoriosObra[i]),
            onApagar: () => _apagarRelatorio(_relatoriosObra[i]),
          ),
        if (_relatoriosObraHasMore) _buildCarregarMaisButton(context),
      ],
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final contagem = _relatoriosObraInitialLoad
        ? null
        : (_relatoriosObraHasMore
            ? '${_relatoriosObra.length}+'
            : '${_relatoriosObra.length}');

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
                  'Relatórios da Obra',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty ? 'RDOs sincronizados desta obra' : _obraNome,
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
              icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 21),
              onPressed:
                  _relatoriosObraInitialLoad ? null : _carregarRelatoriosInicial,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: true,
          child: RefreshIndicator(
            color: theme.primary,
            onRefresh: _carregarRelatoriosInicial,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                RdoSectionCard(
                  title: 'Relatórios',
                  icon: Icons.description_outlined,
                  margin: EdgeInsets.zero,
                  trailing: contagem == null
                      ? null
                      : RdoContadorChip(contagem),
                  contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  child: _buildLista(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

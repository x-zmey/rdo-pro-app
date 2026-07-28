import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/relatorios/relatorio_list_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RelatoriosObraModel());
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
    _carregarRelatoriosInicial();
  }

  Future<List<RelatoriosObraRow>> _queryRelatoriosPage(int offset) {
    return SQLiteManager.instance.relatoriosObra(
      obraUuid: widget!.obraUuid!,
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
        'id': serializeParam(
          row.id,
          ParamType.int,
        ),
        'uuid': serializeParam(
          row.uuid,
          ParamType.String,
        ),
      }.withoutNulls,
    );
    if (!mounted) return;
    await _carregarRelatoriosInicial();
  }

  Future<void> _abrirEdicaoRelatorio(RelatoriosObraRow row) async {
    await context.pushNamed(
      ObraAddRelatorioWidget.routeName,
      queryParameters: {
        'id': serializeParam(
          row.id,
          ParamType.int,
        ),
        'uuid': serializeParam(
          row.uuid,
          ParamType.String,
        ),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
    if (!mounted) return;
    await _carregarRelatoriosInicial();
  }

  Future<void> _carregarMaisRelatorios() async {
    if (_relatoriosObraLoadMore || !_relatoriosObraHasMore) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _relatoriosObraLoadMore = true;
    });
    try {
      final page = await _queryRelatoriosPage(_relatoriosObraOffset);
      if (!mounted) {
        return;
      }
      setState(() {
        _relatoriosObraHasMore = page.length > _kRelatoriosPageSize;
        final toAdd = _relatoriosObraHasMore
            ? page.sublist(0, _kRelatoriosPageSize)
            : page;
        _relatoriosObra.addAll(toAdd);
        _relatoriosObraOffset += toAdd.length;
        _relatoriosObraLoadMore = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _relatoriosObraLoadMore = false;
      });
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível carregar mais itens.',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).info,
            ),
          ),
        ),
      );
    }
  }

  Widget _buildCarregarMaisButton(BuildContext context) {
    final t = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0, 14, 0, 10),
      child: Align(
        alignment: AlignmentDirectional.center,
        child: _relatoriosObraLoadMore
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: t.primary.withValues(alpha: 0.45),
                  ),
                ),
              )
            : TextButton(
                onPressed: _carregarMaisRelatorios,
                style: TextButton.styleFrom(
                  foregroundColor: t.secondaryText.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: t.secondaryText.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Carregar mais',
                      style: t.bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w400,
                        ),
                        fontSize: 14,
                        color: t.secondaryText.withValues(alpha: 0.8),
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _model.dispose();

    super.dispose();
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

  @override
  Widget build(BuildContext context) {
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
            borderColor: Colors.transparent,
            borderRadius: 20.0,
            borderWidth: 1.0,
            buttonSize: 40.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () async {
              context.pushNamed(
                DetalhesObraWidget.routeName,
                queryParameters: {
                  'obraId': serializeParam(
                    widget!.obraId,
                    ParamType.int,
                  ),
                  'obraUuid': serializeParam(
                    widget!.obraUuid,
                    ParamType.String,
                  ),
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
          title: Text(
            'Relatórios da Obra',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(12.0, 16.0, 12.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          if (_relatoriosObraInitialLoad) {
                            final t = FlutterFlowTheme.of(context);
                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              primary: false,
                              shrinkWrap: true,
                              itemCount: 3,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8.0),
                              itemBuilder: (context, _) {
                                return Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: t.secondaryBackground,
                                    borderRadius: BorderRadius.circular(14.0),
                                    border: Border.all(
                                      color: t.primaryText
                                          .withValues(alpha: 0.06),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black
                                            .withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        12, 10, 12, 8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            _shimmerBox(context,
                                                width: 72, height: 12),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: _shimmerBox(context,
                                                  height: 11),
                                            ),
                                            const SizedBox(width: 8),
                                            _shimmerBox(context,
                                                width: 72, height: 18,
                                                radius: 10),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment:
                                              AlignmentDirectional.centerEnd,
                                          child: _shimmerBox(
                                            context,
                                            width: 180,
                                            height: 28,
                                            radius: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          }
                          if (_relatoriosObraError != null) {
                            return Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'Não foi possível carregar os relatórios.',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                        ),
                                  ),
                                  TextButton(
                                    onPressed: _carregarRelatoriosInicial,
                                    child: const Text('Tentar novamente'),
                                  ),
                                ],
                              ),
                            );
                          }
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ListView.builder(
                                padding: EdgeInsets.zero,
                                primary: false,
                                shrinkWrap: true,
                                scrollDirection: Axis.vertical,
                                itemCount: _relatoriosObra.length,
                                itemBuilder: (context, listViewIndex) {
                                  final row = _relatoriosObra[listViewIndex];
                                  final theme = FlutterFlowTheme.of(context);
                                  final dataExec = formatDataResumoRelatorio(
                                    row.dataExecutado,
                                  );
                                  final dataLabel = dataExec.isNotEmpty
                                      ? dataExec
                                      : row.dataExecutado;
                                  final criador =
                                      (row.criadorNome ?? row.criador ?? '')
                                          .trim();

                                  return RelatorioListItemWidget(
                                    numero: row.numero,
                                    dataLabel: dataLabel,
                                    statusId: row.statusId,
                                    statusLabel: labelRelatorioStatus(
                                      statusId: row.statusId,
                                      statusNome: row.statusNome,
                                    ),
                                    criador:
                                        criador.isNotEmpty ? criador : null,
                                    marginBottom: 8,
                                    onTap: () => _abrirRelatorioDetalhes(row),
                                    onVisualizar: () =>
                                        _abrirRelatorioDetalhes(row),
                                    onEditar: () => _abrirEdicaoRelatorio(row),
                                    onApagar: () async {
                                      final confirmar = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: const Text('Apagar relatório'),
                                          content: const Text(
                                            'Deseja apagar este relatório? Esta ação será um soft delete.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(false),
                                              child: const Text('Cancelar'),
                                            ),
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.of(ctx).pop(true),
                                              child: const Text('Apagar'),
                                            ),
                                          ],
                                        ),
                                      );

                                      if (confirmar != true) return;

                                      await SQLiteManager.instance
                                          .softDeleteRelatorio(
                                        uuid: row.uuid,
                                      );
                                      if (!mounted || !context.mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Relatório apagado.',
                                            style: TextStyle(
                                              color: theme.alternate,
                                            ),
                                          ),
                                          duration: const Duration(
                                            milliseconds: 3000,
                                          ),
                                          backgroundColor: theme.secondary,
                                        ),
                                      );
                                      await _carregarRelatoriosInicial();
                                    },
                                  );
                                },
                              ),
                              if (_relatoriosObraHasMore)
                                _buildCarregarMaisButton(context),
                            ],
                          );
                        },
                      ),
                    ].divide(SizedBox(height: 16.0)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

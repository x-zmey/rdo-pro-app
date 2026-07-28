import '/auth/fetch_allowed_obras.dart';
import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/relatorios/relatorio_list_item_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'relatorios_geral_model.dart';
export 'relatorios_geral_model.dart';

/// Lista global de RDOs (SQL local). Com obra_travada, só obras permitidas.
class RelatoriosGeraisWidget extends StatefulWidget {
  const RelatoriosGeraisWidget({super.key});

  static const String routeName = 'relatoriosGerais';
  static const String routePath = '/relatorios-geral';

  @override
  State<RelatoriosGeraisWidget> createState() => _RelatoriosGeraisWidgetState();
}

class _RelatoriosGeraisWidgetState extends State<RelatoriosGeraisWidget>
    with TickerProviderStateMixin {
  late RelatoriosGeraisModel _model;
  late final AnimationController _shimmerController;

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const int _perPage = 25;
  final List<RelatoriosGeraisRow> _itens = [];

  bool _carregando = true;
  bool _carregandoMais = false;
  bool _temMais = true;
  String? _erroInicial;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RelatoriosGeraisModel());
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
    _recarregar(reset: true);
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

  Future<void> _recarregar({bool reset = false}) async {
    if (reset) {
      setState(() {
        _carregando = true;
        _erroInicial = null;
        _itens.clear();
        _temMais = true;
      });
    } else {
      if (!_temMais || _carregandoMais) return;
      setState(() => _carregandoMais = true);
    }

    final offset = reset ? 0 : _itens.length;

    try {
      List<String>? allowedObraUuids;
      if (MembershipAccess.obraTravada) {
        await refreshAllowedObraIdsIfNeeded();
        allowedObraUuids = List<String>.from(FFAppState().allowedObraUuids);
      }

      final lote = await SQLiteManager.instance.relatoriosGerais(
        limit: _perPage,
        offset: offset,
        accountOwnerUuid: FFAppState().creatorUuid,
        allowedObraUuids: allowedObraUuids,
      );
      if (!mounted) return;
      setState(() {
        if (reset) _itens.clear();
        _itens.addAll(lote);
        _temMais = lote.length >= _perPage;
        _carregando = false;
        _carregandoMais = false;
        _erroInicial = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _carregando = false;
        _carregandoMais = false;
        if (reset) {
          _erroInicial = 'Não foi possível carregar os relatórios.';
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erro ao carregar: $e'),
            ),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: true,
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
            onPressed: () => context.pop(),
          ),
          title: Text(
            'Relatórios',
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
          actions: const [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: kBarraNavegacaoPrincipalReservaScroll,
                  ),
                  child: _carregando && _itens.isEmpty
                      ? ListView.separated(
                          padding: const EdgeInsets.fromLTRB(
                            12.0,
                            8.0,
                            12.0,
                            16.0,
                          ),
                          itemCount: 3,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8.0),
                          itemBuilder: (context, _) {
                            final t = FlutterFlowTheme.of(context);
                            return Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: t.secondaryBackground,
                                borderRadius: BorderRadius.circular(14.0),
                                border: Border.all(
                                  color:
                                      t.primaryText.withValues(alpha: 0.06),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color:
                                        Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(12, 10, 12, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        _shimmerBox(context,
                                            width: 72, height: 12),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              _shimmerBox(context, height: 11),
                                              const SizedBox(height: 6),
                                              _shimmerBox(
                                                  context,
                                                  width: 120,
                                                  height: 9),
                                            ],
                                          ),
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
                        )
                      : _erroInicial != null && _itens.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  _erroInicial!,
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Column(
                              children: [
                                Expanded(
                                  child: _itens.isEmpty
                                      ? Center(
                                          child: Text(
                                            'Nenhum relatório no dispositivo.\nSincronize o app e tente novamente.',
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyLarge,
                                          ),
                                        )
                                      : ListView.builder(
                                          padding: const EdgeInsets.fromLTRB(
                                            12.0,
                                            8.0,
                                            12.0,
                                            16.0,
                                          ),
                                          itemCount: _itens.length,
                                          itemBuilder: (context, i) {
                                            return _cardRelatorio(_itens[i]);
                                          },
                                        ),
                                ),
                                if (_itens.isNotEmpty && _temMais) ...[
                                  const Divider(height: 1),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(
                                        16.0, 14.0, 16.0, 10.0),
                                    child: Align(
                                      alignment: AlignmentDirectional.center,
                                      child: _carregandoMais
                                          ? Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 10),
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2.5,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary
                                                      .withValues(alpha: 0.45),
                                                ),
                                              ),
                                            )
                                          : TextButton(
                                              onPressed: () =>
                                                  _recarregar(reset: false),
                                              style: TextButton.styleFrom(
                                                foregroundColor:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText
                                                        .withValues(alpha: 0.75),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                  vertical: 10,
                                                ),
                                                minimumSize: const Size(0, 40),
                                                tapTargetSize:
                                                    MaterialTapTargetSize
                                                        .padded,
                                                visualDensity:
                                                    VisualDensity.standard,
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.expand_more,
                                                    size: 18,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryText
                                                        .withValues(alpha: 0.5),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Carregar mais',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w400,
                                                          ),
                                                          fontSize: 14,
                                                          color:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .secondaryText
                                                                  .withValues(
                                                                      alpha:
                                                                          0.8),
                                                          letterSpacing: 0.1,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                ),
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: BarraNavegacaoPrincipal(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cardRelatorio(RelatoriosGeraisRow row) {
    final dataExec = formatDataResumoRelatorio(row.dataExecutado);
    final dataLabel =
        dataExec.isNotEmpty ? dataExec : row.dataExecutado;
    final criador = (row.criadorNome ?? row.criador ?? '').trim();
    final obraTitulo = valueOrDefault<String>(row.obraNome, 'Obra');

    void abrirDetalhes() {
      context.pushNamed(
        RelatorioDetalhesWidget.routeName,
        queryParameters: {
          'id': serializeParam(row.id, ParamType.int),
          'uuid': serializeParam(row.uuid, ParamType.String),
        }.withoutNulls,
      );
    }

    return RelatorioListItemWidget(
      numero: row.numero,
      dataLabel: dataLabel,
      statusId: row.statusId,
      statusLabel: labelRelatorioStatus(
        statusId: row.statusId,
        statusNome: row.statusNome,
      ),
      criador: criador.isNotEmpty ? criador : null,
      subtitulo: obraTitulo,
      marginBottom: 8,
      onTap: abrirDetalhes,
      onVisualizar: abrirDetalhes,
      onEditar: () {
        context.pushNamed(
          ObraAddRelatorioWidget.routeName,
          queryParameters: {
            'id': serializeParam(row.id, ParamType.int),
            'uuid': serializeParam(row.uuid, ParamType.String),
          }.withoutNulls,
          extra: <String, dynamic>{
            '__transition_info__': TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.rightToLeft,
            ),
          },
        );
      },
      onApagar: () => _confirmarExcluir(row),
    );
  }

  Future<void> _confirmarExcluir(RelatoriosGeraisRow row) async {
    final theme = FlutterFlowTheme.of(context);
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Apagar relatório'),
        content: const Text(
          'Deseja apagar este relatório? Será removido localmente (soft delete).',
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
    if (!mounted || !context.mounted) return;
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
    setState(() {
      _itens.removeWhere((e) => e.uuid == row.uuid);
    });
  }
}

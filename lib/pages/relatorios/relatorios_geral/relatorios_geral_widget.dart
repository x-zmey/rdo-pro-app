import '/auth/fetch_allowed_obras.dart';
import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/relatorios/relatorio_list_item_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
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
            SnackBar(content: Text('Erro ao carregar: $e')),
          );
        }
      });
    }
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
    setState(() {
      _itens.removeWhere((e) => e.uuid == row.uuid);
    });
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
                          _shimmerBox(context, width: 180, height: 11),
                          const SizedBox(height: 6),
                          _shimmerBox(context, width: 120, height: 10),
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

  Widget _buildCarregarMais(BuildContext context) {
    final t = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 2),
      child: Center(
        child: _carregandoMais
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: t.primary,
                ),
              )
            : TextButton.icon(
                onPressed: () => _recarregar(reset: false),
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

  Widget _cardRelatorio(RelatoriosGeraisRow row, {required bool ultimo}) {
    final dataExec = formatDataResumoRelatorio(row.dataExecutado);
    final dataLabel = dataExec.isNotEmpty ? dataExec : row.dataExecutado;
    final criador = nomeExibicaoCriadorRelatorio(row.criadorNome, row.criador);
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
      criador: criador,
      subtitulo: obraTitulo,
      marginBottom: ultimo && !_temMais ? 0 : 6,
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
            '__transition_info__': const TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.rightToLeft,
            ),
          },
        );
      },
      onApagar: () => _confirmarExcluir(row),
    );
  }

  Widget _buildConteudo(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_carregando && _itens.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          kBarraNavegacaoPrincipalReservaScroll + bottomInset + 16,
        ),
        children: [
          RdoSectionCard(
            title: 'Todos os relatórios',
            icon: Icons.description_outlined,
            margin: EdgeInsets.zero,
            contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: _buildShimmerLista(context),
          ),
        ],
      );
    }

    if (_erroInicial != null && _itens.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          16,
          40,
          16,
          kBarraNavegacaoPrincipalReservaScroll + bottomInset + 16,
        ),
        children: [
          Icon(Icons.error_outline_rounded, size: 44, color: theme.error),
          const SizedBox(height: 12),
          Text(
            _erroInicial!,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 13.5, color: theme.error),
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: () => _recarregar(reset: true),
              child: const Text('Tentar novamente'),
            ),
          ),
        ],
      );
    }

    final contagem = _temMais ? '${_itens.length}+' : '${_itens.length}';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        16,
        10,
        16,
        kBarraNavegacaoPrincipalReservaScroll + bottomInset + 16,
      ),
      children: [
        RdoSectionCard(
          title: 'Todos os relatórios',
          icon: Icons.description_outlined,
          margin: EdgeInsets.zero,
          trailing: RdoContadorChip(contagem),
          contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: _itens.isEmpty
              ? Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 28, horizontal: 8),
                  child: Column(
                    children: [
                      Icon(
                        Icons.folder_open_rounded,
                        size: 44,
                        color: theme.secondaryText.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nenhum relatório no dispositivo.\nSincronize o app e tente novamente.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.35,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < _itens.length; i++)
                      _cardRelatorio(
                        _itens[i],
                        ultimo: i == _itens.length - 1,
                      ),
                    if (_temMais) _buildCarregarMais(context),
                  ],
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
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
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.goNamed(InicioWidget.routeName);
              }
            },
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Relatórios',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Todos os RDOs sincronizados',
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
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 21,
              ),
              onPressed: _carregando ? null : () => _recarregar(reset: true),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: RefreshIndicator(
                  color: theme.primary,
                  onRefresh: () => _recarregar(reset: true),
                  child: _buildConteudo(context),
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
}

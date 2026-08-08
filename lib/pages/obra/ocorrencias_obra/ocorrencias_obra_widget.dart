import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'ocorrencias_obra_model.dart';
export 'ocorrencias_obra_model.dart';

/// Listagem de ocorrências de uma obra (descrição, RDO, tipo, horários, responsável).
class OcorrenciasObraWidget extends StatefulWidget {
  const OcorrenciasObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'ocorrenciasObra';
  static String routePath = '/ocorrenciasObra';

  @override
  State<OcorrenciasObraWidget> createState() => _OcorrenciasObraWidgetState();
}

class _OcorrenciasObraWidgetState extends State<OcorrenciasObraWidget> {
  late OcorrenciasObraModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();

  String _obraNome = '';
  late Future<List<CarregaOcorrenciasObraRow>> _ocorrenciasFuture;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OcorrenciasObraModel());
    _ocorrenciasFuture = _carregarOcorrencias();
    _carregarNomeObra();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_ocorrencias')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar ocorrências.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<List<CarregaOcorrenciasObraRow>> _carregarOcorrencias() {
    final u = widget.obraUuid?.trim();
    if (u == null || u.isEmpty) {
      return Future.value(const []);
    }
    return SQLiteManager.instance.carregaOcorrenciasObra(obraUuid: u);
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

  Future<void> _refresh() async {
    setState(() {
      _ocorrenciasFuture = _carregarOcorrencias();
    });
    await _ocorrenciasFuture;
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

  String _labelHora(String? v) {
    if (v == null || v.trim().isEmpty) return '—';
    final t = v.trim();
    if (t.length >= 5 && t.contains('T')) {
      final d = DateTime.tryParse(t);
      if (d != null) {
        final h = d.hour.toString().padLeft(2, '0');
        final m = d.minute.toString().padLeft(2, '0');
        return '$h:$m';
      }
    }
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(t)) {
      return t.length > 5 ? t.substring(0, 5) : t;
    }
    return t;
  }

  String _labelData(String? v) {
    if (v == null || v.trim().isEmpty) return '—';
    final t = v.trim();
    if (t.length >= 10 && t[4] == '-' && t[7] == '-') {
      return '${t.substring(8, 10)}/${t.substring(5, 7)}/${t.substring(0, 4)}';
    }
    if (t.length >= 10 && t.contains('T')) {
      final d = DateTime.tryParse(t);
      if (d != null) {
        return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
      }
    }
    if (RegExp(r'^\d{2}/\d{2}/\d{4}').hasMatch(t)) {
      return t.length > 10 ? t.substring(0, 10) : t;
    }
    return t;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

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
                  'Ocorrências',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Registradas nos RDOs da obra'
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
            Expanded(child: _bodyObraOcorrencias(theme)),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _bodyObraOcorrencias(FlutterFlowTheme theme) {
    final u = widget.obraUuid?.trim();
    if (u == null || u.isEmpty) {
      return Center(
        child: Text(
          'Obra sem identificador.',
          style: GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
        ),
      );
    }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<CarregaOcorrenciasObraRow>>(
        future: _ocorrenciasFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ],
            );
          }

          final list = snapshot.data ?? const <CarregaOcorrenciasObraRow>[];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              kBarraNavegacaoPrincipalReservaScroll,
            ),
            children: [
              RdoSectionCard(
                title: 'Ocorrências da obra',
                icon: Icons.report_problem_outlined,
                subtitle: list.isEmpty
                    ? 'Nenhum registro encontrado'
                    : 'Vinculadas aos relatórios diários',
                margin: EdgeInsets.zero,
                trailing: list.isEmpty
                    ? null
                    : RdoContadorChip('${list.length}'),
                contentPadding: EdgeInsets.zero,
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.report_problem_outlined,
                              size: 40,
                              color:
                                  theme.secondaryText.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma ocorrência nesta obra',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'As ocorrências aparecem aqui após serem lançadas nos RDOs.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < list.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.alternate,
                              ),
                            _buildOcorrenciaObraItem(theme, list[i]),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOcorrenciaObraItem(
    FlutterFlowTheme theme,
    CarregaOcorrenciasObraRow row,
  ) {
    final rdoNum = row.relatorioNumero;
    final tipo = row.tipoNome?.trim();
    final tipoText = (tipo == null || tipo.isEmpty) ? null : tipo;
    final autor = valueOrDefault<String>(row.autorNome, '').trim();
    final dataRdo = _labelData(row.relatorioData);
    final hi = _labelHora(row.horaInicio);
    final hf = _labelHora(row.horaSaida);
    final descricao = valueOrDefault<String>(row.descricao, '—');

    return Material(
      color: theme.secondaryBackground,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: theme.warning),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'RDO #${rdoNum ?? '—'}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: theme.primary,
                            ),
                          ),
                        ),
                        if (tipoText != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: theme.warning.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color:
                                      theme.warning.withValues(alpha: 0.28),
                                ),
                              ),
                              child: Text(
                                tipoText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: theme.warning,
                                ),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(
                          dataRdo,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descricao,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                        color: theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryBackground.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.alternate),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _metaCell(theme, 'INÍCIO', hi),
                          ),
                          Container(
                            width: 1,
                            height: 26,
                            color: theme.alternate,
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _metaCell(theme, 'FIM', hf),
                            ),
                          ),
                          if (autor.isNotEmpty) ...[
                            Container(
                              width: 1,
                              height: 26,
                              color: theme.alternate,
                            ),
                            Expanded(
                              flex: 2,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: _metaCell(theme, 'RESPONSÁVEL', autor),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaCell(FlutterFlowTheme theme, String label, String value) {
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
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
      ],
    );
  }
}

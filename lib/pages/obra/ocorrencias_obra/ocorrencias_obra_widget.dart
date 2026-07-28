import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OcorrenciasObraModel());
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

  String _labelHora(String? v) {
    if (v == null || v.trim().isEmpty) {
      return '—';
    }
    final t = v.trim();
    if (t.length >= 5 && t.contains('T')) {
      try {
        final d = DateTime.tryParse(t);
        if (d != null) {
          final h = d.hour.toString().padLeft(2, '0');
          final m = d.minute.toString().padLeft(2, '0');
          return '$h:$m';
        }
      } catch (_) {}
    }
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(t)) {
      return t.length > 5 ? t.substring(0, 5) : t;
    }
    return t;
  }

  String _labelData(String? v) {
    if (v == null || v.trim().isEmpty) {
      return '—';
    }
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

  Widget _buildOcorrenciaObraItem(
    BuildContext context,
    CarregaOcorrenciasObraRow row,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final borderColor = theme.primaryText.withValues(alpha: 0.06);
    final rdoNum = row.relatorioNumero;
    final tipo = row.tipoNome?.trim();
    final tipoText = (tipo == null || tipo.isEmpty) ? null : tipo;
    final autor = valueOrDefault<String>(row.autorNome, '').trim();
    final dataRdo = _labelData(row.relatorioData);
    final hi = _labelHora(row.horaInicio);
    final hf = _labelHora(row.horaSaida);
    final descricao = valueOrDefault<String>(row.descricao, '—');

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(9, 6, 9, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'RDO #${rdoNum ?? '—'}',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: theme.primary,
                      height: 1,
                    ),
                  ),
                ),
                if (tipoText != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.secondary.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: theme.alternate,
                      ),
                    ),
                    child: Text(
                      tipoText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText,
                        height: 1,
                      ),
                    ),
                  ),
                ],
                if (autor.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Icon(
                    Icons.person_outline_rounded,
                    size: 11,
                    color: theme.secondaryText,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      autor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: theme.secondaryText,
                        height: 1.1,
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 6),
                Text(
                  dataRdo,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    color: theme.secondaryText,
                    height: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              descricao,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.25,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Início $hi · Fim $hf',
              style: GoogleFonts.inter(
                fontSize: 9.5,
                color: theme.secondaryText,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          toolbarHeight: 52.0,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 20.0,
            borderWidth: 1.0,
            buttonSize: 40.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 20.0,
            ),
            onPressed: () async {
              context.pushNamed(
                DetalhesObraWidget.routeName,
                queryParameters: {
                  'obraId': serializeParam(
                    widget.obraId,
                    ParamType.int,
                  ),
                  'obraUuid': serializeParam(
                    widget.obraUuid,
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
            'Ocorrências da Obra',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle: FlutterFlowTheme.of(context)
                        .headlineMedium
                        .fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 18.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 1.0,
        ),
        body: SafeArea(
          top: true,
          child: _bodyObraOcorrencias(context),
        ),
        bottomNavigationBar: const BarraNavegacaoPrincipal(),
      ),
    );
  }

  Widget _bodyObraOcorrencias(BuildContext context) {
    final u = widget.obraUuid?.trim();
    if (u == null || u.isEmpty) {
      return Center(
        child: Text(
          'Obra sem identificador.',
          style: FlutterFlowTheme.of(context).bodyLarge,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: FutureBuilder<List<CarregaOcorrenciasObraRow>>(
            future: SQLiteManager.instance.carregaOcorrenciasObra(
              obraUuid: u,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: LinearProgressIndicator(
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                );
              }
              final list = snapshot.data!;
              if (list.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text(
                      'Nenhuma ocorrência nesta obra.',
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyLarge,
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  kBarraNavegacaoPrincipalReservaScroll,
                ),
                scrollDirection: Axis.vertical,
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 5),
                itemBuilder: (context, i) {
                  return _buildOcorrenciaObraItem(context, list[i]);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'comentarios_obra_novo_model.dart';
export 'comentarios_obra_novo_model.dart';

/// Normaliza `created_at` (ISO/SQLite) para exibição pt-BR.
String _formatarDataHoraComentario(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final s = raw.trim();
  DateTime? dt = DateTime.tryParse(s);
  if (dt == null) {
    try {
      dt = DateTime.parse(s);
    } catch (_) {
      return s;
    }
  }
  return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dt.toLocal());
}

/// crie para mim uma página chamada comentários, nela vai ter todos os
/// comentários de uma obra, eu quero que em cada item da listagem tenha, quem
/// escreveu o comentário, a data dela oo numero do relatório de rdo que foi
/// feito esse comentário, o texto dele e tbm precisa ter um botão de voltar a
/// página anterior
class ComentariosObraNovoWidget extends StatefulWidget {
  const ComentariosObraNovoWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'comentariosObraNovo';
  static String routePath = '/comentariosObraNovo';

  @override
  State<ComentariosObraNovoWidget> createState() =>
      _ComentariosObraNovoWidgetState();
}

class _ComentariosObraNovoWidgetState extends State<ComentariosObraNovoWidget> {
  late ComentariosObraNovoModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ComentariosObraNovoModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_comentarios')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar comentários.',
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

  Widget _buildComentarioObraItem(
    BuildContext context,
    CarregaComentariosObraRow row,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final nomeAutor = valueOrDefault<String>(row.autorNome, 'Usuário');
    final rdoNum = row.relatorioNumero;
    final dataHora = _formatarDataHoraComentario(row.createdAt);
    final texto = valueOrDefault<String>(row.texto, 'Sem texto');
    final borderColor = theme.primaryText.withValues(alpha: 0.06);

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
                const SizedBox(width: 6),
                Icon(
                  Icons.person_outline_rounded,
                  size: 11,
                  color: theme.secondaryText,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    nomeAutor,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: theme.secondaryText,
                      height: 1.1,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    dataHora,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: theme.secondaryText,
                      height: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              texto,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.25,
                color: theme.primaryText,
              ),
            ),
          ],
        ),
      ),
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
          toolbarHeight: 52.0,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 16.0,
            borderWidth: 1.0,
            buttonSize: 36.0,
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
            'Comentários da Obra',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  fontSize: 18.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 1.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                height: 1.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).alternate,
                ),
              ),
              Expanded(
                child: FutureBuilder<List<CarregaComentariosObraRow>>(
                  future: SQLiteManager.instance.carregaComentariosObra(
                    obraUuid: widget!.obraUuid!,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(
                        child: LinearProgressIndicator(
                          color: FlutterFlowTheme.of(context).primary,
                        ),
                      );
                    }
                    final listViewCarregaComentariosObraRowList =
                        snapshot.data!;

                    if (listViewCarregaComentariosObraRowList.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Text(
                            'Nenhum comentário nesta obra.',
                            textAlign: TextAlign.center,
                            style: FlutterFlowTheme.of(context).bodyLarge,
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        12.0,
                        12.0,
                        12.0,
                        kBarraNavegacaoPrincipalReservaScroll,
                      ),
                      scrollDirection: Axis.vertical,
                      itemCount: listViewCarregaComentariosObraRowList.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 5),
                      itemBuilder: (context, listViewIndex) {
                        return _buildComentarioObraItem(
                          context,
                          listViewCarregaComentariosObraRowList[listViewIndex],
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: const BarraNavegacaoPrincipal(),
      ),
    );
  }
}

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

  String _obraNome = '';
  late Future<List<CarregaComentariosObraRow>> _comentariosFuture;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ComentariosObraNovoModel());
    _comentariosFuture = _carregarComentarios();
    _carregarNomeObra();
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

  Future<List<CarregaComentariosObraRow>> _carregarComentarios() {
    final u = widget.obraUuid?.trim();
    if (u == null || u.isEmpty) {
      return Future.value(const []);
    }
    return SQLiteManager.instance.carregaComentariosObra(obraUuid: u);
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
      _comentariosFuture = _carregarComentarios();
    });
    await _comentariosFuture;
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

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) {
      return partes.first.length >= 2
          ? partes.first.substring(0, 2).toUpperCase()
          : partes.first.toUpperCase();
    }
    final a = partes.first[0];
    final b = partes.last[0];
    return ('$a$b').toUpperCase();
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
                  'Comentários',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Registrados nos RDOs da obra'
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
            Expanded(child: _body(theme)),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _body(FlutterFlowTheme theme) {
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
      child: FutureBuilder<List<CarregaComentariosObraRow>>(
        future: _comentariosFuture,
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

          final list = snapshot.data ?? const <CarregaComentariosObraRow>[];

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
                title: 'Comentários da obra',
                icon: Icons.chat_bubble_outline_rounded,
                subtitle: list.isEmpty
                    ? 'Nenhum registro encontrado'
                    : 'Lançados nos relatórios diários',
                margin: EdgeInsets.zero,
                trailing:
                    list.isEmpty ? null : RdoContadorChip('${list.length}'),
                contentPadding: EdgeInsets.zero,
                child: list.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 40,
                              color:
                                  theme.secondaryText.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhum comentário nesta obra',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Os comentários aparecem aqui após serem lançados nos RDOs.',
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
                            _buildComentarioItem(theme, list[i]),
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

  Widget _buildComentarioItem(
    FlutterFlowTheme theme,
    CarregaComentariosObraRow row,
  ) {
    final nomeAutor = valueOrDefault<String>(row.autorNome, 'Usuário');
    final rdoNum = row.relatorioNumero;
    final dataHora = _formatarDataHoraComentario(row.createdAt);
    final texto = valueOrDefault<String>(row.texto, 'Sem texto');

    return Material(
      color: theme.secondaryBackground,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: theme.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              theme.primary.withValues(alpha: 0.12),
                          child: Text(
                            _iniciais(nomeAutor),
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: theme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                nomeAutor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primaryText,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dataHora,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                      decoration: BoxDecoration(
                        color:
                            theme.primaryBackground.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: theme.alternate),
                      ),
                      child: Text(
                        texto,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                          color: theme.primaryText,
                        ),
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
}

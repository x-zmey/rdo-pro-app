import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart' show SQLiteManager;
import '/componentes/dialogs/cadastrar_local/cadastrar_local_widget.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'locais_obra_model.dart';
export 'locais_obra_model.dart';

/// Lista locais vinculados à obra pela API e cadastro via diálogo.
class LocaisObraWidget extends StatefulWidget {
  const LocaisObraWidget({
    super.key,
    required this.obraUuid,
  });

  final String? obraUuid;

  static String routeName = 'locaisObra';
  static String routePath = '/locaisObra';

  @override
  State<LocaisObraWidget> createState() => _LocaisObraWidgetState();
}

class _LocaisObraWidgetState extends State<LocaisObraWidget> {
  late LocaisObraModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isLoading = true;
  bool _isRefreshingSilently = false;
  List<Map<String, dynamic>> _locais = <Map<String, dynamic>>[];
  String _obraNome = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LocaisObraModel());
    _carregarNomeObra();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_cadastros_gerais')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar cadastros gerais.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
        return;
      }
      _fetchLocais(silent: false);
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

  List<Map<String, dynamic>> _extractLocais(dynamic body) {
    if (body is List) {
      return body
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (body is Map) {
      final candidates = [body['data'], body['value'], body['locais']];
      for (final candidate in candidates) {
        if (candidate is List) {
          return candidate
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    }
    return <Map<String, dynamic>>[];
  }

  Future<void> _fetchLocais({required bool silent}) async {
    final uuid = widget.obraUuid;
    if (uuid == null || uuid.isEmpty) return;

    if (silent) {
      if (mounted) setState(() => _isRefreshingSilently = true);
    } else {
      if (mounted) setState(() => _isLoading = true);
    }
    try {
      final response = await ObraLocaisPorObraCall.call(
        token: FFAppState().UserToken,
        obraUuid: uuid,
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = response.jsonBody;
        final msg = body is Map && body['message'] != null
            ? body['message'].toString()
            : 'Falha ao carregar locais';
        throw Exception(msg);
      }
      final rows = _extractLocais(response.jsonBody);
      if (!mounted) return;
      setState(() => _locais = rows);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar locais: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRefreshingSilently = false;
        });
      }
    }
  }

  Future<void> _abrirCadastroLocal() async {
    if (!MembershipAccess.canPermission('create_cadastros_gerais')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para criar cadastros gerais.',
      );
      return;
    }
    final uuid = widget.obraUuid;
    if (uuid == null || uuid.isEmpty) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (dialogContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(dialogContext).bottom,
          ),
          child: CadastrarLocalWidget(obraUuid: uuid),
        );
      },
    );

    if (!mounted) return;
    await _fetchLocais(silent: true);
  }

  Future<void> _voltar() async {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final uuid = widget.obraUuid;
    if (uuid == null || uuid.isEmpty) return;
    context.pushNamed(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraUuid': serializeParam(uuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final canCreate =
        MembershipAccess.canPermission('create_cadastros_gerais');

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
            onPressed: _voltar,
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Locais',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Locais vinculados à obra'
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
              icon: _isRefreshingSilently
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 21),
              onPressed: (_isLoading || _isRefreshingSilently)
                  ? null
                  : () => _fetchLocais(silent: true),
            ),
            if (canCreate)
              IconButton(
                tooltip: 'Novo local',
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
                onPressed: _abrirCadastroLocal,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: theme.primary,
                onRefresh: () => _fetchLocais(silent: true),
                child: ListView(
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
                    if (canCreate)
                      RdoSectionCard(
                        title: 'Incluir local',
                        icon: Icons.add_location_alt_outlined,
                        subtitle: 'Cadastrar e vincular à obra',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: _abrirCadastroLocal,
                          icon: const Icon(Icons.place_outlined, size: 18),
                          label: Text(
                            'Novo local',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    RdoSectionCard(
                      title: 'Lista da obra',
                      icon: Icons.place_outlined,
                      margin: EdgeInsets.zero,
                      trailing: _locais.isEmpty
                          ? null
                          : RdoContadorChip('${_locais.length}'),
                      contentPadding: EdgeInsets.zero,
                      child: _isLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 36),
                              child: Center(
                                child: SizedBox(
                                  width: 32,
                                  height: 32,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5),
                                ),
                              ),
                            )
                          : _locais.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                      16, 28, 16, 28),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.place_outlined,
                                        size: 40,
                                        color: theme.secondaryText
                                            .withValues(alpha: 0.4),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'Nenhum local nesta obra',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: theme.primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        canCreate
                                            ? 'Cadastre um local para vincular a esta obra.'
                                            : 'Nenhum local vinculado a esta obra.',
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
                                    for (var i = 0; i < _locais.length; i++) ...[
                                      if (i > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: theme.alternate,
                                        ),
                                      _buildLocalItem(theme, _locais[i], i),
                                    ],
                                  ],
                                ),
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

  Widget _buildLocalItem(
    FlutterFlowTheme theme,
    Map<String, dynamic> row,
    int index,
  ) {
    final nome = valueOrDefault<String>(row['nome']?.toString(), 'Sem nome');

    return Material(
      color: theme.secondaryBackground,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: theme.primary),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: theme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.place_rounded,
                        size: 18,
                        color: theme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nome,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: theme.primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Local ${index + 1}',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.secondaryText,
                            ),
                          ),
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
}

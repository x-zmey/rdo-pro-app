import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/dialogs/cadastrar_local/cadastrar_local_widget.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LocaisObraModel());
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

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          alignment: AlignmentDirectional(0.0, 0.0)
              .resolve(Directionality.of(context)),
          child: GestureDetector(
            onTap: () {
              FocusScope.of(dialogContext).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: CadastrarLocalWidget(
              obraUuid: uuid,
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    // Recarrega pela API para refletir o vínculo recém-criado.
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
        '__transition_info__': TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
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
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: false,
          toolbarHeight: 52.0,
          leading: FlutterFlowIconButton(
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderRadius: 10.0,
            borderWidth: 1.0,
            buttonSize: 36.0,
            fillColor: FlutterFlowTheme.of(context).secondaryBackground,
            icon: Icon(
              Icons.arrow_back_ios,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 16.0,
            ),
            onPressed: _voltar,
          ),
          title: Text(
            'Locais',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 18.0,
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
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_locais.length} ${_locais.length == 1 ? 'local' : 'locais'}',
                              style: FlutterFlowTheme.of(context).labelMedium,
                            ),
                          ),
                          if (_isRefreshingSilently)
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    FlutterFlowIconButton(
                      borderRadius: 20,
                      buttonSize: 34,
                      icon: Icon(
                        Icons.refresh_rounded,
                        color: FlutterFlowTheme.of(context).primary,
                        size: 18,
                      ),
                      onPressed: (_isLoading || _isRefreshingSilently)
                          ? null
                          : () => _fetchLocais(silent: true),
                    ),
                    if (MembershipAccess.canPermission(
                        'create_cadastros_gerais')) ...[
                      const SizedBox(width: 6),
                      FFButtonWidget(
                        onPressed: _abrirCadastroLocal,
                        text: 'Adicionar',
                        icon: const Icon(Icons.add_location_alt_outlined,
                            size: 16),
                        options: FFButtonOptions(
                          height: 34,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          color: FlutterFlowTheme.of(context).primary,
                          textStyle: FlutterFlowTheme.of(context)
                              .labelMedium
                              .override(
                                font: GoogleFonts.inter(
                                  fontWeight: FontWeight.w600,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).info,
                              ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      12.0, 10.0, 12.0, 12.0),
                  child: _isLoading
                      ? Center(
                          child: LinearProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        )
                      : _locais.isEmpty
                          ? Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.place_outlined,
                                    size: 32,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Nenhum local nesta obra',
                                    style: FlutterFlowTheme.of(context)
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    MembershipAccess.canPermission(
                                            'create_cadastros_gerais')
                                        ? 'Use Adicionar para cadastrar e vincular um local.'
                                        : 'Nenhum local vinculado a esta obra.',
                                    style:
                                        FlutterFlowTheme.of(context).bodySmall,
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(
                                bottom: kBarraNavegacaoPrincipalReservaScroll,
                              ),
                              itemCount: _locais.length,
                              itemBuilder: (context, index) {
                                final row = _locais[index];
                                final nome = valueOrDefault<String>(
                                  row['nome']?.toString(),
                                  'Sem nome',
                                );
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Material(
                                    color: Colors.transparent,
                                    elevation: 0,
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 10,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary
                                                        .withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.place_rounded,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primary,
                                                size: 18,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                nome,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .titleMedium
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          fontSize: 14,
                                                        ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
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

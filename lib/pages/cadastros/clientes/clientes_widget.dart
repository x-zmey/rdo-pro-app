import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'clientes_model.dart';
export 'clientes_model.dart';

/// crie uma pagina onde será listados os clientes e com botão acima de
/// cadastrar cliente
class ClientesWidget extends StatefulWidget {
  const ClientesWidget({super.key});

  static String routeName = 'Clientes';
  static String routePath = '/clientes';

  @override
  State<ClientesWidget> createState() => _ClientesWidgetState();
}

class _ClientesWidgetState extends State<ClientesWidget> {
  late ClientesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Força novo carregamento da lista após exclusão.
  int _listaVersao = 0;

  List<Map<String, dynamic>> _extractClientes(dynamic body) {
    final rawClientes = body is Map ? body['clientes'] : null;
    final rawData = rawClientes is Map ? rawClientes['data'] : rawClientes;
    if (rawData is! List) return [];
    return rawData
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchClientesApi() async {
    final resp = await ListarClientesApiCall.call(
      token: FFAppState().UserToken,
      itemsPerPage: 1000,
    );
    if (!resp.succeeded) {
      throw Exception(
        resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao carregar clientes',
      );
    }
    return _extractClientes(resp.jsonBody);
  }

  int? _intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String? _clienteUuid(Map<String, dynamic> cliente) {
    final uuid = cliente['uuid']?.toString().trim();
    return uuid != null && uuid.isNotEmpty ? uuid : null;
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ClientesModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_clientes')) {
        MembershipAccess.showDenied(context);
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
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: false,
          title: Text(
            'Clientes',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleLarge.fontStyle,
                  ),
                  color: Colors.white,
                  fontSize: 20.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).titleLarge.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          16.0, 16.0, 16.0, 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FFButtonWidget(
                            onPressed: () async {
                              context
                                  .pushNamed(CadastrarClienteWidget.routeName);
                            },
                            text: 'Cadastrar Cliente',
                            icon: Icon(
                              Icons.add_sharp,
                              size: 15.0,
                            ),
                            options: FFButtonOptions(
                              height: 40.0,
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 0.0, 16.0, 0.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: Colors.white,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding:
                          EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 0.0),
                      child: FutureBuilder<List<Map<String, dynamic>>>(
                        key: ValueKey<int>(_listaVersao),
                        future: _fetchClientesApi(),
                        builder: (context, snapshot) {
                          // Customize what your widget looks like when it's loading.
                          if (!snapshot.hasData) {
                            return Center(
                              child: LinearProgressIndicator(
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Center(
                              child: Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Text(
                                  'Erro ao carregar clientes',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                ),
                              ),
                            );
                          }
                          final listViewClientesList = snapshot.data!;

                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            itemCount: listViewClientesList.length,
                            itemBuilder: (context, listViewIndex) {
                              final listViewCliente =
                                  listViewClientesList[listViewIndex];
                              final clienteUuid = _clienteUuid(listViewCliente);
                              final clienteId = _intFrom(listViewCliente['id']);
                              return Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 12.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsets.all(4.0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    12.0, 0.0, 8.0, 0.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  valueOrDefault<String>(
                                                    listViewCliente['nome']
                                                        ?.toString(),
                                                    'Cliente sem nome',
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyLarge
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyLarge
                                                                  .fontStyle,
                                                        ),
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .bodyLarge
                                                                .fontStyle,
                                                      ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 2.0, 0.0, 0.0),
                                                  child: Text(
                                                    valueOrDefault<String>(
                                                      listViewCliente['email']
                                                          ?.toString(),
                                                      'Sem email',
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 14.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 2.0, 0.0, 0.0),
                                                  child: Text(
                                                    valueOrDefault<String>(
                                                      listViewCliente[
                                                              'telefone']
                                                          ?.toString(),
                                                      'Sem telefone',
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodySmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 12.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        if (clienteUuid != null ||
                                            clienteId != null)
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                tooltip: 'Detalhes',
                                                icon: Icon(
                                                  Icons.visibility_outlined,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  size: 22.0,
                                                ),
                                                onPressed: () async {
                                                  await context.pushNamed(
                                                    ClienteDetalhesWidget
                                                        .routeName,
                                                    queryParameters: {
                                                      'clienteServidorId':
                                                          serializeParam(
                                                        clienteId,
                                                        ParamType.int,
                                                      ),
                                                      'clienteUuid':
                                                          serializeParam(
                                                        clienteUuid,
                                                        ParamType.String,
                                                      ),
                                                    }.withoutNulls,
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                tooltip: 'Editar',
                                                icon: Icon(
                                                  Icons.edit_outlined,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primary,
                                                  size: 22.0,
                                                ),
                                                onPressed: () async {
                                                  context.pushNamed(
                                                    CadastrarClienteWidget
                                                        .routeName,
                                                    queryParameters: {
                                                      'clienteUuid':
                                                          serializeParam(
                                                        clienteUuid,
                                                        ParamType.String,
                                                      ),
                                                    }.withoutNulls,
                                                  );
                                                },
                                              ),
                                              IconButton(
                                                tooltip: 'Apagar',
                                                icon: Icon(
                                                  Icons.delete_outline,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  size: 22.0,
                                                ),
                                                onPressed: () async {
                                                  final nome =
                                                      valueOrDefault<String>(
                                                    listViewCliente['nome']
                                                        ?.toString(),
                                                    'Cliente',
                                                  );
                                                  final confirmar =
                                                      await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) =>
                                                        AlertDialog(
                                                      title: const Text(
                                                          'Apagar cliente'),
                                                      content: Text(
                                                        'Deseja apagar o cliente "$nome"? '
                                                        'Ele deixará de aparecer na lista.',
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(ctx)
                                                                  .pop(false),
                                                          child: const Text(
                                                              'Cancelar'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.of(ctx)
                                                                  .pop(true),
                                                          child: Text(
                                                            'Apagar',
                                                            style: TextStyle(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .error,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                  if (confirmar != true ||
                                                      !context.mounted) {
                                                    return;
                                                  }
                                                  final resp =
                                                      await ExcluirClienteCall
                                                          .call(
                                                    id: clienteId,
                                                    clienteUuid:
                                                        clienteUuid ?? '',
                                                    token:
                                                        FFAppState().UserToken,
                                                  );
                                                  if (!context.mounted) {
                                                    return;
                                                  }
                                                  if (resp.succeeded) {
                                                    setState(() {
                                                      _listaVersao++;
                                                    });
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: const Text(
                                                          'Cliente apagado',
                                                        ),
                                                        backgroundColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondary,
                                                      ),
                                                    );
                                                  } else {
                                                    ScaffoldMessenger.of(
                                                            context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          resp.bodyText
                                                                  .isNotEmpty
                                                              ? resp.bodyText
                                                              : 'Erro ao apagar cliente',
                                                        ),
                                                        backgroundColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                      ),
                                                    );
                                                  }
                                                },
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

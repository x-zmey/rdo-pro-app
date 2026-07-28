import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'usuarios_model.dart';
export 'usuarios_model.dart';

class UsuariosWidget extends StatefulWidget {
  const UsuariosWidget({super.key});

  static String routeName = 'Usuarios';
  static String routePath = '/usuarios';

  @override
  State<UsuariosWidget> createState() => _UsuariosWidgetState();
}

class _UsuariosWidgetState extends State<UsuariosWidget> {
  late UsuariosModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  int _listaVersao = 0;

  final TextEditingController _filtroController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UsuariosModel());
    _filtroController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _filtroController.dispose();
    _model.dispose();
    super.dispose();
  }

  String _formatarTipo(String? type) {
    switch (type) {
      case 'administrador':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'operador':
        return 'Operador';
      case 'cliente':
        return 'Cliente';
      default:
        return type ?? '—';
    }
  }

  String _rotuloStatus(int? situacao) {
    if (situacao == null || situacao == 1) return 'Ativo';
    if (situacao == 0) return 'Inativo';
    return '—';
  }

  Color _corStatus(BuildContext context, int? situacao) {
    if (situacao == null || situacao == 1) {
      return FlutterFlowTheme.of(context).secondary;
    }
    if (situacao == 0) {
      return FlutterFlowTheme.of(context).alternate;
    }
    return FlutterFlowTheme.of(context).secondaryText;
  }

  List<Map<String, dynamic>> _extractUsuarios(dynamic body) {
    final rawValue = body is Map ? body['value'] : null;
    final rawUsers = rawValue is Map ? rawValue['users'] : rawValue;
    if (rawUsers is! List) return [];
    return rawUsers
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUsuariosApi() async {
    final resp = await ListarUsuariosApiCall.call(
      token: FFAppState().UserToken,
    );
    if (!resp.succeeded) {
      throw Exception(
        resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao carregar usuários',
      );
    }
    return _extractUsuarios(resp.jsonBody);
  }

  List<Map<String, dynamic>> _filtrarLocal(List<Map<String, dynamic>> todos) {
    final q = _filtroController.text.toLowerCase().trim();
    if (q.isEmpty) return todos;
    return todos.where((u) {
      final nome = (u['nome']?.toString() ?? '').toLowerCase();
      final email = (u['email']?.toString() ?? '').toLowerCase();
      return nome.contains(q) || email.contains(q);
    }).toList();
  }

  int? _intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String? _usuarioUuid(Map<String, dynamic> usuario) {
    final uuid = usuario['uuid']?.toString().trim();
    return uuid != null && uuid.isNotEmpty ? uuid : null;
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
            'Usuários',
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
          bottom: false,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: kBarraNavegacaoPrincipalReservaScroll,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16.0, 16.0, 16.0, 8.0),
                        child: FFButtonWidget(
                          onPressed: () async {
                            context.pushNamed(CadastrarUsuarioWidget.routeName);
                          },
                          text: 'Cadastrar usuário',
                          icon: const Icon(
                            Icons.person_add_outlined,
                            size: 18.0,
                          ),
                          options: FFButtonOptions(
                            height: 40.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            color: FlutterFlowTheme.of(context).primary,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  font: GoogleFonts.interTight(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                  ),
                                  color: Colors.white,
                                ),
                            elevation: 0.0,
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            16.0, 0.0, 16.0, 8.0),
                        child: TextFormField(
                          controller: _filtroController,
                          obscureText: false,
                          decoration: InputDecoration(
                            labelText: 'Pesquisar nome ou e-mail',
                            hintStyle: FlutterFlowTheme.of(context).labelMedium,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).primary,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: FlutterFlowTheme.of(context).secondaryText,
                              size: 20.0,
                            ),
                          ),
                          style: FlutterFlowTheme.of(context).bodyMedium,
                        ),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                              16.0, 0.0, 16.0, 0.0),
                          child: FutureBuilder<List<Map<String, dynamic>>>(
                            key: ValueKey<int>(_listaVersao),
                            future: _fetchUsuariosApi(),
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Center(
                                  child: Text(
                                    'Erro ao carregar usuários',
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                        ),
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return Center(
                                  child: LinearProgressIndicator(
                                    color: FlutterFlowTheme.of(context).primary,
                                  ),
                                );
                              }
                              final filtrados =
                                  _filtrarLocal(snapshot.data ?? const []);

                              if (filtrados.isEmpty) {
                                return Center(
                                  child: Text(
                                    'Nenhum usuário encontrado.',
                                    style:
                                        FlutterFlowTheme.of(context).bodyMedium,
                                  ),
                                );
                              }

                              return ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: filtrados.length,
                                itemBuilder: (context, listViewIndex) {
                                  final row = filtrados[listViewIndex];
                                  final uuid = _usuarioUuid(row);
                                  final idServidor = _intFrom(row['id']);
                                  final identificador =
                                      uuid ?? idServidor?.toString();
                                  final temIdentificador =
                                      identificador != null;
                                  final situacao = _intFrom(row['situacao']);
                                  final meuUsuario = uuid != null &&
                                      uuid == FFAppState().UserUuid.trim();

                                  return Padding(
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 0.0, 12.0),
                                    child: Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                        border: Border.all(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    valueOrDefault<String>(
                                                      row['nome']?.toString(),
                                                      '—',
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyLarge
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                          fontSize: 16.0,
                                                        ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(
                                                            0.0, 2.0, 0.0, 0.0),
                                                    child: Text(
                                                      valueOrDefault<String>(
                                                        row['email']
                                                            ?.toString(),
                                                        'Sem e-mail',
                                                      ),
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodyMedium
                                                              .override(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 14.0,
                                                              ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(
                                                            0.0, 4.0, 0.0, 0.0),
                                                    child: Text(
                                                      'Cargo: ${valueOrDefault<String>(row['cargo']?.toString(), '—')} · Registro: ${valueOrDefault<String>(row['registro_profissional']?.toString(), '—')}',
                                                      style:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .bodySmall
                                                              .override(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 12.0,
                                                              ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsetsDirectional
                                                            .fromSTEB(
                                                            0.0, 6.0, 0.0, 0.0),
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          _formatarTipo(
                                                            row['type']
                                                                ?.toString(),
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primary,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                            width: 8.0),
                                                        Container(
                                                          padding:
                                                              const EdgeInsets
                                                                  .symmetric(
                                                            horizontal: 8.0,
                                                            vertical: 2.0,
                                                          ),
                                                          decoration:
                                                              BoxDecoration(
                                                            color: _corStatus(
                                                                context,
                                                                situacao),
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        8.0),
                                                          ),
                                                          child: Text(
                                                            _rotuloStatus(
                                                                situacao),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodySmall
                                                                .override(
                                                                  color: situacao ==
                                                                          0
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryBackground,
                                                                  fontSize:
                                                                      11.0,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (temIdentificador)
                                              Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  IconButton(
                                                    tooltip: 'Detalhes',
                                                    icon: Icon(
                                                      Icons.visibility_outlined,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      size: 22.0,
                                                    ),
                                                    onPressed: () async {
                                                      context.pushNamed(
                                                        UsuarioDetalhesWidget
                                                            .routeName,
                                                        queryParameters: {
                                                          'usuarioUuid':
                                                              serializeParam(
                                                            identificador,
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
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      size: 22.0,
                                                    ),
                                                    onPressed: () async {
                                                      context.pushNamed(
                                                        CadastrarUsuarioWidget
                                                            .routeName,
                                                        queryParameters: {
                                                          'usuarioUuid':
                                                              serializeParam(
                                                            identificador,
                                                            ParamType.String,
                                                          ),
                                                        }.withoutNulls,
                                                      );
                                                    },
                                                  ),
                                                  if (!meuUsuario)
                                                    IconButton(
                                                      tooltip: 'Apagar',
                                                      icon: Icon(
                                                        Icons.delete_outline,
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .error,
                                                        size: 22.0,
                                                      ),
                                                      onPressed: () async {
                                                        final confirmar =
                                                            await showDialog<
                                                                bool>(
                                                          context: context,
                                                          builder: (ctx) =>
                                                              AlertDialog(
                                                            title: const Text(
                                                                'Apagar usuário'),
                                                            content: Text(
                                                              'Deseja apagar o usuário "${row['nome']?.toString() ?? ''}"? '
                                                              'Ele deixará de aparecer na lista.',
                                                            ),
                                                            actions: [
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            ctx)
                                                                        .pop(
                                                                            false),
                                                                child: const Text(
                                                                    'Cancelar'),
                                                              ),
                                                              TextButton(
                                                                onPressed: () =>
                                                                    Navigator.of(
                                                                            ctx)
                                                                        .pop(
                                                                            true),
                                                                child: Text(
                                                                  'Apagar',
                                                                  style:
                                                                      TextStyle(
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
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
                                                            await ExcluirUsuarioCall
                                                                .call(
                                                          id: idServidor,
                                                          usuarioUuid:
                                                              uuid ?? '',
                                                          token: FFAppState()
                                                              .UserToken,
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
                                                              content:
                                                                  const Text(
                                                                'Usuário apagado',
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
                                                                    ? resp
                                                                        .bodyText
                                                                    : 'Erro ao apagar usuário',
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
                      ),
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
}

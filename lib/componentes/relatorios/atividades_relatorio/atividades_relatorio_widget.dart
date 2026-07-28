import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_atividade_relatorio/cofirma_exclusao_atividade_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'atividades_relatorio_model.dart';
export 'atividades_relatorio_model.dart';

String _statusAtividadeLabel(int situacao) {
  switch (situacao) {
    case 1:
      return 'Em andamento';
    case 0:
      return 'Paralizada';
    case 2:
      return 'Concluída';
    default:
      return 'Status ($situacao)';
  }
}

/// crie para mim um componente chamado atividades, ele vai listar atividades
/// realizadas de um relatorio de rdo, cada atividade vai ter um titulo
/// algumas vão ter como referencia uma etapa as que nao tiverem etapa serão
/// avulsas preciso que apareça a quantidade realizada da atividade a situação
/// dela e botões para editar, ver e apagar atividade
class AtividadesRelatorioWidget extends StatefulWidget {
  const AtividadesRelatorioWidget({
    super.key,
    required this.relatorioId,
    required this.relatorioUuid,
    required this.obraUuid,
  });

  final int? relatorioId;
  final String? relatorioUuid;
  final String? obraUuid;

  @override
  State<AtividadesRelatorioWidget> createState() =>
      _AtividadesRelatorioWidgetState();
}

class _AtividadesRelatorioWidgetState extends State<AtividadesRelatorioWidget> {
  late AtividadesRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AtividadesRelatorioModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: FutureBuilder<List<RelatorioDetalhesRow>>(
        future: SQLiteManager.instance.relatorioDetalhes(
          uuid: widget!.relatorioId!.toString(),
          userUuid: FFAppState().creatorId.toString(),
          accountOwnerUuid: FFAppState().creatorUuid,
        ),
        builder: (context, snapshot) {
          // Customize what your widget looks like when it's loading.
          if (!snapshot.hasData) {
            return Center(
              child: LinearProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            );
          }
          final containerRelatorioDetalhesRowList = snapshot.data!;

          return Container(
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              boxShadow: [
                BoxShadow(
                  blurRadius: 3.0,
                  color: Color(0x33000000),
                  offset: Offset(
                    0.0,
                    1.0,
                  ),
                  spreadRadius: 0.0,
                )
              ],
              borderRadius: BorderRadius.circular(12.0),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<List<GetAtividadesRelatorioRow>>(
                        future: SQLiteManager.instance.getAtividadesRelatorio(
                          relatorioUuid: widget!.relatorioUuid!,
                        ),
                        builder: (context, snapshot) {
                          // Customize what your widget looks like when it's loading.
                          if (!snapshot.hasData) {
                            return Center(
                              child: LinearProgressIndicator(
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            );
                          }
                          final listViewGetAtividadesRelatorioRowList =
                              snapshot.data!;

                          return ListView.builder(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            itemCount:
                                listViewGetAtividadesRelatorioRowList.length,
                            itemBuilder: (context, listViewIndex) {
                              final listViewGetAtividadesRelatorioRow =
                                  listViewGetAtividadesRelatorioRowList[
                                      listViewIndex];
                              return Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 4.0, 0.0, 4.0),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color:
                                        FlutterFlowTheme.of(context).primaryBackground,
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        4.0, 4.0, 4.0, 4.0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    valueOrDefault<String>(
                                                      listViewGetAtividadesRelatorioRow
                                                          .descricao,
                                                      'N/A',
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .titleMedium
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleMedium
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleMedium
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                  Text(
                                                    'Local: ${listViewGetAtividadesRelatorioRow.local}',
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .labelMedium
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelMedium
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primary,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(4.0, 6.0, 4.0, 6.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .success,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          10.0),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(6.0, 3.0, 6.0, 3.0),
                                                  child: Text(
                                                    _statusAtividadeLabel(
                                                      listViewGetAtividadesRelatorioRow
                                                          .situacao,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .labelSmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelSmall
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .labelSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .info,
                                                          letterSpacing: 0.0,
                                                          fontSize: 10.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelSmall
                                                                  .fontStyle,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Realizado: ${valueOrDefault<String>(
                                                listViewGetAtividadesRelatorioRow
                                                    .qtdRealizada
                                                    ?.toString(),
                                                '0',
                                              )}${listViewGetAtividadesRelatorioRow.unidade}',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
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
                                            Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                if (responsiveVisibility(
                                                  context: context,
                                                  phone: false,
                                                  tablet: false,
                                                  tabletLandscape: false,
                                                  desktop: false,
                                                ))
                                                  FlutterFlowIconButton(
                                                    borderColor:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .alternate,
                                                    borderRadius: 16.0,
                                                    borderWidth: 1.0,
                                                    buttonSize: 32.0,
                                                    fillColor: FlutterFlowTheme
                                                            .of(context)
                                                        .secondaryBackground,
                                                    icon: Icon(
                                                      Icons.visibility,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      size: 16.0,
                                                    ),
                                                    onPressed: () {
                                                      print(
                                                          'IconButton pressed ...');
                                                    },
                                                  ),
                                                FlutterFlowIconButton(
                                                  borderColor: Colors.transparent,
                                                  borderRadius: 14.0,
                                                  borderWidth: 0.0,
                                                  buttonSize: 28.0,
                                                  fillColor: Colors.transparent,
                                                  icon: Icon(
                                                    Icons.edit,
                                                    color: Colors.black,
                                                    size: 16.0,
                                                  ),
                                                  onPressed: () async {
                                                    context.pushNamed(
                                                      AddAtividadeRelatorioWidget
                                                          .routeName,
                                                      queryParameters: {
                                                        'relatorioId':
                                                            serializeParam(
                                                          widget!.relatorioId,
                                                          ParamType.int,
                                                        ),
                                                        'obraId':
                                                            serializeParam(
                                                          containerRelatorioDetalhesRowList
                                                              .firstOrNull
                                                              ?.obraId,
                                                          ParamType.int,
                                                        ),
                                                        'atividadeId':
                                                            serializeParam(
                                                          listViewGetAtividadesRelatorioRow
                                                              .id,
                                                          ParamType.int,
                                                        ),
                                                        'atividadeUuid':
                                                            serializeParam(
                                                          listViewGetAtividadesRelatorioRow
                                                              .uuid,
                                                          ParamType.String,
                                                        ),
                                                        'relatorioUuid':
                                                            serializeParam(
                                                          widget!.relatorioUuid,
                                                          ParamType.String,
                                                        ),
                                                        'obraUuid':
                                                            serializeParam(
                                                          widget!.obraUuid,
                                                          ParamType.String,
                                                        ),
                                                      }.withoutNulls,
                                                    );
                                                  },
                                                ),
                                                Builder(
                                                  builder: (context) =>
                                                      FlutterFlowIconButton(
                                                    borderColor: Colors.transparent,
                                                    borderRadius: 14.0,
                                                    borderWidth: 0.0,
                                                    buttonSize: 28.0,
                                                    fillColor: Colors.transparent,
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 16.0,
                                                    ),
                                                    onPressed: () async {
                                                      await showDialog(
                                                        context: context,
                                                        builder:
                                                            (dialogContext) {
                                                          return Dialog(
                                                            elevation: 0,
                                                            insetPadding:
                                                                EdgeInsets.zero,
                                                            backgroundColor:
                                                                Colors
                                                                    .transparent,
                                                            alignment: AlignmentDirectional(
                                                                    0.0, 0.0)
                                                                .resolve(
                                                                    Directionality.of(
                                                                        context)),
                                                            child:
                                                                CofirmaExclusaoAtividadeRelatorioWidget(
                                                              itemID:
                                                                  listViewGetAtividadesRelatorioRow
                                                                      .id,
                                                            ),
                                                          );
                                                        },
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ].divide(SizedBox(width: 8.0)),
                                            ),
                                          ],
                                        ),
                                      ].divide(SizedBox(height: 8.0)),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ].divide(SizedBox(height: 12.0)),
                  ),
                ].divide(SizedBox(height: 16.0)),
              ),
            ),
          );
        },
      ),
    );
  }
}

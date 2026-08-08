import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_anexo_relatorio/cofirma_exclusao_anexo_relatorio_widget.dart';
import '/componentes/dialogs/editar_nome_anexo_relatorio/editar_nome_anexo_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'anexos_relatorios_model.dart';
export 'anexos_relatorios_model.dart';

/// crie para mim um componente chamado anexos, ele vai listar arquivos
/// anexados a um relatorio de rdo cada item vai ter uma descrição um icone
/// indicando que é um arquivo, um botão de download um de alterar descrição e
/// outro de excluir
class AnexosRelatoriosWidget extends StatefulWidget {
  const AnexosRelatoriosWidget({
    super.key,
    required this.relatorioUuid,
  });

  final String? relatorioUuid;

  @override
  State<AnexosRelatoriosWidget> createState() => _AnexosRelatoriosWidgetState();
}

class _AnexosRelatoriosWidgetState extends State<AnexosRelatoriosWidget> {
  late AnexosRelatoriosModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AnexosRelatoriosModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<List<CarregaAnexosRelatorioRow>>(
                    future: SQLiteManager.instance.carregaAnexosRelatorio(
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
                      final listViewCarregaAnexosRelatorioRowList =
                          snapshot.data!;

                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        itemCount: listViewCarregaAnexosRelatorioRowList.length,
                        itemBuilder: (context, listViewIndex) {
                          final listViewCarregaAnexosRelatorioRow =
                              listViewCarregaAnexosRelatorioRowList[
                                  listViewIndex];
                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  12.0, 12.0, 12.0, 12.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Icon(
                                          Icons.description,
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          size: 24.0,
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                valueOrDefault<String>(
                                                  listViewCarregaAnexosRelatorioRow
                                                      .nome,
                                                  'N/A',
                                                ),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .labelSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
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
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      letterSpacing: 0.0,
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
                                            ],
                                          ),
                                        ),
                                      ].divide(SizedBox(width: 12.0)),
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      FlutterFlowIconButton(
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderRadius: 6.0,
                                        borderWidth: 1.0,
                                        buttonSize: 32.0,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        icon: Icon(
                                          Icons.edit_outlined,
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          size: 16.0,
                                        ),
                                        onPressed: () async {
                                          await showDialog(
                                            context: context,
                                            builder: (dialogContext) {
                                              return Dialog(
                                                elevation: 0,
                                                backgroundColor:
                                                    Colors.transparent,
                                                child:
                                                    EditarNomeAnexoRelatorioWidget(
                                                  anexoUuid:
                                                      listViewCarregaAnexosRelatorioRow
                                                          .uuid,
                                                  nomeInicial:
                                                      listViewCarregaAnexosRelatorioRow
                                                          .nome,
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                      FlutterFlowIconButton(
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderRadius: 6.0,
                                        borderWidth: 1.0,
                                        buttonSize: 32.0,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        icon: Icon(
                                          Icons.download,
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          size: 16.0,
                                        ),
                                        onPressed: () {
                                          print('IconButton pressed ...');
                                        },
                                      ),
                                      Builder(
                                        builder: (context) =>
                                            FlutterFlowIconButton(
                                          borderColor:
                                              FlutterFlowTheme.of(context)
                                                  .alternate,
                                          borderRadius: 6.0,
                                          borderWidth: 1.0,
                                          buttonSize: 32.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .secondaryBackground,
                                          icon: Icon(
                                            Icons.delete,
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            size: 16.0,
                                          ),
                                          onPressed: () async {
                                            await showDialog(
                                              context: context,
                                              builder: (dialogContext) {
                                                return Dialog(
                                                  elevation: 0,
                                                  insetPadding: EdgeInsets.zero,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  alignment:
                                                      AlignmentDirectional(
                                                              0.0, 0.0)
                                                          .resolve(
                                                              Directionality.of(
                                                                  context)),
                                                  child:
                                                      CofirmaExclusaoAnexoRelatorioWidget(
                                                    uuid:
                                                        listViewCarregaAnexosRelatorioRow
                                                            .uuid,
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
                            ),
                          );
                        },
                      );
                    },
                  ),
                ].divide(SizedBox(height: 8.0)),
              ),
            ].divide(SizedBox(height: 12.0)),
          ),
        ),
      ),
    );
  }
}

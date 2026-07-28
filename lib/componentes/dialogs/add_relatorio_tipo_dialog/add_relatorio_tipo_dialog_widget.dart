import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'add_relatorio_tipo_dialog_model.dart';
export 'add_relatorio_tipo_dialog_model.dart';

/// Create a component com dois botões um vai ser para avulso e outro vai ser
/// escrito por etapa
class AddRelatorioTipoDialogWidget extends StatefulWidget {
  const AddRelatorioTipoDialogWidget({
    super.key,
    int? relatorioID,
    required this.obraId,
    required this.relatorioUuid,
    required this.obraUuid,
  }) : this.relatorioID = relatorioID ?? 0;

  final int relatorioID;
  final int? obraId;
  final String? relatorioUuid;
  final String? obraUuid;

  @override
  State<AddRelatorioTipoDialogWidget> createState() =>
      _AddRelatorioTipoDialogWidgetState();
}

class _AddRelatorioTipoDialogWidgetState
    extends State<AddRelatorioTipoDialogWidget> {
  late AddRelatorioTipoDialogModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddRelatorioTipoDialogModel());
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
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
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
            padding: EdgeInsets.all(12.0),
            child: Row(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FFButtonWidget(
                    onPressed: () async {
                      _model.relatorioDetalhes =
                          await SQLiteManager.instance.relatorioDetalhes(
                        uuid: widget!.relatorioUuid!,
                        userUuid: FFAppState().creatorUuid,
                        accountOwnerUuid: FFAppState().creatorUuid,
                      );
                      _model.uuid = await actions.generateUuid();
                      await SQLiteManager.instance.insertAtividadeRelatorio(
                        userId: FFAppState().UserID,
                        relatorioId: widget!.relatorioID,
                        createdBy: FFAppState().creatorUuid,
                        local: '',
                        descricao: '',
                        quantidade: 0,
                        unidade: '',
                        item: '',
                        tarefaId: null,
                        relatorioUuid:
                            _model.relatorioDetalhes?.firstOrNull?.uuid,
                        uuid: _model.uuid!,
                        userUuid: FFAppState().creatorUuid,
                        tarefaUuid: '',
                      );
                      _model.atividadeResult = await SQLiteManager.instance
                          .carregaUltimaAtividadeRelatorio();

                      final relDet = _model.relatorioDetalhes?.firstOrNull;

                      if (!context.mounted) return;
                      context.pushNamed(
                        AddAtividadeRelatorioWidget.routeName,
                        queryParameters: {
                          'relatorioId': serializeParam(
                            widget!.relatorioID,
                            ParamType.int,
                          ),
                          'obraId': serializeParam(
                            relDet?.obraId ?? widget!.obraId,
                            ParamType.int,
                          ),
                          'atividadeId': serializeParam(
                            _model.atividadeResult?.firstOrNull?.id,
                            ParamType.int,
                          ),
                          'atividadeUuid': serializeParam(
                            _model.atividadeResult?.firstOrNull?.uuid,
                            ParamType.String,
                          ),
                          'relatorioUuid': serializeParam(
                            relDet?.uuid ?? widget!.relatorioUuid,
                            ParamType.String,
                          ),
                          'obraUuid': serializeParam(
                            relDet?.obraUuid ?? widget!.obraUuid,
                            ParamType.String,
                          ),
                        }.withoutNulls,
                        extra: <String, dynamic>{
                          '__transition_info__': TransitionInfo(
                            hasTransition: true,
                            transitionType: PageTransitionType.bottomToTop,
                          ),
                        },
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                      }

                      safeSetState(() {});
                    },
                    text: 'Avulso',
                    options: FFButtonOptions(
                      height: 48.0,
                      padding: EdgeInsets.all(8.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).primary,
                      textStyle:
                          FlutterFlowTheme.of(context).titleSmall.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).info,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontStyle,
                              ),
                      elevation: 0.0,
                      borderSide: BorderSide(
                        color: Colors.transparent,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
                Expanded(
                  child: FFButtonWidget(
                    onPressed: () async {
                      final rows =
                          await SQLiteManager.instance.relatorioDetalhes(
                        uuid: widget!.relatorioUuid!,
                        userUuid: FFAppState().creatorUuid,
                        accountOwnerUuid: FFAppState().creatorUuid,
                      );
                      final d = rows.firstOrNull;
                      if (d == null) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Não foi possível localizar a obra do relatório.'),
                          ),
                        );
                        return;
                      }
                      if (!context.mounted) return;
                      await context.pushNamed(
                        SelecionarTarefaAtividadeWidget.routeName,
                        queryParameters: {
                          'relatorioID': serializeParam(
                            widget!.relatorioID,
                            ParamType.int,
                          ),
                          'obraId': serializeParam(
                            d.obraId,
                            ParamType.int,
                          ),
                          'relatorioUuid': serializeParam(
                            d.uuid ?? widget!.relatorioUuid,
                            ParamType.String,
                          ),
                          'obraUuid': serializeParam(
                            d.obraUuid,
                            ParamType.String,
                          ),
                        }.withoutNulls,
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        safeSetState(() {});
                      }
                    },
                    text: 'Por Etapa',
                    options: FFButtonOptions(
                      height: 48.0,
                      padding: EdgeInsets.all(8.0),
                      iconPadding:
                          EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      textStyle:
                          FlutterFlowTheme.of(context).titleSmall.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primary,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontStyle,
                              ),
                      elevation: 0.0,
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).primary,
                        width: 1.0,
                      ),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
              ].divide(SizedBox(width: 12.0)),
            ),
          ),
        ),
      ),
    );
  }
}

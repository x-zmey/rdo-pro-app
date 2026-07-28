import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'add_ordens_custo_relatorio_model.dart';
export 'add_ordens_custo_relatorio_model.dart';

/// cria para mim um componente que vai ter uma listagem de diversas ordems de
/// serviço mostrando descrição e codigo de cada ordem e data de periodo
/// inicial e final da ordem como também situação da ordem em cada linha e ao
/// lado quantos itens de custos tem cada ordem, tbm tem que ter uma opção de
/// selecionar varias dessas ordens e depois botão de adicionar ordens ou
/// cancelar
class AddOrdensCustoRelatorioWidget extends StatefulWidget {
  const AddOrdensCustoRelatorioWidget({
    super.key,
    required this.obraUuid,
    required this.userUuid,
    required this.relatorioUuid,
    required this.uuid,
  });

  final String? obraUuid;
  final String? userUuid;
  final String? relatorioUuid;
  final String? uuid;

  @override
  State<AddOrdensCustoRelatorioWidget> createState() =>
      _AddOrdensCustoRelatorioWidgetState();
}

class _AddOrdensCustoRelatorioWidgetState
    extends State<AddOrdensCustoRelatorioWidget> {
  late AddOrdensCustoRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddOrdensCustoRelatorioModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  Future<void> _vincularOrdemSelecionada() async {
    final ordemUuid =
        (_model.ordemSelected ?? _model.dropDownValue ?? '').trim();
    if (ordemUuid.isEmpty || ordemUuid == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecione uma ordem de serviço.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
      return;
    }

    await actions.inserirOrdemServicoNoRelatorio(
      0,
      widget.relatorioUuid!,
      0,
      ordemUuid,
      '',
      FFAppState().creatorId,
      FFAppState().creatorUuid,
      1.0,
    );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Ordem de Serviço vinculada',
          style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
        ),
        duration: const Duration(milliseconds: 4000),
        backgroundColor: FlutterFlowTheme.of(context).secondary,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            boxShadow: [
              BoxShadow(
                blurRadius: 4.0,
                color: Color(0x33000000),
                offset: Offset(
                  0.0,
                  2.0,
                ),
                spreadRadius: 0.0,
              )
            ],
            borderRadius: BorderRadius.circular(12.0),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ordens de Serviço',
                      style:
                          FlutterFlowTheme.of(context).headlineMedium.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                              ),
                    ),
                  ],
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FutureBuilder<List<GetOrdensServicoRow>>(
                      future: SQLiteManager.instance.getOrdensServico(
                        obraUuid: widget!.obraUuid!,
                        userId: FFAppState().creatorId,
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
                        final dropDownGetOrdensServicoRowList = snapshot.data!;

                        return FlutterFlowDropDown<String>(
                          controller: _model.dropDownValueController ??=
                              FormFieldController<String>(
                            _model.dropDownValue ??= '0',
                          ),
                          options:
                              List<String>.from(dropDownGetOrdensServicoRowList
                                  .map((e) => valueOrDefault<String>(
                                        e.uuid,
                                        '0',
                                      ))
                                  .toList()),
                          optionLabels: dropDownGetOrdensServicoRowList
                              .map((e) {
                                final codigo =
                                    valueOrDefault<String>(e.codigo, '')
                                        .trim();
                                final nome = (e.nome ?? '').trim();
                                if (nome.isEmpty) {
                                  return codigo.isEmpty
                                      ? 'Não informado'
                                      : codigo;
                                }
                                if (codigo.isEmpty) return nome;
                                return '$codigo — $nome';
                              })
                              .toList(),
                          onChanged: (val) {
                            safeSetState(() {
                              _model.dropDownValue = val;
                              _model.ordemSelected = val;
                            });
                          },
                          width: double.infinity,
                          height: 56.0,
                          textStyle:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                          hintText: 'Selecione Ordem',
                          fillColor:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          elevation: 0.0,
                          borderColor: FlutterFlowTheme.of(context).alternate,
                          borderWidth: 1.0,
                          borderRadius: 8.0,
                          margin: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, 0.0),
                          isSearchable: false,
                          isMultiSelect: false,
                        );
                      },
                    ),
                  ].divide(SizedBox(height: 8.0)),
                ),
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FFButtonWidget(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      text: 'Cancelar',
                      options: FFButtonOptions(
                        width: 120.0,
                        height: 44.0,
                        padding: EdgeInsets.all(8.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: FlutterFlowTheme.of(context).secondaryBackground,
                        textStyle:
                            FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                        elevation: 0.0,
                        borderSide: BorderSide(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1.0,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    FFButtonWidget(
                      onPressed: () async {
                        await _vincularOrdemSelecionada();
                      },
                      text: 'Adicionar Ordem',
                      options: FFButtonOptions(
                        width: 160.0,
                        height: 44.0,
                        padding: EdgeInsets.all(8.0),
                        iconPadding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                        color: FlutterFlowTheme.of(context).primary,
                        textStyle:
                            FlutterFlowTheme.of(context).bodyMedium.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .fontStyle,
                                  ),
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .fontStyle,
                                ),
                        elevation: 0.0,
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                  ].divide(SizedBox(width: 12.0)),
                ),
              ].divide(SizedBox(height: 16.0)),
            ),
          ),
        ),
      ),
    );
  }
}

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/app_state.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Diálogo para alterar apenas o nome exibido do anexo (metadado local / sync).
class EditarNomeAnexoRelatorioWidget extends StatefulWidget {
  const EditarNomeAnexoRelatorioWidget({
    super.key,
    required this.anexoUuid,
    required this.nomeInicial,
  });

  final String anexoUuid;
  final String? nomeInicial;

  @override
  State<EditarNomeAnexoRelatorioWidget> createState() =>
      _EditarNomeAnexoRelatorioWidgetState();
}

class _EditarNomeAnexoRelatorioWidgetState
    extends State<EditarNomeAnexoRelatorioWidget> {
  late final TextEditingController _nomeController;
  final FocusNode _nomeFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _nomeController = TextEditingController(
      text: (widget.nomeInicial ?? '').trim(),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _nomeFocus.dispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final nome = _nomeController.text.trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Informe o nome do anexo.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    await SQLiteManager.instance.updateAnexoRelatorioNome(
      uuid: widget.anexoUuid,
      nome: nome,
    );
    if (!mounted) return;
    FFAppState().update(() {});
    final messenger = ScaffoldMessenger.of(context);
    final theme = FlutterFlowTheme.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Nome atualizado',
          style: TextStyle(
            color: theme.primaryText,
          ),
        ),
        duration: const Duration(milliseconds: 3000),
        backgroundColor: theme.secondary,
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(24, 24, 24, 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                color: const Color(0x33000000),
                offset: const Offset(0, 4),
                spreadRadius: 0,
              )
            ],
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Editar nome do anexo',
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .fontWeight,
                          fontStyle: FlutterFlowTheme.of(context)
                              .headlineSmall
                              .fontStyle,
                        ),
                        letterSpacing: 0,
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineSmall
                            .fontWeight,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineSmall
                            .fontStyle,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nomeController,
                  focusNode: _nomeFocus,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _salvar(),
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    hintText: 'Nome exibido na lista',
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).alternate,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: FlutterFlowTheme.of(context).primary,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: FlutterFlowTheme.of(context).primaryBackground,
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    FFButtonWidget(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      text: 'Cancelar',
                      options: FFButtonOptions(
                        width: 120,
                        height: 44,
                        padding: const EdgeInsets.all(8),
                        iconPadding: const EdgeInsetsDirectional.fromSTEB(
                            0, 0, 0, 0),
                        color: FlutterFlowTheme.of(context).secondaryBackground,
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
                              color: FlutterFlowTheme.of(context).secondaryText,
                              letterSpacing: 0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontStyle,
                            ),
                        elevation: 0,
                        borderSide: BorderSide(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    FFButtonWidget(
                      onPressed: _salvar,
                      text: 'Salvar',
                      options: FFButtonOptions(
                        width: 120,
                        height: 44,
                        padding: const EdgeInsets.all(8),
                        iconPadding: const EdgeInsetsDirectional.fromSTEB(
                            0, 0, 0, 0),
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
                              color: FlutterFlowTheme.of(context).info,
                              letterSpacing: 0,
                              fontWeight: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontWeight,
                              fontStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .fontStyle,
                            ),
                        elevation: 0,
                        borderSide: const BorderSide(
                          color: Colors.transparent,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

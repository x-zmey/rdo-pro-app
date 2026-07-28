import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'add_anexo_relatorio_widget.dart' show AddAnexoRelatorioWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddAnexoRelatorioModel extends FlutterFlowModel<AddAnexoRelatorioWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for TextFieldNome widget.
  FocusNode? textFieldNomeFocusNode;
  TextEditingController? textFieldNomeTextController;
  String? Function(BuildContext, String?)? textFieldNomeTextControllerValidator;
  // Stores action output result for [Custom Action - pickAndSaveFileLocal] action in Column widget.
  String? resultUploadAnexo;
  // Stores action output result for [Custom Action - generateUuid] action in Column widget.
  String? uuidResult;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldNomeFocusNode?.dispose();
    textFieldNomeTextController?.dispose();
  }
}

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'criar_relatorio_dialog_widget.dart' show CriarRelatorioDialogWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

class CriarRelatorioDialogModel
    extends FlutterFlowModel<CriarRelatorioDialogWidget> {
  ///  Local state fields for this component.

  String? modeloSelecionado;

  ///  State fields for stateful widgets in this component.

  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  late MaskTextInputFormatter textFieldMask;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - SQLite (carregaUltimoRelatorio)] action in Button widget.
  List<CarregaUltimoRelatorioRow>? ultimoDetalhes;
  // Stores action output result for [Custom Action - incriseRelatorioNumero] action in Button widget.
  int? novoNumero;
  // Stores action output result for [Custom Action - generateUuid] action in Button widget.
  String? uuid;
  // Stores action output result for [Backend Call - SQLite (carregaUltimoRelatorio)] action in Button widget.
  List<CarregaUltimoRelatorioRow>? relatorioDetalhes;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}

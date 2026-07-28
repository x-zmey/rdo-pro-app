import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import 'add_atividade_avulsa_relatorio_dialog_widget.dart'
    show AddAtividadeAvulsaRelatorioDialogWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddAtividadeAvulsaRelatorioDialogModel
    extends FlutterFlowModel<AddAtividadeAvulsaRelatorioDialogWidget> {
  ///  State fields for stateful widgets in this component.

  final formKey = GlobalKey<FormState>();
  // State field(s) for TextFieldLocal widget.
  FocusNode? textFieldLocalFocusNode;
  TextEditingController? textFieldLocalTextController;
  String? Function(BuildContext, String?)?
      textFieldLocalTextControllerValidator;
  // State field(s) for TextFieldDescricao widget.
  FocusNode? textFieldDescricaoFocusNode;
  TextEditingController? textFieldDescricaoTextController;
  String? Function(BuildContext, String?)?
      textFieldDescricaoTextControllerValidator;
  // State field(s) for TextFieldQtd widget.
  FocusNode? textFieldQtdFocusNode;
  TextEditingController? textFieldQtdTextController;
  String? Function(BuildContext, String?)? textFieldQtdTextControllerValidator;
  // State field(s) for TextFieldUnidade widget.
  FocusNode? textFieldUnidadeFocusNode;
  TextEditingController? textFieldUnidadeTextController;
  String? Function(BuildContext, String?)?
      textFieldUnidadeTextControllerValidator;
  // State field(s) for TextFieldQtdRealizada widget.
  FocusNode? textFieldQtdRealizadaFocusNode;
  TextEditingController? textFieldQtdRealizadaTextController;
  String? Function(BuildContext, String?)?
      textFieldQtdRealizadaTextControllerValidator;
  // State field(s) for DropDownStatus widget.
  String? dropDownStatusValue;
  FormFieldController<String>? dropDownStatusValueController;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldLocalFocusNode?.dispose();
    textFieldLocalTextController?.dispose();

    textFieldDescricaoFocusNode?.dispose();
    textFieldDescricaoTextController?.dispose();

    textFieldQtdFocusNode?.dispose();
    textFieldQtdTextController?.dispose();

    textFieldUnidadeFocusNode?.dispose();
    textFieldUnidadeTextController?.dispose();

    textFieldQtdRealizadaFocusNode?.dispose();
    textFieldQtdRealizadaTextController?.dispose();
  }
}

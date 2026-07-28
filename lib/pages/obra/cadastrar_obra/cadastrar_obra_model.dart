import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'cadastrar_obra_widget.dart' show CadastrarObraWidget;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

class CadastrarObraModel extends FlutterFlowModel<CadastrarObraWidget> {
  ///  Local state fields for this page.

  String? grupoSelected;

  String? clienteSelected;

  String? estadoSelected;

  /// Foto opcional enviada no `POST /api/obras` (multipart), como em [EditarObraWidget].
  FFUploadedFile? novaFotoObra;

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for DropDownGrupos widget.
  String? dropDownGruposValue;
  FormFieldController<String>? dropDownGruposValueController;
  // State field(s) for DropDownClientes widget.
  String? dropDownClientesValue;
  FormFieldController<String>? dropDownClientesValueController;
  // State field(s) for TextFieldNome widget.
  FocusNode? textFieldNomeFocusNode;
  TextEditingController? textFieldNomeTextController;
  String? Function(BuildContext, String?)? textFieldNomeTextControllerValidator;
  // State field(s) for TextFieldRua widget.
  FocusNode? textFieldRuaFocusNode;
  TextEditingController? textFieldRuaTextController;
  String? Function(BuildContext, String?)? textFieldRuaTextControllerValidator;
  // State field(s) for TextFieldNumero widget.
  FocusNode? textFieldNumeroFocusNode;
  TextEditingController? textFieldNumeroTextController;
  String? Function(BuildContext, String?)?
      textFieldNumeroTextControllerValidator;
  // State field(s) for TextFieldComplemento widget.
  FocusNode? textFieldComplementoFocusNode;
  TextEditingController? textFieldComplementoTextController;
  String? Function(BuildContext, String?)?
      textFieldComplementoTextControllerValidator;
  // State field(s) for TextFieldBairro widget.
  FocusNode? textFieldBairroFocusNode;
  TextEditingController? textFieldBairroTextController;
  String? Function(BuildContext, String?)?
      textFieldBairroTextControllerValidator;
  // State field(s) for TextFieldCidade widget.
  FocusNode? textFieldCidadeFocusNode;
  TextEditingController? textFieldCidadeTextController;
  String? Function(BuildContext, String?)?
      textFieldCidadeTextControllerValidator;
  // State field(s) for DropDownEstados widget.
  String? dropDownEstadosValue;
  FormFieldController<String>? dropDownEstadosValueController;
  // State field(s) for TextFieldInicio widget.
  FocusNode? textFieldInicioFocusNode;
  TextEditingController? textFieldInicioTextController;
  late MaskTextInputFormatter textFieldInicioMask;
  String? Function(BuildContext, String?)?
      textFieldInicioTextControllerValidator;
  // State field(s) for TextFieldFim widget.
  FocusNode? textFieldFimFocusNode;
  TextEditingController? textFieldFimTextController;
  late MaskTextInputFormatter textFieldFimMask;
  String? Function(BuildContext, String?)? textFieldFimTextControllerValidator;
  // Stores action output result for [Backend Call - API (CadastrarObra)] action in Button widget.
  ApiCallResponse? apiResult0t0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldNomeFocusNode?.dispose();
    textFieldNomeTextController?.dispose();

    textFieldRuaFocusNode?.dispose();
    textFieldRuaTextController?.dispose();

    textFieldNumeroFocusNode?.dispose();
    textFieldNumeroTextController?.dispose();

    textFieldComplementoFocusNode?.dispose();
    textFieldComplementoTextController?.dispose();

    textFieldBairroFocusNode?.dispose();
    textFieldBairroTextController?.dispose();

    textFieldCidadeFocusNode?.dispose();
    textFieldCidadeTextController?.dispose();

    textFieldInicioFocusNode?.dispose();
    textFieldInicioTextController?.dispose();

    textFieldFimFocusNode?.dispose();
    textFieldFimTextController?.dispose();
  }
}

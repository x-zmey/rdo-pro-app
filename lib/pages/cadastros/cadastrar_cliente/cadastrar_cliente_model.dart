import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'cadastrar_cliente_widget.dart' show CadastrarClienteWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class CadastrarClienteModel extends FlutterFlowModel<CadastrarClienteWidget> {
  ///  Local state fields for this page.

  String tipoDocumento = 'fisica';

  String? documento;

  String? nome;

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for TextFieldCpf widget.
  FocusNode? textFieldCpfFocusNode;
  TextEditingController? textFieldCpfTextController;
  String? Function(BuildContext, String?)? textFieldCpfTextControllerValidator;
  // State field(s) for TextFieldNome widget.
  FocusNode? textFieldNomeFocusNode;
  TextEditingController? textFieldNomeTextController;
  String? Function(BuildContext, String?)? textFieldNomeTextControllerValidator;
  // State field(s) for TextFieldCnpj widget.
  FocusNode? textFieldCnpjFocusNode;
  TextEditingController? textFieldCnpjTextController;
  String? Function(BuildContext, String?)? textFieldCnpjTextControllerValidator;
  // State field(s) for TextFieldRazaoSocial widget.
  FocusNode? textFieldRazaoSocialFocusNode;
  TextEditingController? textFieldRazaoSocialTextController;
  String? Function(BuildContext, String?)?
      textFieldRazaoSocialTextControllerValidator;
  // State field(s) for TextFieldTelefone widget.
  FocusNode? textFieldTelefoneFocusNode;
  TextEditingController? textFieldTelefoneTextController;
  String? Function(BuildContext, String?)?
      textFieldTelefoneTextControllerValidator;
  // State field(s) for TextFieldEmail widget.
  FocusNode? textFieldEmailFocusNode;
  TextEditingController? textFieldEmailTextController;
  String? Function(BuildContext, String?)?
      textFieldEmailTextControllerValidator;
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
  // State field(s) for TextFieldObservacoes widget.
  FocusNode? textFieldObservacoesFocusNode;
  TextEditingController? textFieldObservacoesTextController;
  String? Function(BuildContext, String?)?
      textFieldObservacoesTextControllerValidator;
  // Stores action output result for [Backend Call - API (CadastrarCliente)] action in ButtonCadastrar widget.
  ApiCallResponse? apiResultys7;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldCpfFocusNode?.dispose();
    textFieldCpfTextController?.dispose();

    textFieldNomeFocusNode?.dispose();
    textFieldNomeTextController?.dispose();

    textFieldCnpjFocusNode?.dispose();
    textFieldCnpjTextController?.dispose();

    textFieldRazaoSocialFocusNode?.dispose();
    textFieldRazaoSocialTextController?.dispose();

    textFieldTelefoneFocusNode?.dispose();
    textFieldTelefoneTextController?.dispose();

    textFieldEmailFocusNode?.dispose();
    textFieldEmailTextController?.dispose();

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

    textFieldObservacoesFocusNode?.dispose();
    textFieldObservacoesTextController?.dispose();
  }
}

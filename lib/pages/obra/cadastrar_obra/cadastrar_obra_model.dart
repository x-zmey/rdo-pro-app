import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'cadastrar_obra_widget.dart' show CadastrarObraWidget;
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class CadastrarObraModel extends FlutterFlowModel<CadastrarObraWidget> {
  String? grupoSelected;
  String? clienteSelected;
  String? estadoSelected;

  bool salvando = false;

  /// Foto opcional enviada no `POST /api/obras` (multipart).
  FFUploadedFile? novaFotoObra;

  final formKey = GlobalKey<FormState>();

  String? dropDownGruposValue;
  FormFieldController<String>? dropDownGruposValueController;

  String? dropDownClientesValue;
  FormFieldController<String>? dropDownClientesValueController;

  FocusNode? textFieldNomeFocusNode;
  TextEditingController? textFieldNomeTextController;
  String? Function(BuildContext, String?)? textFieldNomeTextControllerValidator;

  FocusNode? textFieldRuaFocusNode;
  TextEditingController? textFieldRuaTextController;
  String? Function(BuildContext, String?)? textFieldRuaTextControllerValidator;

  FocusNode? textFieldNumeroFocusNode;
  TextEditingController? textFieldNumeroTextController;
  String? Function(BuildContext, String?)?
      textFieldNumeroTextControllerValidator;

  FocusNode? textFieldComplementoFocusNode;
  TextEditingController? textFieldComplementoTextController;
  String? Function(BuildContext, String?)?
      textFieldComplementoTextControllerValidator;

  FocusNode? textFieldBairroFocusNode;
  TextEditingController? textFieldBairroTextController;
  String? Function(BuildContext, String?)?
      textFieldBairroTextControllerValidator;

  FocusNode? textFieldCidadeFocusNode;
  TextEditingController? textFieldCidadeTextController;
  String? Function(BuildContext, String?)?
      textFieldCidadeTextControllerValidator;

  String? dropDownEstadosValue;
  FormFieldController<String>? dropDownEstadosValueController;

  FocusNode? textFieldInicioFocusNode;
  TextEditingController? textFieldInicioTextController;
  late MaskTextInputFormatter textFieldInicioMask;
  String? Function(BuildContext, String?)?
      textFieldInicioTextControllerValidator;

  FocusNode? textFieldFimFocusNode;
  TextEditingController? textFieldFimTextController;
  late MaskTextInputFormatter textFieldFimMask;
  String? Function(BuildContext, String?)? textFieldFimTextControllerValidator;

  FocusNode? textFieldContratoFocusNode;
  TextEditingController? textFieldContratoTextController;
  String? Function(BuildContext, String?)?
      textFieldContratoTextControllerValidator;

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
    textFieldContratoFocusNode?.dispose();
    textFieldContratoTextController?.dispose();
  }
}

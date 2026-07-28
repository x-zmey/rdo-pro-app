import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'editar_obra_widget.dart' show EditarObraWidget;
import 'package:flutter/material.dart';

class EditarObraModel extends FlutterFlowModel<EditarObraWidget> {
  ///  Local state fields for this page.

  int? grupoSelected;

  int? clienteSelected;

  String? grupoUuidSelected;

  String? clienteUuidSelected;

  String? estadoSelected;

  /// Preenchido uma vez a partir do SQLite (campos sem campo dedicado no form).
  bool dadosObraCarregados = false;
  String engenheiroPersistido = '';

  bool salvando = false;
  FFUploadedFile? novaFotoObra;

  ///  State fields for stateful widgets in this page.

  final formKey = GlobalKey<FormState>();
  // State field(s) for DropDownGrupos widget.
  int? dropDownGruposValue;
  FormFieldController<int>? dropDownGruposValueController;
  // State field(s) for DropDownClientes widget.
  int? dropDownClientesValue;
  FormFieldController<int>? dropDownClientesValueController;
  // State field(s) for DropDownSituacao widget.
  int? dropDownSituacaoValue;
  FormFieldController<int>? dropDownSituacaoValueController;
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
  String? Function(BuildContext, String?)?
      textFieldInicioTextControllerValidator;
  // State field(s) for TextFieldFim widget.
  FocusNode? textFieldFimFocusNode;
  TextEditingController? textFieldFimTextController;
  String? Function(BuildContext, String?)? textFieldFimTextControllerValidator;
  // State field(s) for TextFieldContrato widget.
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

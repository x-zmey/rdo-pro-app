import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/hh_mm_24h_input_formatter.dart';
import 'add_ocorrencia_relatorio_modal_widget.dart'
    show AddOcorrenciaRelatorioModalWidget;
import 'package:flutter/material.dart';

class AddOcorrenciaRelatorioModalModel
    extends FlutterFlowModel<AddOcorrenciaRelatorioModalWidget> {
  ///  Local state fields for this component.

  int? photoNumber;

  String? tipoSelecionado;

  ///  State fields for stateful widgets in this component.

  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  // Situação (1–4), alinhado ao dialog Vue.
  String? situacaoDropDownValue;
  FormFieldController<String>? situacaoDropDownValueController;
  // State field(s) for textoOcorrencia widget.
  FocusNode? textoOcorrenciaFocusNode;
  TextEditingController? textoOcorrenciaTextController;
  String? Function(BuildContext, String?)?
      textoOcorrenciaTextControllerValidator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode1;
  TextEditingController? textController2;
  late HhMm24hInputFormatter textFieldMask1;
  String? Function(BuildContext, String?)? textController2Validator;
  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode2;
  TextEditingController? textController3;
  late HhMm24hInputFormatter textFieldMask2;
  String? Function(BuildContext, String?)? textController3Validator;
  // Stores action output result for [Custom Action - generateUuid] action in Button widget.
  String? resultUuid;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textoOcorrenciaFocusNode?.dispose();
    textoOcorrenciaTextController?.dispose();

    textFieldFocusNode1?.dispose();
    textController2?.dispose();

    textFieldFocusNode2?.dispose();
    textController3?.dispose();
  }
}

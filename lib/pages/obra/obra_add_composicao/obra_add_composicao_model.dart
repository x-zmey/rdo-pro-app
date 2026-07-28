import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'obra_add_composicao_widget.dart' show ObraAddComposicaoWidget;
import 'package:flutter/material.dart';

class ObraAddComposicaoModel extends FlutterFlowModel<ObraAddComposicaoWidget> {
  final formKey = GlobalKey<FormState>();

  String? dropDownEtapaUuidValue;
  FormFieldController<String>? dropDownEtapaUuidValueController;

  String? dropDownTarefaPaiIdValue;
  FormFieldController<String>? dropDownTarefaPaiIdValueController;

  String? dropDownTipoValue;
  FormFieldController<String>? dropDownTipoValueController;

  FocusNode? itemFocusNode;
  TextEditingController? itemTextController;
  FocusNode? descricaoFocusNode;
  TextEditingController? descricaoTextController;
  FocusNode? qtdFocusNode;
  TextEditingController? qtdTextController;
  FocusNode? unidadeFocusNode;
  TextEditingController? unidadeTextController;
  FocusNode? valorUnitFocusNode;
  TextEditingController? valorUnitTextController;
  FocusNode? metaFocusNode;
  TextEditingController? metaTextController;
  FocusNode? metaUnidadeFocusNode;
  TextEditingController? metaUnidadeTextController;

  bool salvando = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    itemFocusNode?.dispose();
    itemTextController?.dispose();
    descricaoFocusNode?.dispose();
    descricaoTextController?.dispose();
    qtdFocusNode?.dispose();
    qtdTextController?.dispose();
    unidadeFocusNode?.dispose();
    unidadeTextController?.dispose();
    valorUnitFocusNode?.dispose();
    valorUnitTextController?.dispose();
    metaFocusNode?.dispose();
    metaTextController?.dispose();
    metaUnidadeFocusNode?.dispose();
    metaUnidadeTextController?.dispose();
  }
}

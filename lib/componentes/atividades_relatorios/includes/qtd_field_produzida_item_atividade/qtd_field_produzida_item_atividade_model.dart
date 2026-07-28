import '/flutter_flow/flutter_flow_util.dart';
import 'qtd_field_produzida_item_atividade_widget.dart'
    show QtdFieldProduzidaItemAtividadeWidget;
import 'package:flutter/material.dart';

class QtdFieldProduzidaItemAtividadeModel
    extends FlutterFlowModel<QtdFieldProduzidaItemAtividadeWidget> {
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}

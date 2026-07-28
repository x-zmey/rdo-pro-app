import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

import 'inicio_widget.dart' show InicioWidget;

class InicioModel extends FlutterFlowModel<InicioWidget> {
  TextEditingController? textControllerBusca;
  FocusNode? textFieldBuscaFocusNode;

  @override
  void initState(BuildContext context) {
    textControllerBusca = TextEditingController();
    textFieldBuscaFocusNode = FocusNode();
  }

  @override
  void dispose() {
    textFieldBuscaFocusNode?.dispose();
    textControllerBusca?.dispose();
  }
}

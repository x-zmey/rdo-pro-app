import '/flutter_flow/flutter_flow_util.dart';
import 'obra_add_etapa_widget.dart' show ObraAddEtapaWidget;
import 'package:flutter/material.dart';

class ObraAddEtapaModel extends FlutterFlowModel<ObraAddEtapaWidget> {
  final formKey = GlobalKey<FormState>();
  FocusNode? itemFocusNode;
  TextEditingController? itemTextController;
  FocusNode? nomeFocusNode;
  TextEditingController? nomeTextController;
  bool salvando = false;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    itemFocusNode?.dispose();
    itemTextController?.dispose();
    nomeFocusNode?.dispose();
    nomeTextController?.dispose();
  }
}

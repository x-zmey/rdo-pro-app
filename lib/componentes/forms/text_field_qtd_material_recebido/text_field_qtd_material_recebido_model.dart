import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'text_field_qtd_material_recebido_widget.dart'
    show TextFieldQtdMaterialRecebidoWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class TextFieldQtdMaterialRecebidoModel
    extends FlutterFlowModel<TextFieldQtdMaterialRecebidoWidget> {
  ///  Local state fields for this component.

  int? qtdMaterialRecebido;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextFieldQtdMaterial widget.
  FocusNode? textFieldQtdMaterialFocusNode;
  TextEditingController? textFieldQtdMaterialTextController;
  String? Function(BuildContext, String?)?
      textFieldQtdMaterialTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldQtdMaterialFocusNode?.dispose();
    textFieldQtdMaterialTextController?.dispose();
  }
}

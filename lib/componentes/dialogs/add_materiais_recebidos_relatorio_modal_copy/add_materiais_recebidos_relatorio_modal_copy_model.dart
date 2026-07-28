import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'add_materiais_recebidos_relatorio_modal_copy_widget.dart'
    show AddMateriaisRecebidosRelatorioModalCopyWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddMateriaisRecebidosRelatorioModalCopyModel
    extends FlutterFlowModel<AddMateriaisRecebidosRelatorioModalCopyWidget> {
  ///  Local state fields for this component.

  String? materialSelecionado;

  ///  State fields for stateful widgets in this component.

  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  // State field(s) for qtd widget.
  FocusNode? qtdFocusNode;
  TextEditingController? qtdTextController;
  String? Function(BuildContext, String?)? qtdTextControllerValidator;
  // Stores action output result for [Custom Action - generateUuid] action in Button widget.
  String? uuidResult;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    qtdFocusNode?.dispose();
    qtdTextController?.dispose();
  }
}

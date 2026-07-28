import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'add_ordens_custo_relatorio_widget.dart'
    show AddOrdensCustoRelatorioWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddOrdensCustoRelatorioModel
    extends FlutterFlowModel<AddOrdensCustoRelatorioWidget> {
  ///  Local state fields for this component.

  String? ordemSelected;

  ///  State fields for stateful widgets in this component.

  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  // Stores action output result for [Custom Action - inserirOrdemServicoNoRelatorio] action in DropDown widget.
  String? resultOrdem;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'add_mao_obra_vinculada_widget.dart' show AddMaoObraVinculadaWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddMaoObraVinculadaModel
    extends FlutterFlowModel<AddMaoObraVinculadaWidget> {
  ///  Local state fields for this component.

  String? funcionarioSelected;

  ///  State fields for stateful widgets in this component.

  // State field(s) for DropDown widget.
  String? dropDownValue;
  FormFieldController<String>? dropDownValueController;
  // Stores action output result for [Backend Call - SQLite (relatorioDetalhes)] action in Button widget.
  List<RelatorioDetalhesRow>? relatorioResult;
  // Stores action output result for [Custom Action - generateUuid] action in Button widget.
  String? uuidResult;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'aplicar_checklist_widget.dart' show AplicarChecklistWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AplicarChecklistModel extends FlutterFlowModel<AplicarChecklistWidget> {
  ///  Local state fields for this page.

  int? modeloSelected;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Custom Action - iniciarNovoChecklist] action in Button widget.
  String? resultChecklistIniciado;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

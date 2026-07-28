import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import 'add_obra_modal_widget.dart' show AddObraModalWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddObraModalModel extends FlutterFlowModel<AddObraModalWidget> {
  ///  Local state fields for this component.

  int? photoNumber;

  ///  State fields for stateful widgets in this component.

  // State field(s) for obraNome widget.
  FocusNode? obraNomeFocusNode;
  TextEditingController? obraNomeTextController;
  String? Function(BuildContext, String?)? obraNomeTextControllerValidator;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    obraNomeFocusNode?.dispose();
    obraNomeTextController?.dispose();
  }
}

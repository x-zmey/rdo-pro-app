import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/criar_relatorio_dialog/criar_relatorio_dialog_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'detalhes_obra_widget.dart' show DetalhesObraWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class DetalhesObraModel extends FlutterFlowModel<DetalhesObraWidget> {
  ///  Local state fields for this page.

  int? idServe;

  ///  State fields for stateful widgets in this page.

  // Stores action output result for [Backend Call - SQLite (ObraDetalhes)] action in detalhesObra widget.
  List<ObraDetalhesRow>? obraDetalhes;
  // Stores action output result for [Backend Call - SQLite (getIdServidor)] action in detalhesObra widget.
  List<GetIdServidorRow>? idServidorResult;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

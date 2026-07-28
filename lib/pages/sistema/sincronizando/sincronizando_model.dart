import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'sincronizando_widget.dart' show SincronizandoWidget;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SincronizandoModel extends FlutterFlowModel<SincronizandoWidget> {
  ///  Local state fields for this page.

  int totalRealizado = 0;

  int statusSyncUsuarios = 0;

  int statusSyncProjetos = 0;

  int statusSyncRelatorios = 0;

  int statusSyncChecklists = 0;

  int statusSyncComplementos = 0;

  int statusSyncOrdensServico = 0;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

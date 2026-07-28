import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'add_relatorio_tipo_dialog_widget.dart'
    show AddRelatorioTipoDialogWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class AddRelatorioTipoDialogModel
    extends FlutterFlowModel<AddRelatorioTipoDialogWidget> {
  ///  State fields for stateful widgets in this component.

  // Stores action output result for [Backend Call - SQLite (relatorioDetalhes)] action in Button widget.
  List<RelatorioDetalhesRow>? relatorioDetalhes;
  // Stores action output result for [Custom Action - generateUuid] action in Button widget.
  String? uuid;
  // Stores action output result for [Backend Call - SQLite (carregaUltimaAtividadeRelatorio)] action in Button widget.
  List<CarregaUltimaAtividadeRelatorioRow>? atividadeResult;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {}
}

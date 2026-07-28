import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'qtd_field_mao_obra_realizado_atividade_relatorio_widget.dart'
    show QtdFieldMaoObraRealizadoAtividadeRelatorioWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class QtdFieldMaoObraRealizadoAtividadeRelatorioModel
    extends FlutterFlowModel<QtdFieldMaoObraRealizadoAtividadeRelatorioWidget> {
  ///  Local state fields for this component.

  double? newValor;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - SQLite (getDetalhesItemAtividade)] action in TextField widget.
  List<GetDetalhesItemAtividadeRow>? detalhesItem;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}

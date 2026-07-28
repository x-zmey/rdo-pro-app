import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'selecionar_tarefa_atividade_widget.dart'
    show SelecionarTarefaAtividadeWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class SelecionarTarefaAtividadeModel
    extends FlutterFlowModel<SelecionarTarefaAtividadeWidget> {
  ///  Local state fields for this page.

  String? etapaSelected;

  String? tarefaSelected;

  String? ordemSelected;

  /// Com [switchOrdemValue] true: `true` = tarefa pela lista da OS; `false` = etapa + tarefa (mantém `ordem_id`).
  bool? usarTarefaListaOrdem;

  ///  State fields for stateful widgets in this page.

  // State field(s) for SwitchOrdem widget.
  bool? switchOrdemValue;
  // State field(s) for DropDownOrdem widget.
  String? dropDownOrdemValue;
  FormFieldController<String>? dropDownOrdemValueController;
  // State field(s) for DropDownTarefasOrdem widget.
  String? dropDownTarefasOrdemValue;
  FormFieldController<String>? dropDownTarefasOrdemValueController;
  // State field(s) for DropDownEtapa widget.
  String? dropDownEtapaValue;
  FormFieldController<String>? dropDownEtapaValueController;
  // State field(s) for DropDownTarefas widget.
  String? dropDownTarefasValue;
  FormFieldController<String>? dropDownTarefasValueController;
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

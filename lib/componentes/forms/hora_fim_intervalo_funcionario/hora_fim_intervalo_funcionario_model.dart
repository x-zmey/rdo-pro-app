import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'hora_fim_intervalo_funcionario_widget.dart'
    show HoraFimIntervaloFuncionarioWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

class HoraFimIntervaloFuncionarioModel
    extends FlutterFlowModel<HoraFimIntervaloFuncionarioWidget> {
  ///  Local state fields for this component.

  DateTime? newValue;

  ///  State fields for stateful widgets in this component.

  // State field(s) for TextField widget.
  FocusNode? textFieldFocusNode;
  TextEditingController? textController;
  late MaskTextInputFormatter textFieldMask;
  String? Function(BuildContext, String?)? textControllerValidator;
  // Stores action output result for [Backend Call - SQLite (getMaoObraRelatorioDetalhes)] action in TextField widget.
  List<GetMaoObraRelatorioDetalhesRow>? maoObraDetalhes;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldFocusNode?.dispose();
    textController?.dispose();
  }
}

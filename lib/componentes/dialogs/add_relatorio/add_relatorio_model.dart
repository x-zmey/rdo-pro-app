import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'add_relatorio_widget.dart' show AddRelatorioWidget;
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

class AddRelatorioModel extends FlutterFlowModel<AddRelatorioWidget> {
  ///  State fields for stateful widgets in this component.

  // State field(s) for DropDown widget.
  int? dropDownValue;
  FormFieldController<int?>? dropDownValueController;
  // Data do relatório (dd/MM/yyyy)
  FocusNode? textFieldDataFocusNode;
  TextEditingController? textDataController;
  late MaskTextInputFormatter textFieldDataMask;
  // Stores action output result for [Backend Call - SQLite (carregaUltimoRelatorio)] action in Button widget.
  List<CarregaUltimoRelatorioRow>? id;
  List<CarregaUltimoRelatorioRow>? ultimoDetalhes;
  int? novoNumero;
  String? uuid;

  @override
  void initState(BuildContext context) {}

  @override
  void dispose() {
    textFieldDataFocusNode?.dispose();
    textDataController?.dispose();
  }
}

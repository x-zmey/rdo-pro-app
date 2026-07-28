import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/show_equipamentos_atividade_relatorio/show_equipamentos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/show_fotos_atividade/show_fotos_atividade_widget.dart';
import '/componentes/atividades_relatorios/show_insumos_atividade_relatorio/show_insumos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/show_mao_obra_atividade_relatorio/show_mao_obra_atividade_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/index.dart';
import 'show_atividade_relatorio_widget.dart' show ShowAtividadeRelatorioWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class ShowAtividadeRelatorioModel
    extends FlutterFlowModel<ShowAtividadeRelatorioWidget> {
  ///  Local state fields for this page.

  int? insumoSelected;

  int? equipamentoSelected;

  int? maoObraSelected;

  int? statusSelected;

  ///  State fields for stateful widgets in this page.

  // State field(s) for TextFieldLocal widget.
  FocusNode? textFieldLocalFocusNode;
  TextEditingController? textFieldLocalTextController;
  String? Function(BuildContext, String?)?
      textFieldLocalTextControllerValidator;
  // State field(s) for TextFieldDescricao widget.
  FocusNode? textFieldDescricaoFocusNode;
  TextEditingController? textFieldDescricaoTextController;
  String? Function(BuildContext, String?)?
      textFieldDescricaoTextControllerValidator;
  // State field(s) for TextFieldQtdRealizada widget.
  FocusNode? textFieldQtdRealizadaFocusNode;
  TextEditingController? textFieldQtdRealizadaTextController;
  String? Function(BuildContext, String?)?
      textFieldQtdRealizadaTextControllerValidator;
  // State field(s) for TextFieldUnidade widget.
  FocusNode? textFieldUnidadeFocusNode;
  TextEditingController? textFieldUnidadeTextController;
  String? Function(BuildContext, String?)?
      textFieldUnidadeTextControllerValidator;
  // State field(s) for DropDownStatus widget.
  int? dropDownStatusValue;
  FormFieldController<int>? dropDownStatusValueController;
  // Model for ShowInsumosAtividadeRelatorio component.
  late ShowInsumosAtividadeRelatorioModel showInsumosAtividadeRelatorioModel;
  // Model for ShowEquipamentosAtividadeRelatorio component.
  late ShowEquipamentosAtividadeRelatorioModel
      showEquipamentosAtividadeRelatorioModel;
  // Model for showMaoObraAtividadeRelatorio component.
  late ShowMaoObraAtividadeRelatorioModel showMaoObraAtividadeRelatorioModel;
  // Model for ShowFotosAtividade component.
  late ShowFotosAtividadeModel showFotosAtividadeModel;

  @override
  void initState(BuildContext context) {
    showInsumosAtividadeRelatorioModel =
        createModel(context, () => ShowInsumosAtividadeRelatorioModel());
    showEquipamentosAtividadeRelatorioModel =
        createModel(context, () => ShowEquipamentosAtividadeRelatorioModel());
    showMaoObraAtividadeRelatorioModel =
        createModel(context, () => ShowMaoObraAtividadeRelatorioModel());
    showFotosAtividadeModel =
        createModel(context, () => ShowFotosAtividadeModel());
  }

  @override
  void dispose() {
    textFieldLocalFocusNode?.dispose();
    textFieldLocalTextController?.dispose();

    textFieldDescricaoFocusNode?.dispose();
    textFieldDescricaoTextController?.dispose();

    textFieldQtdRealizadaFocusNode?.dispose();
    textFieldQtdRealizadaTextController?.dispose();

    textFieldUnidadeFocusNode?.dispose();
    textFieldUnidadeTextController?.dispose();

    showInsumosAtividadeRelatorioModel.dispose();
    showEquipamentosAtividadeRelatorioModel.dispose();
    showMaoObraAtividadeRelatorioModel.dispose();
    showFotosAtividadeModel.dispose();
  }
}

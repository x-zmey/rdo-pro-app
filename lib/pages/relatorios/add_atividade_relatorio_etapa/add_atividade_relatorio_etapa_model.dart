import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/equipamentos_atividade_relatorio/equipamentos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/fotos_atividade/fotos_atividade_widget.dart';
import '/componentes/atividades_relatorios/insumos_atividade_relatorio/insumos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/mao_obra_atividade_relatorio/mao_obra_atividade_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'add_atividade_relatorio_etapa_widget.dart'
    show AddAtividadeRelatorioEtapaWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';

class AddAtividadeRelatorioEtapaModel
    extends FlutterFlowModel<AddAtividadeRelatorioEtapaWidget> {
  ///  Local state fields for this page.

  String? insumoSelected;

  String? equipamentoSelected;

  String? maoObraSelected;

  int? statusSelected;

  ///  State fields for stateful widgets in this page.

  // State field(s) for SwitchOrdem widget.
  bool? switchOrdemValue;
  /// UUID da ordem de serviço (`ordens_servico.uuid`) vinculada à atividade.
  String? dropDownOrdemUuidValue;
  FormFieldController<String>? dropDownOrdemUuidValueController;
  // State field(s) for DropDownLocal (locais da obra no SQLite).
  String? dropDownLocalValue;
  FormFieldController<String>? dropDownLocalValueController;
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
  // State field(s) for DropDownInsumo widget.
  String? dropDownInsumoValue;
  FormFieldController<String>? dropDownInsumoValueController;
  // Stores action output result for [Custom Action - generateUuid] action in DropDownInsumo widget.
  String? uuidResultInsumos;
  // Model for insumosAtividadeRelatorio component.
  late InsumosAtividadeRelatorioModel insumosAtividadeRelatorioModel;
  // State field(s) for DropDownEquipamentos widget.
  String? dropDownEquipamentosValue;
  FormFieldController<String>? dropDownEquipamentosValueController;
  // Stores action output result for [Custom Action - generateUuid] action in DropDownEquipamentos widget.
  String? uuidResultEquipamentos;
  // Model for equipamentosAtividadeRelatorio component.
  late EquipamentosAtividadeRelatorioModel equipamentosAtividadeRelatorioModel;
  // State field(s) for DropDownMaoObra widget.
  String? dropDownMaoObraValue;
  FormFieldController<String>? dropDownMaoObraValueController;
  // Stores action output result for [Custom Action - generateUuid] action in DropDownMaoObra widget.
  String? uuidResultMo;
  // Model for maoObraAtividadeRelatorio component.
  late MaoObraAtividadeRelatorioModel maoObraAtividadeRelatorioModel;
  // Model for fotosAtividade component.
  late FotosAtividadeModel fotosAtividadeModel;

  @override
  void initState(BuildContext context) {
    insumosAtividadeRelatorioModel =
        createModel(context, () => InsumosAtividadeRelatorioModel());
    equipamentosAtividadeRelatorioModel =
        createModel(context, () => EquipamentosAtividadeRelatorioModel());
    maoObraAtividadeRelatorioModel =
        createModel(context, () => MaoObraAtividadeRelatorioModel());
    fotosAtividadeModel = createModel(context, () => FotosAtividadeModel());
  }

  @override
  void dispose() {
    textFieldDescricaoFocusNode?.dispose();
    textFieldDescricaoTextController?.dispose();

    textFieldQtdRealizadaFocusNode?.dispose();
    textFieldQtdRealizadaTextController?.dispose();

    textFieldUnidadeFocusNode?.dispose();
    textFieldUnidadeTextController?.dispose();

    insumosAtividadeRelatorioModel.dispose();
    equipamentosAtividadeRelatorioModel.dispose();
    maoObraAtividadeRelatorioModel.dispose();
    fotosAtividadeModel.dispose();
  }
}

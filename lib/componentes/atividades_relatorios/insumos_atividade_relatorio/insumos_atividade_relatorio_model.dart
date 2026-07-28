import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_insumo_atividade_relatorio/qtd_field_insumo_atividade_relatorio_widget.dart';
import '/componentes/dialogs/cofirma_exclusao_item_atividade/cofirma_exclusao_item_atividade_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'insumos_atividade_relatorio_widget.dart'
    show InsumosAtividadeRelatorioWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class InsumosAtividadeRelatorioModel
    extends FlutterFlowModel<InsumosAtividadeRelatorioWidget> {
  ///  State fields for stateful widgets in this component.

  // Models for qtdFieldInsumoAtividadeRelatorio dynamic component.
  late FlutterFlowDynamicModels<QtdFieldInsumoAtividadeRelatorioModel>
      qtdFieldInsumoAtividadeRelatorioModels;

  @override
  void initState(BuildContext context) {
    qtdFieldInsumoAtividadeRelatorioModels =
        FlutterFlowDynamicModels(() => QtdFieldInsumoAtividadeRelatorioModel());
  }

  @override
  void dispose() {
    qtdFieldInsumoAtividadeRelatorioModels.dispose();
  }
}

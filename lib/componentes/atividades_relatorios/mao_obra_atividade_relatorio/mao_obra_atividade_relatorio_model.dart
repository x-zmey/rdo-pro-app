import '/componentes/atividades_relatorios/includes/qtd_field_mao_obra_atividade_relatorio/qtd_field_mao_obra_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_mao_obra_realizado_atividade_relatorio/qtd_field_mao_obra_realizado_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_produzida_item_atividade/qtd_field_produzida_item_atividade_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'mao_obra_atividade_relatorio_widget.dart'
    show MaoObraAtividadeRelatorioWidget;
import 'package:flutter/material.dart';

class MaoObraAtividadeRelatorioModel
    extends FlutterFlowModel<MaoObraAtividadeRelatorioWidget> {
  late FlutterFlowDynamicModels<QtdFieldMaoObraAtividadeRelatorioModel>
      qtdFieldMaoObraAtividadeRelatorioModels;
  late FlutterFlowDynamicModels<QtdFieldMaoObraRealizadoAtividadeRelatorioModel>
      qtdFieldMaoObraRealizadoAtividadeRelatorioModels;
  late FlutterFlowDynamicModels<QtdFieldProduzidaItemAtividadeModel>
      qtdFieldProduzidaItemAtividadeModels;

  @override
  void initState(BuildContext context) {
    qtdFieldMaoObraAtividadeRelatorioModels = FlutterFlowDynamicModels(
        () => QtdFieldMaoObraAtividadeRelatorioModel());
    qtdFieldMaoObraRealizadoAtividadeRelatorioModels = FlutterFlowDynamicModels(
        () => QtdFieldMaoObraRealizadoAtividadeRelatorioModel());
    qtdFieldProduzidaItemAtividadeModels = FlutterFlowDynamicModels(
        () => QtdFieldProduzidaItemAtividadeModel());
  }

  @override
  void dispose() {
    qtdFieldMaoObraAtividadeRelatorioModels.dispose();
    qtdFieldMaoObraRealizadoAtividadeRelatorioModels.dispose();
    qtdFieldProduzidaItemAtividadeModels.dispose();
  }
}

import '/componentes/atividades_relatorios/includes/qtd_field_equipamento_atividade_relatorio/qtd_field_equipamento_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_equipamento_realizado_atividade_relatorio/qtd_field_equipamento_realizado_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_produzida_item_atividade/qtd_field_produzida_item_atividade_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'equipamentos_atividade_relatorio_widget.dart'
    show EquipamentosAtividadeRelatorioWidget;
import 'package:flutter/material.dart';

class EquipamentosAtividadeRelatorioModel
    extends FlutterFlowModel<EquipamentosAtividadeRelatorioWidget> {
  late FlutterFlowDynamicModels<QtdFieldEquipamentoAtividadeRelatorioModel>
      qtdFieldEquipamentoAtividadeRelatorioModels;
  late FlutterFlowDynamicModels<
          QtdFieldEquipamentoRealizadoAtividadeRelatorioModel>
      qtdFieldEquipamentoRealizadoAtividadeRelatorioModels;
  late FlutterFlowDynamicModels<QtdFieldProduzidaItemAtividadeModel>
      qtdFieldProduzidaItemAtividadeModels;

  @override
  void initState(BuildContext context) {
    qtdFieldEquipamentoAtividadeRelatorioModels = FlutterFlowDynamicModels(
        () => QtdFieldEquipamentoAtividadeRelatorioModel());
    qtdFieldEquipamentoRealizadoAtividadeRelatorioModels =
        FlutterFlowDynamicModels(
            () => QtdFieldEquipamentoRealizadoAtividadeRelatorioModel());
    qtdFieldProduzidaItemAtividadeModels = FlutterFlowDynamicModels(
        () => QtdFieldProduzidaItemAtividadeModel());
  }

  @override
  void dispose() {
    qtdFieldEquipamentoAtividadeRelatorioModels.dispose();
    qtdFieldEquipamentoRealizadoAtividadeRelatorioModels.dispose();
    qtdFieldProduzidaItemAtividadeModels.dispose();
  }
}

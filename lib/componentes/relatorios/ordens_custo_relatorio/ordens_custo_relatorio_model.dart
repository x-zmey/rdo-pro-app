import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_custo_relatorio/cofirma_exclusao_custo_relatorio_widget.dart';
import '/componentes/forms/qtd_custo_item_ordem_relatorio/qtd_custo_item_ordem_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'ordens_custo_relatorio_widget.dart' show OrdensCustoRelatorioWidget;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class OrdensCustoRelatorioModel
    extends FlutterFlowModel<OrdensCustoRelatorioWidget> {
  ///  State fields for stateful widgets in this component.

  // Models for qtdCustoItemOrdemRelatorio dynamic component.
  late FlutterFlowDynamicModels<QtdCustoItemOrdemRelatorioModel>
      qtdCustoItemOrdemRelatorioModels;

  @override
  void initState(BuildContext context) {
    qtdCustoItemOrdemRelatorioModels =
        FlutterFlowDynamicModels(() => QtdCustoItemOrdemRelatorioModel());
  }

  @override
  void dispose() {
    qtdCustoItemOrdemRelatorioModels.dispose();
  }
}

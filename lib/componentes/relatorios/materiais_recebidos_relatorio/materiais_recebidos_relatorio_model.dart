import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_material_recebido/cofirma_exclusao_material_recebido_widget.dart';
import '/componentes/forms/qtd_material_recebido_text/qtd_material_recebido_text_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'materiais_recebidos_relatorio_widget.dart'
    show MateriaisRecebidosRelatorioWidget;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class MateriaisRecebidosRelatorioModel
    extends FlutterFlowModel<MateriaisRecebidosRelatorioWidget> {
  ///  State fields for stateful widgets in this component.

  // Models for qtdMaterialRecebidoText dynamic component.
  late FlutterFlowDynamicModels<QtdMaterialRecebidoTextModel>
      qtdMaterialRecebidoTextModels;

  @override
  void initState(BuildContext context) {
    qtdMaterialRecebidoTextModels =
        FlutterFlowDynamicModels(() => QtdMaterialRecebidoTextModel());
  }

  @override
  void dispose() {
    qtdMaterialRecebidoTextModels.dispose();
  }
}

import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/add_anexo_relatorio/add_anexo_relatorio_widget.dart';
import '/componentes/dialogs/add_comentario_relatorio_modal/add_comentario_relatorio_modal_widget.dart';
import '/componentes/dialogs/add_mao_obra_vinculada/add_mao_obra_vinculada_widget.dart';
import '/componentes/dialogs/add_materiais_recebidos_relatorio_modal_copy/add_materiais_recebidos_relatorio_modal_copy_widget.dart';
import '/componentes/dialogs/add_ocorrencia_relatorio_modal/add_ocorrencia_relatorio_modal_widget.dart';
import '/componentes/dialogs/add_ordens_custo_relatorio/add_ordens_custo_relatorio_widget.dart';
import '/componentes/dialogs/add_relatorio_tipo_dialog/add_relatorio_tipo_dialog_widget.dart';
import '/componentes/dialogs/cofirma_exclusao_mao_obra_relatorio/cofirma_exclusao_mao_obra_relatorio_widget.dart';
import '/componentes/dialogs/concluir_relatorio_dialog/concluir_relatorio_dialog_widget.dart';
import '/componentes/relatorios/anexos_relatorios/anexos_relatorios_widget.dart';
import '/componentes/relatorios/atividades_relatorio/atividades_relatorio_widget.dart';
import '/componentes/relatorios/comentarios_relatorio/comentarios_relatorio_widget.dart';
import '/componentes/relatorios/materiais_recebidos_relatorio/materiais_recebidos_relatorio_widget.dart';
import '/componentes/relatorios/ocorrencias_relatorio/ocorrencias_relatorio_widget.dart';
import '/componentes/relatorios/ordens_custo_relatorio/ordens_custo_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/hh_mm_24h_input_formatter.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'obra_add_relatorio_widget.dart' show ObraAddRelatorioWidget;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

class ObraAddRelatorioModel extends FlutterFlowModel<ObraAddRelatorioWidget> {
  ///  State fields for stateful widgets in this page.

  // State field(s) for TextFieldNumero widget.
  FocusNode? textFieldNumeroFocusNode1;
  TextEditingController? textFieldNumeroTextController1;
  String? Function(BuildContext, String?)?
      textFieldNumeroTextController1Validator;
  // State field(s) for TextFieldData widget.
  FocusNode? textFieldDataFocusNode;
  TextEditingController? textFieldDataTextController;
  late MaskTextInputFormatter textFieldDataMask;
  String? Function(BuildContext, String?)? textFieldDataTextControllerValidator;
  // State field(s) for TextFieldNumero widget.
  FocusNode? textFieldNumeroFocusNode2;
  TextEditingController? textFieldNumeroTextController2;
  late HhMm24hInputFormatter textFieldNumeroMask2;
  String? Function(BuildContext, String?)?
      textFieldNumeroTextController2Validator;
  // State field(s) for TextFieldHoras widget.
  FocusNode? textFieldHorasFocusNode1;
  TextEditingController? textFieldHorasTextController1;
  late HhMm24hInputFormatter textFieldHorasMask1;
  String? Function(BuildContext, String?)?
      textFieldHorasTextController1Validator;
  // State field(s) for TextFieldHoras widget.
  FocusNode? textFieldHorasFocusNode2;
  TextEditingController? textFieldHorasTextController2;
  late HhMm24hInputFormatter textFieldHorasMask2;
  String? Function(BuildContext, String?)?
      textFieldHorasTextController2Validator;
  // State field(s) for TextFieldHoras widget.
  FocusNode? textFieldHorasFocusNode3;
  TextEditingController? textFieldHorasTextController3;
  late HhMm24hInputFormatter textFieldHorasMask3;
  String? Function(BuildContext, String?)?
      textFieldHorasTextController3Validator;
  // Model for materiaisRecebidosRelatorio component.
  late MateriaisRecebidosRelatorioModel materiaisRecebidosRelatorioModel;
  // Model for atividadesRelatorio component.
  late AtividadesRelatorioModel atividadesRelatorioModel;
  // Model for OrdensCustoRelatorio component.
  late OrdensCustoRelatorioModel ordensCustoRelatorioModel;
  // Model for comentariosRelatorio component.
  late ComentariosRelatorioModel comentariosRelatorioModel;
  // Model for ocorrenciasRelatorio component.
  late OcorrenciasRelatorioModel ocorrenciasRelatorioModel;
  // Model for anexosRelatorios component.
  late AnexosRelatoriosModel anexosRelatoriosModel;

  @override
  void initState(BuildContext context) {
    materiaisRecebidosRelatorioModel =
        createModel(context, () => MateriaisRecebidosRelatorioModel());
    atividadesRelatorioModel =
        createModel(context, () => AtividadesRelatorioModel());
    ordensCustoRelatorioModel =
        createModel(context, () => OrdensCustoRelatorioModel());
    comentariosRelatorioModel =
        createModel(context, () => ComentariosRelatorioModel());
    ocorrenciasRelatorioModel =
        createModel(context, () => OcorrenciasRelatorioModel());
    anexosRelatoriosModel = createModel(context, () => AnexosRelatoriosModel());
  }

  @override
  void dispose() {
    textFieldNumeroFocusNode1?.dispose();
    textFieldNumeroTextController1?.dispose();

    textFieldDataFocusNode?.dispose();
    textFieldDataTextController?.dispose();

    textFieldNumeroFocusNode2?.dispose();
    textFieldNumeroTextController2?.dispose();

    textFieldHorasFocusNode1?.dispose();
    textFieldHorasTextController1?.dispose();

    textFieldHorasFocusNode2?.dispose();
    textFieldHorasTextController2?.dispose();

    textFieldHorasFocusNode3?.dispose();
    textFieldHorasTextController3?.dispose();

    materiaisRecebidosRelatorioModel.dispose();
    atividadesRelatorioModel.dispose();
    ordensCustoRelatorioModel.dispose();
    comentariosRelatorioModel.dispose();
    ocorrenciasRelatorioModel.dispose();
    anexosRelatoriosModel.dispose();
  }
}

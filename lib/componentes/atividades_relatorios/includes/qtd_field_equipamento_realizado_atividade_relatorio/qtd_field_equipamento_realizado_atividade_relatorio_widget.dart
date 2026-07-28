import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'qtd_field_equipamento_realizado_atividade_relatorio_model.dart';
export 'qtd_field_equipamento_realizado_atividade_relatorio_model.dart';

class QtdFieldEquipamentoRealizadoAtividadeRelatorioWidget
    extends StatefulWidget {
  const QtdFieldEquipamentoRealizadoAtividadeRelatorioWidget({
    super.key,
    required this.uuid,
    required this.valor,
  });

  final String? uuid;
  final int? valor;

  @override
  State<QtdFieldEquipamentoRealizadoAtividadeRelatorioWidget> createState() =>
      _QtdFieldEquipamentoRealizadoAtividadeRelatorioWidgetState();
}

class _QtdFieldEquipamentoRealizadoAtividadeRelatorioWidgetState
    extends State<QtdFieldEquipamentoRealizadoAtividadeRelatorioWidget> {
  late QtdFieldEquipamentoRealizadoAtividadeRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
        context, () => QtdFieldEquipamentoRealizadoAtividadeRelatorioModel());

    _model.textController ??= TextEditingController(
        text: valueOrDefault<String>(
      widget!.valor?.toString(),
      '0',
    ));
    _model.textFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _model.textController,
      focusNode: _model.textFieldFocusNode,
      onChanged: (_) => EasyDebounce.debounce(
        '_model.textController',
        Duration(milliseconds: 2000),
        () async {
          _model.detalhesItem =
              await SQLiteManager.instance.getDetalhesItemAtividade(
            uuid: widget!.uuid!,
          );
          await SQLiteManager.instance.updateItemAtividade(
            qtdRealizada: int.tryParse(_model.textController.text),
            uuid: widget!.uuid!,
            qtdUtilizada: _model.detalhesItem?.firstOrNull?.qtdUtilizada,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Quantidade Atualizada',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                ),
              ),
              duration: Duration(milliseconds: 4000),
              backgroundColor: FlutterFlowTheme.of(context).primary,
            ),
          );

          safeSetState(() {});
        },
      ),
      autofocus: false,
      textInputAction: TextInputAction.done,
      obscureText: false,
      decoration: InputDecoration(
        isDense: true,
        hintText: '0',
        hintStyle: FlutterFlowTheme.of(context).bodyLarge.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
              ),
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
            ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        filled: true,
        fillColor: FlutterFlowTheme.of(context).primaryBackground,
      ),
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            font: GoogleFonts.inter(
              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            ),
            fontSize: 16.0,
            letterSpacing: 0.0,
            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
          ),
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      validator: _model.textControllerValidator.asValidator(context),
    );
  }
}

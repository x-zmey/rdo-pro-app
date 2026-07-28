import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'qtd_material_recebido_text_model.dart';
export 'qtd_material_recebido_text_model.dart';

String _formatQuantidadeExibicao(double v) {
  if (v == v.roundToDouble()) {
    return v.toInt().toString();
  }
  return v.toString();
}

class QtdMaterialRecebidoTextWidget extends StatefulWidget {
  const QtdMaterialRecebidoTextWidget({
    super.key,
    required this.uuid,
    required this.relatorioUuid,
    required this.valor,
  });

  final String? uuid;
  final String? relatorioUuid;
  final double valor;

  @override
  State<QtdMaterialRecebidoTextWidget> createState() =>
      _QtdMaterialRecebidoTextWidgetState();
}

class _QtdMaterialRecebidoTextWidgetState
    extends State<QtdMaterialRecebidoTextWidget> {
  late QtdMaterialRecebidoTextModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => QtdMaterialRecebidoTextModel());

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
          _model.newValor = parseQuantidadeRelatorio(_model.textController.text);
          safeSetState(() {});
          await SQLiteManager.instance.updateEquipamentoRecebido(
            uuid: widget!.uuid!,
            qtd: _model.newValor!,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Registro Atualizado',
                style: TextStyle(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                ),
              ),
              duration: Duration(milliseconds: 4000),
              backgroundColor: FlutterFlowTheme.of(context).secondary,
            ),
          );
        },
      ),
      autofocus: false,
      obscureText: false,
      decoration: InputDecoration(
        isDense: true,
        hintText: 'Qtd',
        hintStyle: FlutterFlowTheme.of(context).bodyLarge.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
              ),
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
              lineHeight: 0.7,
            ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: FlutterFlowTheme.of(context).alternate,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        errorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(6.0),
        ),
        filled: true,
        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
      ),
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            font: GoogleFonts.inter(
              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            ),
            fontSize: 14.0,
            letterSpacing: 0.0,
            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
          ),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: _model.textControllerValidator.asValidator(context),
    );
  }
}

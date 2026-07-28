import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'campo_numero_int_checklist_model.dart';
export 'campo_numero_int_checklist_model.dart';

class CampoNumeroIntChecklistWidget extends StatefulWidget {
  const CampoNumeroIntChecklistWidget({
    super.key,
    this.index,
    this.areaId,
    required this.perguntaId,
  });

  final int? index;
  final int? areaId;
  final int? perguntaId;

  @override
  State<CampoNumeroIntChecklistWidget> createState() =>
      _CampoNumeroIntChecklistWidgetState();
}

class _CampoNumeroIntChecklistWidgetState
    extends State<CampoNumeroIntChecklistWidget> {
  late CampoNumeroIntChecklistModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CampoNumeroIntChecklistModel());

    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return TextFormField(
      controller: _model.textController,
      focusNode: _model.textFieldFocusNode,
      onChanged: (_) => EasyDebounce.debounce(
        '_model.textController',
        Duration(milliseconds: 2000),
        () async {
          await actions.salvarRespostaTexto(
            FFAppState().checklistAtualJson,
            widget!.areaId!.toString(),
            widget!.perguntaId!.toString(),
            _model.textController.text,
          );
        },
      ),
      autofocus: false,
      obscureText: false,
      decoration: InputDecoration(
        hintText: 'Digite o valor...',
        hintStyle: FlutterFlowTheme.of(context).bodySmall.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
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
            color: FlutterFlowTheme.of(context).primary,
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
        contentPadding: EdgeInsets.all(12.0),
      ),
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            font: GoogleFonts.inter(
              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            ),
            letterSpacing: 0.0,
            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
          ),
      minLines: 1,
      keyboardType: TextInputType.number,
      cursorColor: FlutterFlowTheme.of(context).primary,
      validator: _model.textControllerValidator.asValidator(context),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[0-9]'))],
    );
  }
}

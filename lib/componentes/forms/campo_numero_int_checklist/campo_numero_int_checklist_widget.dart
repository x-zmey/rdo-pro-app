import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/custom_code/actions/index.dart' as actions;
import 'dart:convert';
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

  final dynamic index;
  final dynamic areaId;
  final dynamic perguntaId;

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

    _model.textController ??= TextEditingController(text: _valorSalvo());
    _model.textFieldFocusNode ??= FocusNode();
  }

  String _valorSalvo() {
    try {
      final envelope = jsonDecode(FFAppState().checklistAtualJson);
      if (envelope is! Map) return '';
      final td = envelope['template_data'];
      if (td is! Map) return '';
      for (final area in td['areas'] as List? ?? []) {
        if (area is! Map ||
            area['id']?.toString() != widget.areaId.toString()) {
          continue;
        }
        for (final item in area['items'] as List? ?? []) {
          if (item is! Map ||
              item['id']?.toString() != widget.perguntaId.toString()) {
            continue;
          }
          final v = item['respostaNumero'];
          return v == null ? '' : v.toString();
        }
      }
    } catch (_) {}
    return '';
  }

  @override
  void dispose() {
    EasyDebounce.cancel(_debounceKey);
    _persistNow();
    _model.maybeDispose();

    super.dispose();
  }

  String get _debounceKey =>
      'checklist_numero_${widget.areaId}_${widget.perguntaId}';

  Future<void> _persistNow() async {
    await actions.salvarRespostaNumero(
      FFAppState().checklistAtualJson,
      widget.areaId.toString(),
      widget.perguntaId.toString(),
      num.tryParse((_model.textController?.text ?? '').trim()),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return TextFormField(
      controller: _model.textController,
      focusNode: _model.textFieldFocusNode,
      onChanged: (_) => EasyDebounce.debounce(
        _debounceKey,
        Duration(milliseconds: 800),
        () async {
          await _persistNow();
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

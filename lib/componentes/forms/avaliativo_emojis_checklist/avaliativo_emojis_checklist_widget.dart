import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'avaliativo_emojis_checklist_model.dart';
export 'avaliativo_emojis_checklist_model.dart';

class AvaliativoEmojisChecklistWidget extends StatefulWidget {
  const AvaliativoEmojisChecklistWidget({
    super.key,
    required this.index,
    required this.areaId,
    required this.perguntaId,
  });

  final int? index;
  final int? areaId;
  final int? perguntaId;

  @override
  State<AvaliativoEmojisChecklistWidget> createState() =>
      _AvaliativoEmojisChecklistWidgetState();
}

class _AvaliativoEmojisChecklistWidgetState
    extends State<AvaliativoEmojisChecklistWidget> {
  late AvaliativoEmojisChecklistModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AvaliativoEmojisChecklistModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterFlowIconButton(
              borderRadius: 25.0,
              buttonSize: 50.0,
              fillColor: Color(0xFFFFE0E0),
              icon: Icon(
                Icons.sentiment_very_dissatisfied,
                color: FlutterFlowTheme.of(context).error,
                size: 30.0,
              ),
              onPressed: () async {
                _model.optionSelected = 'triste';
                safeSetState(() {});
              },
            ),
            Text(
              'Péssimo',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterFlowIconButton(
              borderRadius: 25.0,
              buttonSize: 50.0,
              fillColor: Color(0xFFFFF5E0),
              icon: Icon(
                Icons.sentiment_neutral,
                color: Colors.orange,
                size: 30.0,
              ),
              onPressed: () async {
                _model.optionSelected = 'normal';
                safeSetState(() {});
              },
            ),
            Text(
              'Regular',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ],
        ),
        Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterFlowIconButton(
              borderRadius: 25.0,
              buttonSize: 50.0,
              fillColor: FlutterFlowTheme.of(context).primary,
              icon: Icon(
                Icons.sentiment_very_satisfied,
                color: Colors.white,
                size: 30.0,
              ),
              onPressed: () async {
                _model.optionSelected = 'feliz';
                safeSetState(() {});
              },
            ),
            Text(
              'Excelente',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodySmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodySmall.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
            ),
          ],
        ),
      ].divide(SizedBox(width: 16.0)),
    );
  }
}

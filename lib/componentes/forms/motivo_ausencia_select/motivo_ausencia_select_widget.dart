import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'motivo_ausencia_select_model.dart';
export 'motivo_ausencia_select_model.dart';

class MotivoAusenciaSelectWidget extends StatefulWidget {
  const MotivoAusenciaSelectWidget({
    super.key,
    required this.parameter1,
    required this.uuid,
  });

  final String? parameter1;
  final String? uuid;

  @override
  State<MotivoAusenciaSelectWidget> createState() =>
      _MotivoAusenciaSelectWidgetState();
}

class _MotivoAusenciaSelectWidgetState
    extends State<MotivoAusenciaSelectWidget> {
  late MotivoAusenciaSelectModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MotivoAusenciaSelectModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: widget!.parameter1 != 'presente',
      child: FlutterFlowDropDown<String>(
        controller: _model.dropDownValueController ??=
            FormFieldController<String>(
          _model.dropDownValue ??= 'Option 1',
        ),
        options: ['Option 1', 'Option 2', 'Option 3'],
        onChanged: (val) => safeSetState(() => _model.dropDownValue = val),
        width: 345.0,
        height: 40.0,
        textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
              ),
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            ),
        hintText: 'Motivo da ausencia...',
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          color: FlutterFlowTheme.of(context).secondaryText,
          size: 24.0,
        ),
        fillColor: FlutterFlowTheme.of(context).secondaryBackground,
        elevation: 2.0,
        borderColor: FlutterFlowTheme.of(context).alternate,
        borderWidth: 1.0,
        borderRadius: 8.0,
        margin: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
        hidesUnderline: true,
        isOverButton: false,
        isSearchable: false,
        isMultiSelect: false,
      ),
    );
  }
}

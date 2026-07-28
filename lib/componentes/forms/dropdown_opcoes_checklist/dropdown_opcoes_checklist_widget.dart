import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dropdown_opcoes_checklist_model.dart';
export 'dropdown_opcoes_checklist_model.dart';

class DropdownOpcoesChecklistWidget extends StatefulWidget {
  const DropdownOpcoesChecklistWidget({
    super.key,
    required this.areaId,
    required this.itemId,
    required this.opcoes,
  });

  final int? areaId;
  final int? itemId;
  final List<dynamic>? opcoes;

  @override
  State<DropdownOpcoesChecklistWidget> createState() =>
      _DropdownOpcoesChecklistWidgetState();
}

class _DropdownOpcoesChecklistWidgetState
    extends State<DropdownOpcoesChecklistWidget> {
  late DropdownOpcoesChecklistModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DropdownOpcoesChecklistModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FlutterFlowDropDown<String>(
      controller: _model.dropDownValueController ??=
          FormFieldController<String>(
        _model.dropDownValue ??= getJsonField(
          widget!.opcoes?.firstOrNull,
          r'''$['texto']''',
        ).toString(),
      ),
      options: widget!.opcoes!
          .map((e) => getJsonField(
                e,
                r'''$['texto']''',
              ))
          .toList()
          .map((e) => e.toString())
          .toList(),
      onChanged: (val) => safeSetState(() => _model.dropDownValue = val),
      width: 200.0,
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
      hintText: 'Selecionar Opção',
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: FlutterFlowTheme.of(context).secondaryText,
        size: 24.0,
      ),
      fillColor: FlutterFlowTheme.of(context).secondaryBackground,
      elevation: 2.0,
      borderColor: Colors.transparent,
      borderWidth: 0.0,
      borderRadius: 8.0,
      margin: EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
      hidesUnderline: true,
      isOverButton: false,
      isSearchable: false,
      isMultiSelect: false,
    );
  }
}

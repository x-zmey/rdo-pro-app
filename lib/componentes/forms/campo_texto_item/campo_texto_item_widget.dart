import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'campo_texto_item_model.dart';
export 'campo_texto_item_model.dart';

class CampoTextoItemWidget extends StatefulWidget {
  const CampoTextoItemWidget({
    super.key,
    required this.qtd,
    required this.itemId,
  });

  final int? qtd;
  final int? itemId;

  @override
  State<CampoTextoItemWidget> createState() => _CampoTextoItemWidgetState();
}

class _CampoTextoItemWidgetState extends State<CampoTextoItemWidget> {
  late CampoTextoItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CampoTextoItemModel());

    _model.textController ??= TextEditingController(text: '1');
    _model.textFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
      child: TextFormField(
        controller: _model.textController,
        focusNode: _model.textFieldFocusNode,
        onChanged: (_) => EasyDebounce.debounce(
          '_model.textController',
          Duration(milliseconds: 2000),
          () async {
            _model.detalhesItem =
                await SQLiteManager.instance.getDetalhesItemAtividade(
              uuid: widget!.itemId!.toString(),
            );
            await SQLiteManager.instance.updateItemAtividade(
              uuid: widget!.itemId!.toString(),
              qtdRealizada: int.tryParse(_model.textController.text),
              qtdUtilizada: _model.detalhesItem?.firstOrNull?.qtdUtilizada,
            );

            _model.updatePage(() {});
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Quantidade atualizada!',
                  style: TextStyle(
                    color: FlutterFlowTheme.of(context).alternate,
                  ),
                ),
                duration: Duration(milliseconds: 4000),
                backgroundColor: FlutterFlowTheme.of(context).secondary,
              ),
            );

            safeSetState(() {});
          },
        ),
        textInputAction: TextInputAction.done,
        obscureText: false,
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Qtd',
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
        ),
        style: FlutterFlowTheme.of(context).bodySmall.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              ),
              fontSize: 16.0,
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodySmall.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodySmall.fontStyle,
              lineHeight: 0.7,
            ),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        validator: _model.textControllerValidator.asValidator(context),
      ),
    );
  }
}

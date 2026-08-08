import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'qtd_field_mao_obra_atividade_relatorio_model.dart';
export 'qtd_field_mao_obra_atividade_relatorio_model.dart';

class QtdFieldMaoObraAtividadeRelatorioWidget extends StatefulWidget {
  const QtdFieldMaoObraAtividadeRelatorioWidget({
    super.key,
    required this.uuid,
    required this.valor,
  });

  final String? uuid;
  final int? valor;

  @override
  State<QtdFieldMaoObraAtividadeRelatorioWidget> createState() =>
      _QtdFieldMaoObraAtividadeRelatorioWidgetState();
}

class _QtdFieldMaoObraAtividadeRelatorioWidgetState
    extends State<QtdFieldMaoObraAtividadeRelatorioWidget> {
  late QtdFieldMaoObraAtividadeRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model =
        createModel(context, () => QtdFieldMaoObraAtividadeRelatorioModel());

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
            qtdRealizada: _model.detalhesItem?.firstOrNull?.qtdRealizada,
            uuid: widget!.uuid!,
            qtdUtilizada: int.tryParse(_model.textController.text),
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
      decoration: rdoCompactFieldDecoration(
        context,
        hint: '0',
        fillColor: FlutterFlowTheme.of(context).primaryBackground,
      ),
      style: rdoCompactFieldTextStyle(context),
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number,
      validator: _model.textControllerValidator.asValidator(context),
    );
  }
}

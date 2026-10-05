import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final num? valor;

  @override
  State<QtdFieldEquipamentoRealizadoAtividadeRelatorioWidget> createState() =>
      _QtdFieldEquipamentoRealizadoAtividadeRelatorioWidgetState();
}

class _QtdFieldEquipamentoRealizadoAtividadeRelatorioWidgetState
    extends State<QtdFieldEquipamentoRealizadoAtividadeRelatorioWidget> {
  late QtdFieldEquipamentoRealizadoAtividadeRelatorioModel _model;

  static final List<TextInputFormatter> _formatters = [
    FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
  ];

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
      text: formatQuantidadeRelatorio(widget.valor ?? 0),
    );
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
          final qtd = tryParseQuantidadeRelatorio(_model.textController.text);
          if (qtd == null || qtd < 0) return;

          _model.detalhesItem =
              await SQLiteManager.instance.getDetalhesItemAtividade(
            uuid: widget.uuid!,
          );
          await SQLiteManager.instance.updateItemAtividade(
            qtdRealizada: qtd,
            uuid: widget.uuid!,
            qtdUtilizada: _model.detalhesItem?.firstOrNull?.qtdUtilizada,
          );
          if (!mounted) return;
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _formatters,
      validator: _model.textControllerValidator.asValidator(context),
    );
  }
}

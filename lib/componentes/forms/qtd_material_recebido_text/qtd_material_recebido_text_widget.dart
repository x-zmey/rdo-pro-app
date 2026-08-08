import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
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
      decoration: rdoCompactFieldDecoration(context, hint: 'Qtd'),
      style: rdoCompactFieldTextStyle(context),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: _model.textControllerValidator.asValidator(context),
    );
  }
}

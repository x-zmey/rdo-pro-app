import 'dart:async';

import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'qtd_custo_item_ordem_relatorio_model.dart';
export 'qtd_custo_item_ordem_relatorio_model.dart';

class QtdCustoItemOrdemRelatorioWidget extends StatefulWidget {
  const QtdCustoItemOrdemRelatorioWidget({
    super.key,
    required this.uuid,
    required this.relatorioUuid,
    this.valor,
    this.onQuantidadeChanged,
  });

  final String? uuid;
  final String? relatorioUuid;
  final int? valor;
  /// Chamado quando o valor digitado muda (para recalcular saldo na lista).
  final ValueChanged<int?>? onQuantidadeChanged;

  @override
  State<QtdCustoItemOrdemRelatorioWidget> createState() =>
      _QtdCustoItemOrdemRelatorioWidgetState();
}

class _QtdCustoItemOrdemRelatorioWidgetState
    extends State<QtdCustoItemOrdemRelatorioWidget> {
  late QtdCustoItemOrdemRelatorioModel _model;

  Timer? _saveDebounce;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => QtdCustoItemOrdemRelatorioModel());

    _model.textController ??= TextEditingController(
        text: valueOrDefault<String>(
      widget!.valor?.toString(),
      '0',
    ));
    _model.textFieldFocusNode ??= FocusNode();
  }

  @override
  void didUpdateWidget(covariant QtdCustoItemOrdemRelatorioWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.valor != oldWidget.valor && _model.textController != null) {
      final newText =
          valueOrDefault<String>(widget.valor?.toString(), '0');
      if (_model.textController!.text != newText) {
        _model.textController!.text = newText;
      }
    }
  }

  void _notifyQuantidade() {
    final t = _model.textController?.text.trim() ?? '';
    if (t.isEmpty) {
      widget.onQuantidadeChanged?.call(null);
      return;
    }
    final d = double.tryParse(t.replaceAll(',', '.'));
    if (d == null) {
      widget.onQuantidadeChanged?.call(null);
      return;
    }
    widget.onQuantidadeChanged?.call(d.round());
  }

  Future<void> _persistQuantidadeToSqlite() async {
    final uuid = widget.uuid;
    if (uuid == null || uuid.isEmpty) return;

    final t = _model.textController?.text.trim() ?? '';
    final q = t.isEmpty
        ? 0.0
        : (double.tryParse(t.replaceAll(',', '.')) ?? 0.0);

    try {
      await SQLiteManager.instance.updateRelatorioCustoQtdRealizada(
        uuid: uuid,
        qtdRealizada: q,
      );
    } catch (e) {
      debugPrint('Erro ao salvar qtd realizada (relatorio_custos): $e');
    }
  }

  void _schedulePersist() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 450), () {
      _persistQuantidadeToSqlite();
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80.0,
      child: TextFormField(
        controller: _model.textController,
        focusNode: _model.textFieldFocusNode,
        autofocus: false,
        obscureText: false,
        decoration: rdoCompactFieldDecoration(
          context,
          hint: 'Qtd',
          fillColor: FlutterFlowTheme.of(context).primaryBackground,
        ),
        style: rdoCompactFieldTextStyle(context),
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: _model.textControllerValidator.asValidator(context),
        onChanged: (_) {
          _notifyQuantidade();
          _schedulePersist();
        },
        onEditingComplete: () {
          _saveDebounce?.cancel();
          _persistQuantidadeToSqlite();
        },
        onFieldSubmitted: (_) {
          _saveDebounce?.cancel();
          _persistQuantidadeToSqlite();
        },
      ),
    );
  }
}

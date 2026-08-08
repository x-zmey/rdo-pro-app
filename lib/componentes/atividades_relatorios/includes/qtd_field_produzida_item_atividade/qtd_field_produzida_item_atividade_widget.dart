import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/custom_functions.dart';
import '/componentes/atividades_relatorios/includes/atividade_produtividade.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'qtd_field_produzida_item_atividade_model.dart';
export 'qtd_field_produzida_item_atividade_model.dart';

/// Campo **Prod.** (`qtd_produzida`) — mão de obra / equipamentos da atividade.
class QtdFieldProduzidaItemAtividadeWidget extends StatefulWidget {
  const QtdFieldProduzidaItemAtividadeWidget({
    super.key,
    required this.uuid,
    required this.itemId,
    required this.atividadeUuid,
    required this.valor,
    required this.tipo,
    this.unidade,
    this.onSaved,
    this.qtdRealizadaAtividade,
  });

  final String uuid;
  final int itemId;
  final String atividadeUuid;
  final num? valor;
  /// `mao_obra` | `equipamento`
  final String tipo;
  final String? unidade;
  final VoidCallback? onSaved;

  /// Quantidade realizada digitada no formulário da atividade (pode ainda não
  /// estar persistida no SQLite). Usada como teto da produtividade.
  final ValueGetter<num?>? qtdRealizadaAtividade;

  @override
  State<QtdFieldProduzidaItemAtividadeWidget> createState() =>
      _QtdFieldProduzidaItemAtividadeWidgetState();
}

class _QtdFieldProduzidaItemAtividadeWidgetState
    extends State<QtdFieldProduzidaItemAtividadeWidget> {
  late QtdFieldProduzidaItemAtividadeModel _model;
  String _snapshot = '0';

  String get _tipoLabel =>
      widget.tipo == 'equipamento' ? 'equipamentos' : 'mão de obra';

  String _formatValor(num? v) {
    final n = v ?? 0;
    if (n == n.roundToDouble()) return n.toInt().toString();
    return n.toStringAsFixed(2).replaceAll('.', ',');
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => QtdFieldProduzidaItemAtividadeModel());
    final initial = _formatValor(widget.valor);
    _snapshot = initial;
    _model.textController ??= TextEditingController(text: initial);
    _model.textFieldFocusNode ??= FocusNode();
    _model.textFieldFocusNode!.addListener(() {
      if (_model.textFieldFocusNode!.hasFocus) {
        _snapshot = _model.textController?.text ?? _snapshot;
      }
    });
  }

  @override
  void didUpdateWidget(covariant QtdFieldProduzidaItemAtividadeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.valor != widget.valor &&
        !(_model.textFieldFocusNode?.hasFocus ?? false)) {
      final next = _formatValor(widget.valor);
      _model.textController?.text = next;
      _snapshot = next;
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    final digitado = parseQuantidadeRelatorio(_model.textController?.text);
    final itens = await SQLiteManager.instance.getItensAtividade(
      atividadeUuid: widget.atividadeUuid,
      tipo: widget.tipo,
    );
    final atividadeRows = await SQLiteManager.instance.getDadosAtividade(
      uuid: widget.atividadeUuid,
    );
    final atividade = atividadeRows.firstOrNull;
    final item = itens.where((e) => e.id == widget.itemId).firstOrNull;

    final check = validarProdutividadeItem(
      itens: itens,
      item: item,
      atividade: atividade,
      qtdProduzida: digitado,
      tipoLabel: _tipoLabel,
      qtdRealizadaFormulario: widget.qtdRealizadaAtividade?.call(),
    );

    if (!check.ok) {
      _model.textController?.text = _snapshot;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            check.message ?? 'Quantidade produzida inválida',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).primaryBackground,
            ),
          ),
          duration: const Duration(milliseconds: 4500),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      safeSetState(() {});
      return;
    }

    await SQLiteManager.instance.updateItemAtividade(
      uuid: widget.uuid,
      qtdProduzida: digitado,
    );
    _snapshot = _formatValor(digitado);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Produtividade atualizada',
          style: TextStyle(
            color: FlutterFlowTheme.of(context).primaryBackground,
          ),
        ),
        duration: const Duration(milliseconds: 2500),
        backgroundColor: FlutterFlowTheme.of(context).primary,
      ),
    );
    widget.onSaved?.call();
    safeSetState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final unidade =
        (widget.unidade ?? '').trim().isEmpty ? 'un' : widget.unidade!.trim();

    return TextFormField(
      controller: _model.textController,
      focusNode: _model.textFieldFocusNode,
      onChanged: (_) => EasyDebounce.debounce(
        'produzida_${widget.uuid}',
        const Duration(milliseconds: 2000),
        _salvar,
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
      onFieldSubmitted: (_) => _salvar(),
      validator: _model.textControllerValidator.asValidator(context),
    );
  }
}

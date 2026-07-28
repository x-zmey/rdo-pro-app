import '/backend/sqlite/sqlite_manager.dart';
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
  });

  final String uuid;
  final int itemId;
  final String atividadeUuid;
  final num? valor;
  /// `mao_obra` | `equipamento`
  final String tipo;
  final String? unidade;
  final VoidCallback? onSaved;

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
      decoration: InputDecoration(
        isDense: true,
        hintText: '0',
        hintStyle: FlutterFlowTheme.of(context).bodyLarge.override(
              font: GoogleFonts.inter(
                fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
                fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
              ),
              letterSpacing: 0.0,
              fontWeight: FlutterFlowTheme.of(context).bodyLarge.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyLarge.fontStyle,
              lineHeight: 0.7,
            ),
        suffixText: unidade.toUpperCase(),
        suffixStyle: FlutterFlowTheme.of(context).labelSmall.override(
              font: GoogleFonts.inter(
                fontWeight: FontWeight.w500,
              ),
              color: FlutterFlowTheme.of(context).secondaryText,
              letterSpacing: 0.0,
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
          borderSide: const BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderSide: const BorderSide(
            color: Color(0x00000000),
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(8.0),
        ),
        filled: true,
        fillColor: FlutterFlowTheme.of(context).primaryBackground,
      ),
      style: FlutterFlowTheme.of(context).bodyMedium.override(
            font: GoogleFonts.inter(
              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
            ),
            fontSize: 16.0,
            letterSpacing: 0.0,
            fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
            fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
          ),
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onFieldSubmitted: (_) => _salvar(),
      validator: _model.textControllerValidator.asValidator(context),
    );
  }
}

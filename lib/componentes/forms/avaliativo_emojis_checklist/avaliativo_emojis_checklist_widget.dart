import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
    this.valorAtual,
    this.opcoes,
  });

  final dynamic index;
  final dynamic areaId;
  final dynamic perguntaId;
  final String? valorAtual;
  final List<dynamic>? opcoes;

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
    _model.optionSelected = _valorEfetivo();
  }

  @override
  void didUpdateWidget(covariant AvaliativoEmojisChecklistWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _valorEfetivo();
    if (next != _model.optionSelected) {
      _model.optionSelected = next;
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  String? _valorEfetivo() {
    final fromProp = (widget.valorAtual ?? '').trim();
    if (fromProp.isNotEmpty) return fromProp;
    return _lerDoAppState();
  }

  String? _lerDoAppState() {
    try {
      final envelope = jsonDecode(FFAppState().checklistAtualJson);
      if (envelope is! Map) return null;
      final td = envelope['template_data'];
      if (td is! Map) return null;
      for (final area in td['areas'] as List? ?? []) {
        if (area is! Map ||
            area['id']?.toString() != widget.areaId.toString()) {
          continue;
        }
        for (final item in area['items'] as List? ?? []) {
          if (item is! Map ||
              item['id']?.toString() != widget.perguntaId.toString()) {
            continue;
          }
          final atual = (item['respostaEmoji'] ?? '').toString().trim();
          return atual.isEmpty ? null : atual;
        }
      }
    } catch (_) {}
    return null;
  }

  List<_EmojiOpcaoUi> _opcoesUi() {
    final raw = widget.opcoes;
    if (raw != null && raw.isNotEmpty) {
      final parsed = <_EmojiOpcaoUi>[];
      for (final o in raw) {
        if (o is! Map) continue;
        final valor = (o['valor'] ?? '').toString().trim();
        if (valor.isEmpty) continue;
        final label = (o['label'] ?? valor).toString().trim();
        parsed.add(_EmojiOpcaoUi(
          valor: valor,
          label: _labelAmigavel(label, valor),
          icon: _iconePara(valor, label),
          color: _corPara(valor, label, context),
          fill: _fillPara(valor, label, context),
        ));
      }
      if (parsed.isNotEmpty) return parsed;
    }

    final theme = FlutterFlowTheme.of(context);
    return [
      _EmojiOpcaoUi(
        valor: 'triste',
        label: 'Péssimo',
        icon: Icons.sentiment_very_dissatisfied,
        color: theme.error,
        fill: const Color(0xFFFFE0E0),
      ),
      _EmojiOpcaoUi(
        valor: 'normal',
        label: 'Regular',
        icon: Icons.sentiment_neutral,
        color: Colors.orange,
        fill: const Color(0xFFFFF5E0),
      ),
      _EmojiOpcaoUi(
        valor: 'feliz',
        label: 'Excelente',
        icon: Icons.sentiment_very_satisfied,
        color: theme.success,
        fill: const Color(0xFFE0F7E9),
      ),
    ];
  }

  String _labelAmigavel(String label, String valor) {
    final key = '$label $valor'.toLowerCase();
    final pareceSoEmoji = label.trim().length <= 2 &&
        !RegExp(r'[a-zA-ZÀ-ÿ0-9]').hasMatch(label);
    if (key.contains('triste') ||
        key.contains('péssim') ||
        key.contains('pessim') ||
        key.contains('😞') ||
        key.contains('😢')) {
      return pareceSoEmoji ? 'Péssimo' : label;
    }
    if (key.contains('normal') ||
        key.contains('regular') ||
        key.contains('😐')) {
      return pareceSoEmoji ? 'Regular' : label;
    }
    if (key.contains('feliz') ||
        key.contains('excelente') ||
        key.contains('ótimo') ||
        key.contains('otimo') ||
        key.contains('😀') ||
        key.contains('😊')) {
      return pareceSoEmoji ? 'Excelente' : label;
    }
    return label.isEmpty ? valor : label;
  }

  IconData _iconePara(String valor, String label) {
    final key = '${valor.toLowerCase()} ${label.toLowerCase()}';
    if (key.contains('triste') ||
        key.contains('péssim') ||
        key.contains('pessim') ||
        key.contains('ruim') ||
        key.contains('😞') ||
        key.contains('😢')) {
      return Icons.sentiment_very_dissatisfied;
    }
    if (key.contains('feliz') ||
        key.contains('excelente') ||
        key.contains('ótimo') ||
        key.contains('otimo') ||
        key.contains('bom') ||
        key.contains('😀') ||
        key.contains('😊')) {
      return Icons.sentiment_very_satisfied;
    }
    return Icons.sentiment_neutral;
  }

  Color _corPara(String valor, String label, BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final icon = _iconePara(valor, label);
    if (icon == Icons.sentiment_very_dissatisfied) return theme.error;
    if (icon == Icons.sentiment_very_satisfied) return theme.success;
    return Colors.orange;
  }

  Color _fillPara(String valor, String label, BuildContext context) {
    final icon = _iconePara(valor, label);
    if (icon == Icons.sentiment_very_dissatisfied) {
      return const Color(0xFFFFE0E0);
    }
    if (icon == Icons.sentiment_very_satisfied) {
      return const Color(0xFFE0F7E9);
    }
    return const Color(0xFFFFF5E0);
  }

  Future<void> _salvar(String valor) async {
    _model.optionSelected = valor;
    safeSetState(() {});
    await actions.salvarRespostaEmoji(
      FFAppState().checklistAtualJson,
      widget.areaId.toString(),
      widget.perguntaId.toString(),
      valor,
    );
  }

  Widget _emojiBtn(_EmojiOpcaoUi opcao, String? selecionadoValor) {
    final selecionado =
        (selecionadoValor ?? '').trim() == opcao.valor.trim();
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: selecionado ? opcao.color : opcao.fill,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => _salvar(opcao.valor),
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  opcao.icon,
                  size: 30,
                  color: selecionado ? Colors.white : opcao.color,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            opcao.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  font: GoogleFonts.inter(
                    fontWeight: selecionado
                        ? FontWeight.w700
                        : FlutterFlowTheme.of(context).bodySmall.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodySmall.fontStyle,
                  ),
                  color: selecionado
                      ? opcao.color
                      : FlutterFlowTheme.of(context).secondaryText,
                  letterSpacing: 0.0,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final selecionado = _valorEfetivo() ?? _model.optionSelected;
    _model.optionSelected = selecionado;

    final opcoes = _opcoesUi();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < opcoes.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _emojiBtn(opcoes[i], selecionado),
        ],
      ],
    );
  }
}

class _EmojiOpcaoUi {
  const _EmojiOpcaoUi({
    required this.valor,
    required this.label,
    required this.icon,
    required this.color,
    required this.fill,
  });

  final String valor;
  final String label;
  final IconData icon;
  final Color color;
  final Color fill;
}

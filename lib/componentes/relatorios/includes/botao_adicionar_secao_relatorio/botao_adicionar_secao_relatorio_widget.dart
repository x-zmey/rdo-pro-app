import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

/// Botão de adicionar (+) compacto no cabeçalho das seções do relatório.
class BotaoAdicionarSecaoRelatorioWidget extends StatelessWidget {
  const BotaoAdicionarSecaoRelatorioWidget({
    super.key,
    required this.onPressed,
    this.tooltip = 'Adicionar',
  });

  final VoidCallback onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.primary,
      ),
      icon: const Icon(Icons.add_rounded, size: 22),
    );
  }
}

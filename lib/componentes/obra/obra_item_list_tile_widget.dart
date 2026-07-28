import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

String formatQtdObraItemDisplay(double v) {
  return v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
}

/// Card compacto de item da obra (insumo, equipamento, mão de obra).
class ObraItemListTileWidget extends StatelessWidget {
  const ObraItemListTileWidget({
    super.key,
    required this.titulo,
    this.subtitulo,
    required this.qtd,
    required this.qtdRealizada,
    this.unidade = 'un',
    required this.podeExcluir,
    required this.isDeleting,
    required this.onExcluir,
    this.deleteTooltip,
    this.mostrarExcluir = true,
    this.marginBottom = 5,
  });

  final String titulo;
  final String? subtitulo;
  final double qtd;
  final double qtdRealizada;
  final String unidade;
  final bool podeExcluir;
  final bool isDeleting;
  final VoidCallback? onExcluir;
  final String? deleteTooltip;
  /// Quando false (sem permissão delete_*), oculta o botão por completo.
  final bool mostrarExcluir;
  final double marginBottom;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final unLabel = unidade.trim().isNotEmpty ? unidade.trim() : 'un';
    final progresso =
        qtd > 0 ? (qtdRealizada / qtd).clamp(0.0, 1.0) : 0.0;
    final borderColor = theme.primaryText.withValues(alpha: 0.06);
    final subt = (subtitulo ?? '').trim();

    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(9, 5, 6, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText,
                        height: 1.15,
                      ),
                    ),
                    if (subt.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: theme.primary,
                          height: 1.1,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          'Qtd ${formatQtdObraItemDisplay(qtd)} $unLabel',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: theme.secondaryText,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Real. ${formatQtdObraItemDisplay(qtdRealizada)} $unLabel',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: theme.secondaryText,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progresso,
                        minHeight: 4,
                        backgroundColor: theme.alternate,
                        color: theme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              if (mostrarExcluir)
                Tooltip(
                  message: deleteTooltip ?? 'Excluir',
                  child: Material(
                    color: theme.alternate.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(6),
                    child: InkWell(
                      onTap: podeExcluir ? onExcluir : null,
                      borderRadius: BorderRadius.circular(6),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: isDeleting
                            ? Padding(
                                padding: const EdgeInsets.all(5),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme.error,
                                ),
                              )
                            : Icon(
                                Icons.delete_outline,
                                size: 14,
                                color: podeExcluir
                                    ? theme.error
                                    : theme.secondaryText,
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

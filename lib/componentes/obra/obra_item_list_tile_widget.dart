import '/flutter_flow/flutter_flow_theme.dart';
import '/componentes/ui/rdo_estilo.dart';
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
    this.marginBottom = 0,
    this.accentColor,
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
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final accent = accentColor ?? theme.primary;
    final unLabel = unidade.trim().isNotEmpty ? unidade.trim() : 'un';
    final progresso = qtd > 0 ? (qtdRealizada / qtd).clamp(0.0, 1.0) : 0.0;
    final pct = (progresso * 100).round();
    final subt = (subtitulo ?? '').trim();

    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom),
      child: Material(
        color: theme.secondaryBackground,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  titulo,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: theme.primaryText,
                                    height: 1.25,
                                  ),
                                ),
                                if (subt.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    subt,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (mostrarExcluir) ...[
                            const SizedBox(width: 4),
                            Tooltip(
                              message: deleteTooltip ?? 'Excluir',
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: podeExcluir ? onExcluir : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(
                                    width: 32,
                                    height: 32,
                                    child: isDeleting
                                        ? Padding(
                                            padding: const EdgeInsets.all(8),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: theme.error,
                                            ),
                                          )
                                        : Icon(
                                            Icons.delete_outline_rounded,
                                            size: 18,
                                            color: podeExcluir
                                                ? theme.error
                                                : theme.secondaryText
                                                    .withValues(alpha: 0.4),
                                          ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              theme.primaryBackground.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: theme.alternate),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _kpi(
                                theme,
                                'PREVISTO',
                                '${formatQtdObraItemDisplay(qtd)} $unLabel',
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 26,
                              color: theme.alternate,
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(left: 10),
                                child: _kpi(
                                  theme,
                                  'REALIZADO',
                                  '${formatQtdObraItemDisplay(qtdRealizada)} $unLabel',
                                  destaque: true,
                                  destaqueColor: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            'PROGRESSO',
                            style: rdoColumnLabelStyle(context),
                          ),
                          const Spacer(),
                          Text(
                            '$pct%',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: accent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progresso,
                          minHeight: 5,
                          backgroundColor: theme.alternate,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kpi(
    FlutterFlowTheme theme,
    String label,
    String value, {
    bool destaque = false,
    Color? destaqueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: theme.secondaryText,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: destaque
                  ? (destaqueColor ?? theme.primary)
                  : theme.primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

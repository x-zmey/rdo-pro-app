import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// `status_id`: 1 preenchendo, 2 aguardando, 3 aprovado, 4 reprovado.
bool relatorioPodeEditarOuApagar(int? statusId) {
  if (statusId == null) return true;
  return statusId != 2 && statusId != 3;
}

Color corStatusRelatorioChip(BuildContext context, int? statusId) {
  final t = FlutterFlowTheme.of(context);
  switch (statusId ?? 1) {
    case 2:
      return t.warning;
    case 3:
      return t.success;
    case 4:
      return t.error;
    default:
      return t.secondaryText;
  }
}

String labelRelatorioStatus({
  required int? statusId,
  String? statusNome,
}) {
  final n = statusNome?.trim();
  if (n != null && n.isNotEmpty) return n;
  switch (statusId ?? 0) {
    case 1:
      return 'Preenchendo';
    case 2:
      return 'Em aprovação';
    case 3:
      return 'Aprovado';
    case 4:
      return 'Reprovado';
    default:
      return '—';
  }
}

String formatDataResumoRelatorio(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '';
  final s = raw.trim();
  if (s.length >= 10 && s[4] == '-' && s[7] == '-') {
    return '${s.substring(8, 10)}/${s.substring(5, 7)}/${s.substring(0, 4)}';
  }
  return s;
}

/// Card compacto de relatório (RDO): faixa de status, 2 linhas de info, ações à direita.
class RelatorioListItemWidget extends StatelessWidget {
  const RelatorioListItemWidget({
    super.key,
    required this.numero,
    required this.dataLabel,
    required this.statusId,
    required this.statusLabel,
    this.criador,
    this.subtitulo,
    required this.onTap,
    required this.onVisualizar,
    this.onEditar,
    this.onApagar,
    this.podeEditar,
    this.marginBottom = 5,
  });

  final int? numero;
  final String dataLabel;
  final int? statusId;
  final String statusLabel;
  final String? criador;
  /// Ex.: nome da obra (lista global).
  final String? subtitulo;
  final VoidCallback onTap;
  final VoidCallback onVisualizar;
  final VoidCallback? onEditar;
  final Future<void> Function()? onApagar;
  final bool? podeEditar;
  final double marginBottom;

  Widget _statusChip(BuildContext context, Color statusCor) {
    final id = statusId ?? 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: statusCor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (id == 2)
            Icon(Icons.hourglass_top, size: 10, color: statusCor),
          if (id == 3) Icon(Icons.check_circle, size: 10, color: statusCor),
          if (id == 4) Icon(Icons.cancel, size: 10, color: statusCor),
          const SizedBox(width: 2),
          Text(
            statusLabel,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: statusCor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
  }) {
    final t = FlutterFlowTheme.of(context);
    final btn = Material(
      color: t.alternate.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 26,
          height: 26,
          child: Icon(icon, size: 14, color: t.primary),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip, child: btn);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final statusCor = corStatusRelatorioChip(context, statusId);
    final criadorTxt = (criador ?? '').trim();
    final subtituloTxt = (subtitulo ?? '').trim();
    final editar = podeEditar ?? relatorioPodeEditarOuApagar(statusId);
    final borderColor = theme.primaryText.withValues(alpha: 0.06);

    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3.5, color: statusCor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(9, 5, 4, 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'RDO #${numero?.toString() ?? '—'}',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: theme.primary,
                                  height: 1,
                                ),
                              ),
                            ),
                            if (subtituloTxt.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtituloTxt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  height: 1.1,
                                  color: theme.primary,
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  dataLabel.isNotEmpty ? dataLabel : '—',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    height: 1.1,
                                    color: theme.secondaryText,
                                  ),
                                ),
                                if (criadorTxt.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Icon(
                                    Icons.person_outline_rounded,
                                    size: 11,
                                    color: theme.secondaryText,
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      criadorTxt,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w500,
                                        height: 1.1,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 5),
                                _statusChip(context, statusCor),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 6, 4),
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _iconAction(
                              context,
                              icon: Icons.visibility_outlined,
                              tooltip: 'Visualizar',
                              onPressed: onVisualizar,
                            ),
                            if (editar && onEditar != null) ...[
                              const SizedBox(width: 3),
                              _iconAction(
                                context,
                                icon: Icons.edit_outlined,
                                tooltip: 'Editar',
                                onPressed: onEditar,
                              ),
                            ],
                            if (editar && onApagar != null) ...[
                              const SizedBox(width: 3),
                              _iconAction(
                                context,
                                icon: Icons.delete_outline,
                                tooltip: 'Apagar',
                                onPressed: () => onApagar!(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

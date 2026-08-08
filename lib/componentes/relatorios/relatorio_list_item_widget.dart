import '/componentes/ui/rdo_estilo.dart';
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

IconData iconeStatusRelatorio(int? statusId) {
  switch (statusId ?? 1) {
    case 2:
      return Icons.hourglass_top_rounded;
    case 3:
      return Icons.check_circle_rounded;
    case 4:
      return Icons.cancel_rounded;
    default:
      return Icons.edit_note_rounded;
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

bool _pareceUuidOuIdTecnico(String value) {
  final s = value.trim();
  if (s.isEmpty) return false;
  if (RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(s)) {
    return true;
  }
  // id numérico puro (legado) — não exibir como nome
  if (RegExp(r'^\d+$').hasMatch(s)) return true;
  return false;
}

/// Nome para listagem: usa [criadorNome] resolvido; nunca mostra UUID/id bruto.
String? nomeExibicaoCriadorRelatorio(String? criadorNome, [String? criadorRaw]) {
  final nome = (criadorNome ?? '').trim();
  if (nome.isNotEmpty && !_pareceUuidOuIdTecnico(nome)) return nome;
  final raw = (criadorRaw ?? '').trim();
  if (raw.isNotEmpty && !_pareceUuidOuIdTecnico(raw)) return raw;
  return null;
}

/// Item de relatório no estilo da identidade RDO: faixa de status, título,
/// data/autor e ações compactas.
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
    this.marginBottom = 6,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: statusCor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusCor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconeStatusRelatorio(statusId), size: 11, color: statusCor),
          const SizedBox(width: 4),
          Text(
            statusLabel,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: statusCor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaItem(
    BuildContext context, {
    required IconData icon,
    required String text,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: theme.secondaryText),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: theme.secondaryText,
            ),
          ),
        ),
      ],
    );
  }

  Widget _iconAction(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
    String? tooltip,
  }) {
    final btn = Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 15, color: color),
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
    final dataTxt = dataLabel.trim().isEmpty ? '—' : dataLabel.trim();

    return Padding(
      padding: EdgeInsets.only(bottom: marginBottom),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: rdoCardDecoration(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3.5, color: statusCor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'RDO #${numero?.toString() ?? '—'}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.interTight(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: theme.primaryText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusChip(context, statusCor),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              _iconAction(
                                context,
                                icon: Icons.visibility_outlined,
                                tooltip: 'Visualizar',
                                color: theme.primary,
                                onPressed: onVisualizar,
                              ),
                              if (editar && onEditar != null) ...[
                                const SizedBox(width: 4),
                                _iconAction(
                                  context,
                                  icon: Icons.edit_outlined,
                                  tooltip: 'Editar',
                                  color: theme.primary,
                                  onPressed: onEditar,
                                ),
                              ],
                              if (editar && onApagar != null) ...[
                                const SizedBox(width: 4),
                                _iconAction(
                                  context,
                                  icon: Icons.delete_outline_rounded,
                                  tooltip: 'Apagar',
                                  color: theme.error,
                                  onPressed: () => onApagar!(),
                                ),
                              ],
                            ],
                          ),
                          if (subtituloTxt.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              subtituloTxt,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: theme.primary,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Row(
                            children: [
                              Flexible(
                                child: _metaItem(
                                  context,
                                  icon: Icons.calendar_today_outlined,
                                  text: dataTxt,
                                ),
                              ),
                              if (criadorTxt.isNotEmpty) ...[
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  child: Text(
                                    '·',
                                    style: GoogleFonts.inter(
                                      color: theme.secondaryText
                                          .withValues(alpha: 0.6),
                                    ),
                                  ),
                                ),
                                Flexible(
                                  flex: 2,
                                  child: _metaItem(
                                    context,
                                    icon: Icons.person_outline_rounded,
                                    text: criadorTxt,
                                  ),
                                ),
                              ],
                            ],
                          ),
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
    );
  }
}

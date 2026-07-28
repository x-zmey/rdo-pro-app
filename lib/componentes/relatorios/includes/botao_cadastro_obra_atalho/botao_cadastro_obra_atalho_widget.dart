import '/componentes/relatorios/includes/cadastro_obra_rede_guard.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Atalho visual para cadastrar item na obra e vincular ao relatório/atividade.
class BotaoCadastroObraAtalhoWidget extends StatelessWidget {
  const BotaoCadastroObraAtalhoWidget({
    super.key,
    required this.titulo,
    required this.subtitulo,
    required this.icon,
    required this.onPressed,
    this.margin,
  });

  final String titulo;
  final String subtitulo;
  final IconData icon;
  final VoidCallback onPressed;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return Padding(
      padding: margin ?? const EdgeInsets.only(top: 10, bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (!await garantirInternetParaCadastroObra(context)) return;
            onPressed();
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: theme.secondaryBackground,
              border: Border.all(
                color: theme.primary.withValues(alpha: 0.2),
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.primaryText.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.primary.withValues(alpha: 0.14),
                          theme.primary.withValues(alpha: 0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: Icon(icon, size: 22, color: theme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                            height: 1.25,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitulo,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: theme.secondaryText,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.wifi_rounded,
                              size: 14,
                              color: theme.primary.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Requer conexão com a internet',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: theme.primary.withValues(alpha: 0.85),
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 22,
                    color: theme.primary,
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

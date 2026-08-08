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
      padding: margin ?? const EdgeInsets.only(top: 6, bottom: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (!await garantirInternetParaCadastroObra(context)) return;
            onPressed();
          },
          borderRadius: BorderRadius.circular(8),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: theme.primary.withValues(alpha: 0.04),
              border: Border.all(
                color: theme.primary.withValues(alpha: 0.18),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              child: Row(
                children: [
                  Icon(icon, size: 15, color: theme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: theme.primary,
                            height: 1.2,
                          ),
                        ),
                        Text(
                          subtitulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: theme.secondaryText,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: 'Requer conexão com a internet',
                    child: Icon(
                      Icons.wifi_rounded,
                      size: 13,
                      color: theme.secondaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.add_circle_outline_rounded,
                    size: 17,
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

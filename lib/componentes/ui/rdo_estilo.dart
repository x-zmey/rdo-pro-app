import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidade visual das telas de ordem de serviço do web (cards com toolbar,
/// faixa de KPIs e tabelas compactas), portada para o app.

const double kRdoRadius = 12.0;

BoxDecoration rdoCardDecoration(BuildContext context) {
  final theme = FlutterFlowTheme.of(context);
  return BoxDecoration(
    color: theme.secondaryBackground,
    borderRadius: BorderRadius.circular(kRdoRadius),
    border: Border.all(color: theme.alternate),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}

/// Campo de ~36px usado nas linhas de tabela do RDO: horários HH:mm da mão de
/// obra e quantidades por item. Mesma altura do seletor de motivo.
InputDecoration rdoCompactFieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  Color? fillColor,
}) {
  final theme = FlutterFlowTheme.of(context);
  OutlineInputBorder borda(Color cor, [double largura = 1.0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cor, width: largura),
      );

  final rotulo = GoogleFonts.inter(fontSize: 11, color: theme.secondaryText);

  return InputDecoration(
    labelText: label,
    hintText: hint,
    isDense: true,
    labelStyle: rotulo,
    floatingLabelStyle: rotulo,
    hintStyle: rotulo,
    filled: true,
    fillColor: fillColor ?? theme.secondaryBackground,
    border: borda(theme.alternate),
    enabledBorder: borda(theme.alternate),
    focusedBorder: borda(theme.primary, 1.5),
    errorBorder: borda(theme.error),
    focusedErrorBorder: borda(theme.error, 1.5),
    errorStyle: GoogleFonts.inter(fontSize: 9.5, color: theme.error),
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
    counterText: '',
  );
}

TextStyle rdoCompactFieldTextStyle(BuildContext context) => GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: FlutterFlowTheme.of(context).primaryText,
    );

/// Rótulo de coluna de tabela: maiúsculas, pequeno e com espaçamento.
TextStyle rdoColumnLabelStyle(BuildContext context) {
  final theme = FlutterFlowTheme.of(context);
  return GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: theme.secondaryText,
  );
}

/// Decoração de campos em formulários de cadastro (altura confortável ~48px).
InputDecoration rdoFormFieldDecoration(
  BuildContext context, {
  String? label,
  String? hint,
  String? prefixText,
  Widget? suffixIcon,
}) {
  final theme = FlutterFlowTheme.of(context);
  OutlineInputBorder borda(Color cor, [double largura = 1.0]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: cor, width: largura),
      );

  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixText: prefixText,
    suffixIcon: suffixIcon,
    isDense: true,
    filled: true,
    fillColor: theme.secondaryBackground,
    labelStyle: GoogleFonts.inter(fontSize: 12.5, color: theme.secondaryText),
    hintStyle: GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
    prefixStyle: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: theme.primaryText,
    ),
    border: borda(theme.alternate),
    enabledBorder: borda(theme.alternate),
    focusedBorder: borda(theme.primary, 1.5),
    errorBorder: borda(theme.error),
    focusedErrorBorder: borda(theme.error, 1.5),
    errorStyle: GoogleFonts.inter(fontSize: 11, color: theme.error),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
  );
}

TextStyle rdoFormFieldTextStyle(BuildContext context) => GoogleFonts.inter(
      fontSize: 13.5,
      fontWeight: FontWeight.w500,
      color: FlutterFlowTheme.of(context).primaryText,
    );

/// Faixa cinza-clara com os rótulos das colunas, como no cabeçalho da tabela web.
class RdoTableHeader extends StatelessWidget {
  const RdoTableHeader({super.key, required this.columns});

  /// Cada entrada é `flex` + rótulo. Use `flex: 0` para largura automática.
  final List<RdoColumn> columns;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.primaryBackground.withValues(alpha: 0.6),
        border: Border(bottom: BorderSide(color: theme.alternate)),
      ),
      child: Row(
        children: [
          for (final c in columns)
            Expanded(
              flex: c.flex,
              child: Text(
                c.label.toUpperCase(),
                textAlign: c.align,
                style: rdoColumnLabelStyle(context),
              ),
            ),
        ],
      ),
    );
  }
}

class RdoColumn {
  const RdoColumn(this.label, {this.flex = 1, this.align = TextAlign.start});

  final String label;
  final int flex;
  final TextAlign align;
}

/// Card com toolbar no topo (ícone + título + ações), opcionalmente recolhível.
class RdoSectionCard extends StatelessWidget {
  const RdoSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
    this.subtitle,
    this.expandida = true,
    this.onToggle,
    this.margin = const EdgeInsets.symmetric(horizontal: 16),
    this.contentPadding = const EdgeInsets.all(12),
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  /// Ações à direita da toolbar (contador, botão de adicionar…).
  final Widget? trailing;

  final bool expandida;
  final VoidCallback? onToggle;
  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry contentPadding;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final recolhivel = onToggle != null;
    final aberto = !recolhivel || expandida;

    final cabecalho = Container(
      padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
      constraints: const BoxConstraints(minHeight: 44),
      decoration: BoxDecoration(
        color: theme.primaryBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.vertical(
          top: const Radius.circular(kRdoRadius),
          bottom: Radius.circular(aberto ? 0 : kRdoRadius),
        ),
        border: aberto
            ? Border(bottom: BorderSide(color: theme.alternate))
            : null,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.secondaryText),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (recolhivel)
            IconButton(
              onPressed: onToggle,
              tooltip: aberto ? 'Recolher' : 'Expandir',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              visualDensity: VisualDensity.compact,
              style: IconButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: theme.secondaryText,
              ),
              icon: Icon(
                aberto
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                size: 20,
              ),
            ),
        ],
      ),
    );

    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: rdoCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          recolhivel
              ? InkWell(onTap: onToggle, child: cabecalho)
              : cabecalho,
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: aberto
                ? Padding(padding: contentPadding, child: child)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Contador discreto à direita da toolbar (ex.: "3 itens").
class RdoContadorChip extends StatelessWidget {
  const RdoContadorChip(this.texto, {super.key});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text(
        texto,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: FlutterFlowTheme.of(context).secondaryText,
        ),
      ),
    );
  }
}

class RdoKpiData {
  const RdoKpiData({
    required this.label,
    required this.value,
    this.hint,
    this.destaque = false,
    this.flex = 1,
  });

  final String label;
  final String value;
  final String? hint;

  /// Peso da célula na faixa: valores longos (períodos, jornada) pedem mais
  /// largura para não encolherem no `FittedBox`.
  final int flex;

  /// Destaca a célula com o tom primário, como o "Total com tributos" do web.
  final bool destaque;
}

/// Faixa horizontal de indicadores separados por divisores verticais.
class RdoKpiStrip extends StatelessWidget {
  const RdoKpiStrip({super.key, required this.itens});

  final List<RdoKpiData> itens;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itens.length; i++) ...[
            if (i > 0) VerticalDivider(width: 1, color: theme.alternate),
            Expanded(
              flex: itens[i].flex,
              child: _celula(context, itens[i]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _celula(BuildContext context, RdoKpiData kpi) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      color: kpi.destaque ? theme.primary.withValues(alpha: 0.08) : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kpi.label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 4),
          // Encolhe em vez de cortar: valores longos como "08:00 - 17:00" não
          // cabem em 15px na terça parte da largura da tela.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              kpi.value,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kpi.destaque ? theme.primary : theme.primaryText,
              ),
            ),
          ),
          if (kpi.hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                kpi.hint!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: theme.secondaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

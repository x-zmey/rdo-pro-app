import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Seletor de motivo em uma única linha de 34px, na altura dos campos HH:mm da
/// [MaoObraHorariosFormWidget].
///
/// Usa [PopupMenuButton] em vez de [DropdownButton] porque este último força
/// `kMinInteractiveDimension` (48px) na área do botão, o que somado ao rótulo
/// flutuante do [InputDecorator] passava de 70px por motivo.
Widget buildMaoObraCompactMotivoDropdown({
  required BuildContext context,
  required String label,
  required String hint,
  required List<String> items,
  required String? value,
  required ValueChanged<String?> onChanged,
  IconData icone = Icons.notes_rounded,
}) {
  final theme = FlutterFlowTheme.of(context);
  final merged = List<String>.from(items);
  final v = value?.trim();
  if (v != null && v.isNotEmpty && !merged.contains(v)) {
    merged.insert(0, v);
  }
  final valid = v != null && v.isNotEmpty && merged.contains(v) ? v : null;

  return PopupMenuButton<String>(
    tooltip: hint,
    initialValue: valid,
    position: PopupMenuPosition.under,
    constraints: const BoxConstraints(minWidth: 240),
    onSelected: onChanged,
    itemBuilder: (context) => [
      for (final item in merged)
        PopupMenuItem<String>(
          value: item,
          height: 40,
          child: Text(
            item,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: item == valid ? FontWeight.w600 : FontWeight.w400,
              color: item == valid ? theme.primary : theme.primaryText,
            ),
          ),
        ),
    ],
    child: Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          Icon(icone, size: 14, color: theme.secondaryText),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              valid ?? label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: valid == null ? FontWeight.w400 : FontWeight.w600,
                color: valid == null ? theme.secondaryText : theme.primaryText,
              ),
            ),
          ),
          Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 17,
            color: theme.secondaryText,
          ),
        ],
      ),
    ),
  );
}

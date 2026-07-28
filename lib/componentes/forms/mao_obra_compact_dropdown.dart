import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Altura alinhada aos campos HH:mm da [MaoObraHorariosFormWidget].
Widget buildMaoObraCompactMotivoDropdown({
  required BuildContext context,
  required String label,
  required String hint,
  required List<String> items,
  required String? value,
  required ValueChanged<String?> onChanged,
}) {
  final theme = FlutterFlowTheme.of(context);
  final merged = List<String>.from(items);
  final v = value?.trim();
  if (v != null && v.isNotEmpty && !merged.contains(v)) {
    merged.insert(0, v);
  }
  final valid = v != null && v.isNotEmpty && merged.contains(v) ? v : null;

  return InputDecorator(
    decoration: InputDecoration(
      isDense: true,
      labelText: label,
      labelStyle: theme.bodySmall.override(
        font: GoogleFonts.inter(
          fontWeight: theme.bodySmall.fontWeight,
          fontStyle: theme.bodySmall.fontStyle,
        ),
        fontSize: 14.0,
        letterSpacing: 0.0,
      ),
      hintText: hint,
      hintStyle: theme.labelMedium,
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(
          color: theme.alternate,
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(6.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(
          color: Color(0x00000000),
          width: 1.0,
        ),
        borderRadius: BorderRadius.circular(6.0),
      ),
      filled: true,
      fillColor: theme.secondaryBackground,
      contentPadding: const EdgeInsetsDirectional.fromSTEB(10, 8, 10, 8),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        isExpanded: true,
        // itemHeight omitido: valores < kMinInteractiveDimension (48) disparam assert em dropdown.dart.
        value: valid,
        hint: Text(
          hint,
          style: theme.bodySmall.override(
            font: GoogleFonts.inter(
              fontWeight: theme.bodySmall.fontWeight,
              fontStyle: theme.bodySmall.fontStyle,
            ),
            fontSize: 14.0,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        style: theme.bodySmall.override(
          font: GoogleFonts.inter(
            fontWeight: theme.bodySmall.fontWeight,
            fontStyle: theme.bodySmall.fontStyle,
          ),
          fontSize: 14.0,
          letterSpacing: 0.0,
        ),
        items: merged
            .map(
              (s) => DropdownMenuItem<String>(
                value: s,
                child: Text(
                  s,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodySmall.override(
                    font: GoogleFonts.inter(
                      fontWeight: theme.bodySmall.fontWeight,
                      fontStyle: theme.bodySmall.fontStyle,
                    ),
                    fontSize: 14.0,
                  ),
                ),
              ),
            )
            .toList(),
        onChanged: onChanged,
      ),
    ),
  );
}

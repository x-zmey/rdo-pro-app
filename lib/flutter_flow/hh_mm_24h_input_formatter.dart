import 'package:flutter/services.dart';

/// Máscara HH:mm com horas 00–23 e minutos 00–59.
class HhMm24hInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return newValue.copyWith(
        text: '',
        selection: const TextSelection.collapsed(offset: 0),
      );
    }

    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 4; i++) {
      final ch = digits[i];
      if (i == 0) {
        if (ch.compareTo('2') > 0) return oldValue;
      } else if (i == 1) {
        final hh = int.parse(digits[0] + ch);
        if (hh > 23) return oldValue;
      } else if (i == 2) {
        if (ch.compareTo('5') > 0) return oldValue;
      }
      buf.write(ch);
    }

    var s = buf.toString();
    if (s.length >= 3) {
      s = '${s.substring(0, 2)}:${s.substring(2)}';
    }
    final sel = s.length;
    return TextEditingValue(
      text: s,
      selection: TextSelection.collapsed(offset: sel),
    );
  }
}

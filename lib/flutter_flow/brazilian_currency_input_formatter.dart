import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Máscara pt-BR: milhar com `.` e decimais com `,` (ex.: `1.234,56`).
/// O utilizador escreve só dígitos; o valor é tratado em **centavos**.
final NumberFormat _currencyDisplay = NumberFormat('#,##0.00', 'pt_BR');

/// Remove formatação e devolve o valor em unidade monetária (double).
double parseBrazilianCurrencyInput(String text) {
  final digits = text.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 0;
  final centavos = int.tryParse(digits);
  if (centavos == null) return 0;
  return centavos / 100.0;
}

/// Valor em reais (ex.: SQLite/API) → texto inicial do campo pt-BR (`0,00`, `1.234,56`).
String formatBrazilianCurrencyInputFromDouble(double value) {
  return _currencyDisplay.format(value);
}

class BrazilianCurrencyInputFormatter extends TextInputFormatter {
  BrazilianCurrencyInputFormatter({this.maxCentavos = 999999999999999});

  /// Limite de centavos (evita overflow e entradas absurdas).
  final int maxCentavos;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      const t = '0,00';
      return const TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: 4),
      );
    }
    var centavos = int.tryParse(digits) ?? 0;
    if (centavos > maxCentavos) {
      centavos = maxCentavos;
    }
    final formatted = _currencyDisplay.format(centavos / 100.0);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

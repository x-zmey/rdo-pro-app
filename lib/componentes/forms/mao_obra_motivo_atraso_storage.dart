import 'dart:convert';

/// Alinhado ao Vue: `motivosAtrasoSaida` em `relatorios/edit/[token].vue`.
const List<String> kMotivosAtrasoSaida = [
  'Problemas de Transporte',
  'Problemas Pessoais',
  'Compromisso Médico',
  'Problemas Familiares',
  'Condições Climáticas',
  'Outro',
];

/// Parse minutos desde 00:00 (HH:mm 24h). Retorna null se inválido.
int? parseMinutosDesdeMeiaNoite(String? s) {
  if (s == null) return null;
  final t = s.trim();
  final p = t.split(':');
  if (p.length != 2) return null;
  final h = int.tryParse(p[0]);
  final m = int.tryParse(p[1]);
  if (h == null || m == null) return null;
  if (h < 0 || h > 23 || m < 0 || m > 59) return null;
  return h * 60 + m;
}

/// Coluna única `motivo_atraso`: JSON `{"e":"...","s":"..."}` ou texto legado.
class MaoObraMotivoAtrasoStorage {
  MaoObraMotivoAtrasoStorage._();

  /// `e` = motivo entrada após horário do relatório; `s` = motivo saída antes do relatório.
  static String encode({
    String? entrada,
    String? saida,
  }) {
    final e = entrada?.trim();
    final s = saida?.trim();
    if ((e == null || e.isEmpty) && (s == null || s.isEmpty)) {
      return '';
    }
    final map = <String, String>{};
    if (e != null && e.isNotEmpty) map['e'] = e;
    if (s != null && s.isNotEmpty) map['s'] = s;
    return jsonEncode(map);
  }

  static ({String? entrada, String? saida}) decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return (entrada: null, saida: null);
    }
    final t = raw.trim();
    if (t.startsWith('{')) {
      try {
        final m = jsonDecode(t) as Map<String, dynamic>;
        String? pick(dynamic x) {
          if (x == null) return null;
          final s = x.toString().trim();
          return s.isEmpty ? null : s;
        }

        return (entrada: pick(m['e']), saida: pick(m['s']));
      } catch (_) {
        return (entrada: null, saida: null);
      }
    }
    return (entrada: t, saida: null);
  }
}

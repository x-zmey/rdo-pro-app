import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_theme.dart';

/// Parse "HH:mm" para minutos desde meia-noite; [null] se inválido ou incompleto.
int? parseHhMmToMinutes(String raw) {
  final s = raw.trim();
  final m = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(s);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final min = int.parse(m.group(2)!);
  return h * 60 + min;
}

String? validateSingleHhMm(String? value) {
  final s = value?.trim() ?? '';
  if (s.isEmpty) {
    return 'Preencha o horário';
  }
  if (s.length < 5) {
    return 'Horário incompleto (use HH:mm)';
  }
  if (parseHhMmToMinutes(s) == null) {
    return 'Horário inválido (use 00:00 a 23:59)';
  }
  return null;
}

/// Para [TextFormField]: vazio não mostra erro até o usuário preencher.
String? validateSingleHhMmLenient(String? value) {
  final s = value?.trim() ?? '';
  if (s.isEmpty) return null;
  if (s.length < 5) {
    return 'Horário incompleto (use HH:mm)';
  }
  if (parseHhMmToMinutes(s) == null) {
    return 'Horário inválido (use 00:00 a 23:59)';
  }
  return null;
}

bool todosHorariosCompletosValidos4(
  String e,
  String i,
  String f,
  String s,
) {
  if (e.length != 5 || i.length != 5 || f.length != 5 || s.length != 5) {
    return false;
  }
  return parseHhMmToMinutes(e) != null &&
      parseHhMmToMinutes(i) != null &&
      parseHhMmToMinutes(f) != null &&
      parseHhMmToMinutes(s) != null;
}

/// Valida ordem: entrada ≤ início intervalo ≤ fim intervalo ≤ saída.
String? validateHorariosSequenceFromStrings({
  required String entrada,
  required String inicio,
  required String fim,
  required String saida,
}) {
  for (final field in [entrada, inicio, fim, saida]) {
    final err = validateSingleHhMm(field);
    if (err != null) return err;
  }

  final em = parseHhMmToMinutes(entrada)!;
  final im = parseHhMmToMinutes(inicio)!;
  final fm = parseHhMmToMinutes(fim)!;
  final sm = parseHhMmToMinutes(saida)!;

  if (em > im) {
    return 'Entrada deve ser anterior ou igual ao início do intervalo.';
  }
  if (im > fm) {
    return 'Início do intervalo deve ser anterior ou igual ao fim do intervalo.';
  }
  if (fm > sm) {
    return 'Fim do intervalo deve ser anterior ou igual à saída.';
  }
  return null;
}

String? validateEntradaMaoObra(
  String? value,
  String inicio,
  String fim,
  String saida,
) {
  final err = validateSingleHhMmLenient(value);
  if (err != null) return err;
  final e = value?.trim() ?? '';
  if (!todosHorariosCompletosValidos4(e, inicio, fim, saida)) return null;
  final em = parseHhMmToMinutes(e)!;
  final im = parseHhMmToMinutes(inicio)!;
  final fm = parseHhMmToMinutes(fim)!;
  final sm = parseHhMmToMinutes(saida)!;
  if (em > im || em > fm || em > sm) {
    return 'Entrada deve ser a menor hora do dia.';
  }
  return null;
}

String? validateInicioMaoObra(
  String? value,
  String entrada,
  String fim,
  String saida,
) {
  final err = validateSingleHhMmLenient(value);
  if (err != null) return err;
  final i = value?.trim() ?? '';
  if (!todosHorariosCompletosValidos4(entrada, i, fim, saida)) return null;
  final em = parseHhMmToMinutes(entrada)!;
  final im = parseHhMmToMinutes(i)!;
  final fm = parseHhMmToMinutes(fim)!;
  if (im < em) return 'Início do intervalo não pode ser anterior à entrada.';
  if (im > fm) return 'Início do intervalo deve ser anterior ou igual ao fim.';
  return null;
}

String? validateFimMaoObra(
  String? value,
  String entrada,
  String inicio,
  String saida,
) {
  final err = validateSingleHhMmLenient(value);
  if (err != null) return err;
  final f = value?.trim() ?? '';
  if (!todosHorariosCompletosValidos4(entrada, inicio, f, saida)) return null;
  final im = parseHhMmToMinutes(inicio)!;
  final fm = parseHhMmToMinutes(f)!;
  final sm = parseHhMmToMinutes(saida)!;
  if (fm < im) return 'Fim do intervalo deve ser posterior ou igual ao início.';
  if (fm > sm) return 'Fim do intervalo deve ser anterior ou igual à saída.';
  return null;
}

String? validateSaidaMaoObra(
  String? value,
  String entrada,
  String inicio,
  String fim,
) {
  final err = validateSingleHhMmLenient(value);
  if (err != null) return err;
  final s = value?.trim() ?? '';
  if (!todosHorariosCompletosValidos4(entrada, inicio, fim, s)) return null;
  final em = parseHhMmToMinutes(entrada)!;
  final fm = parseHhMmToMinutes(fim)!;
  final sm = parseHhMmToMinutes(s)!;
  if (sm < em || sm < fm) {
    return 'Saída deve ser a maior hora do dia.';
  }
  return null;
}

void showHorarioErroSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: TextStyle(
          color: FlutterFlowTheme.of(context).primaryBackground,
        ),
      ),
      duration: const Duration(milliseconds: 4500),
      backgroundColor: FlutterFlowTheme.of(context).error,
    ),
  );
}

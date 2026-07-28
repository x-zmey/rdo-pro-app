import '/flutter_flow/relatorio_horarios_validation.dart';
import 'obra_add_relatorio_model.dart';

export '/flutter_flow/relatorio_horarios_validation.dart'
    show
        parseHhMmToMinutes,
        validateSingleHhMm,
        validateSingleHhMmLenient,
        validateHorariosSequenceFromStrings,
        showHorarioErroSnackBar,
        validateEntradaMaoObra,
        validateInicioMaoObra,
        validateFimMaoObra,
        validateSaidaMaoObra;

/// Valida ordem dos quatro horários do relatório (controllers do topo).
String? validateHorariosSequence(ObraAddRelatorioModel model) {
  return validateHorariosSequenceFromStrings(
    entrada: model.textFieldNumeroTextController2?.text ?? '',
    inicio: model.textFieldHorasTextController1?.text ?? '',
    fim: model.textFieldHorasTextController2?.text ?? '',
    saida: model.textFieldHorasTextController3?.text ?? '',
  );
}

String? validateEntradaField(ObraAddRelatorioModel model, String? value) {
  return validateEntradaMaoObra(
    value,
    model.textFieldHorasTextController1?.text ?? '',
    model.textFieldHorasTextController2?.text ?? '',
    model.textFieldHorasTextController3?.text ?? '',
  );
}

String? validateInicioIntervaloField(ObraAddRelatorioModel model, String? value) {
  return validateInicioMaoObra(
    value,
    model.textFieldNumeroTextController2?.text ?? '',
    model.textFieldHorasTextController2?.text ?? '',
    model.textFieldHorasTextController3?.text ?? '',
  );
}

String? validateFimIntervaloField(ObraAddRelatorioModel model, String? value) {
  return validateFimMaoObra(
    value,
    model.textFieldNumeroTextController2?.text ?? '',
    model.textFieldHorasTextController1?.text ?? '',
    model.textFieldHorasTextController3?.text ?? '',
  );
}

String? validateSaidaField(ObraAddRelatorioModel model, String? value) {
  return validateSaidaMaoObra(
    value,
    model.textFieldNumeroTextController2?.text ?? '',
    model.textFieldHorasTextController1?.text ?? '',
    model.textFieldHorasTextController2?.text ?? '',
  );
}

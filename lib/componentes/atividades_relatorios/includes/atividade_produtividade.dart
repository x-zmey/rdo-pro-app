import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/custom_functions.dart';

/// Alinha `frontend/.../atividadeProdutividade.js`.

double qtdRealizadaAtividadeNum(GetDadosAtividadeRow? atividade) {
  if (atividade == null) return 0;
  return parseQuantidadeRelatorio(atividade.data['qtd_realizada']);
}

/// Teto efetivo: prioriza o valor digitado no formulário (ainda não salvo no SQLite).
double limiteProdutividadeEfetivo({
  required GetDadosAtividadeRow? atividade,
  num? qtdRealizadaFormulario,
}) {
  if (qtdRealizadaFormulario != null) {
    return qtdRealizadaFormulario.toDouble();
  }
  return qtdRealizadaAtividadeNum(atividade);
}

String unidadeProdutividadeAtividade(GetDadosAtividadeRow? atividade) {
  final u = (atividade?.unidade ?? '').trim();
  return u.isEmpty ? 'un' : u;
}

double somaProdutividadeItens(
  List<GetItensAtividadeRow> itens, {
  int? ignorarItemId,
}) {
  var total = 0.0;
  for (final row in itens) {
    if (ignorarItemId != null && row.id == ignorarItemId) continue;
    total += parseQuantidadeRelatorio(row.data['qtd_produzida']);
  }
  return total;
}

double maxProdutividadeItem(
  List<GetItensAtividadeRow> itens,
  GetDadosAtividadeRow? atividade,
  int? itemId, {
  num? qtdRealizadaFormulario,
}) {
  final limite = limiteProdutividadeEfetivo(
    atividade: atividade,
    qtdRealizadaFormulario: qtdRealizadaFormulario,
  );
  final outros = somaProdutividadeItens(itens, ignorarItemId: itemId);
  final max = limite - outros;
  return max > 0 ? max : 0;
}

class ValidacaoProdutividadeResultado {
  const ValidacaoProdutividadeResultado.ok({
    required this.limite,
    required this.total,
  })  : ok = true,
        message = null;

  const ValidacaoProdutividadeResultado.erro({
    required this.limite,
    required this.total,
    required this.message,
  }) : ok = false;

  final bool ok;
  final double limite;
  final double total;
  final String? message;
}

String _fmtProd(num n) {
  final v = n.toDouble();
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toStringAsFixed(2).replaceAll('.', ',');
}

ValidacaoProdutividadeResultado validarProdutividadeItem({
  required List<GetItensAtividadeRow> itens,
  required GetItensAtividadeRow? item,
  required GetDadosAtividadeRow? atividade,
  required num qtdProduzida,
  String tipoLabel = 'recursos',
  num? qtdRealizadaFormulario,
}) {
  final limite = limiteProdutividadeEfetivo(
    atividade: atividade,
    qtdRealizadaFormulario: qtdRealizadaFormulario,
  );
  final valor = qtdProduzida.toDouble();
  final somaOutros = somaProdutividadeItens(
    itens,
    ignorarItemId: item?.id,
  );
  final total = somaOutros + valor;
  final unidade = unidadeProdutividadeAtividade(atividade);
  final unidadeFmt = unidade.isNotEmpty ? ' $unidade' : '';

  if (total - limite > 1e-6) {
    return ValidacaoProdutividadeResultado.erro(
      limite: limite,
      total: total,
      message:
          'A soma da produtividade da $tipoLabel (${_fmtProd(total)}$unidadeFmt) '
          'não pode ultrapassar a quantidade realizada da atividade '
          '(${_fmtProd(limite)}$unidadeFmt).',
    );
  }

  return ValidacaoProdutividadeResultado.ok(limite: limite, total: total);
}

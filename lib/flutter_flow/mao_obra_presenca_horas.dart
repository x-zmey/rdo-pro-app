/// Horas a persistir em `relatorio_mao_obra_presenca` conforme o status.
/// Ausente/licença/etc. → `0`. Presente/atrasado com valor vazio → `''` (sync recalcula).
String horasTrabalhadasParaPersistir(String? statusPresenca, [String? horasAtuais]) {
  final statusNorm = (statusPresenca ?? '').trim().toLowerCase();
  if (statusNorm != 'presente' && statusNorm != 'atrasado') {
    return '0';
  }
  final h = (horasAtuais ?? '').trim().replaceAll(',', '.');
  if (h.isEmpty || h == '0' || h == '0.0' || h == '0.00') {
    return '';
  }
  return horasAtuais!.replaceAll("'", "''");
}

bool statusPresencaContabilizaHoras(String? statusPresenca) {
  final s = (statusPresenca ?? '').trim().toLowerCase();
  return s == 'presente' || s == 'atrasado';
}

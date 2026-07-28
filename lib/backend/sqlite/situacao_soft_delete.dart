/// Convenção alinhada ao servidor Laravel (`SoftDeletesBySituacao`) e ao MySQL.
///
/// - [kSituacaoAtivo]: registro visível / válido para listagens e sync.
/// - [kSituacaoExcluidoLogico]: exclusão lógica (soft delete); não apagar a linha no SQLite.
const int kSituacaoAtivo = 1;

/// Valor usado em `UPDATE ... SET situacao = ...` para marcar como removido sem `DELETE`.
const int kSituacaoExcluidoLogico = -2;

/// Fragmento SQL: registro ativo (`situacao` NULL ou diferente de [-2]).
/// [alias] opcional (ex.: `o` → `o.situacao`).
String sqlNaoExcluidoPorSituacao([String? alias]) {
  final p = alias == null || alias.isEmpty ? '' : '$alias.';
  return '(${p}situacao IS NULL OR CAST(${p}situacao AS INTEGER) != $kSituacaoExcluidoLogico)';
}

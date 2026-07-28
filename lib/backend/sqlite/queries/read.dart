import '/backend/sqlite/queries/sqlite_row.dart';
import '/backend/sqlite/situacao_soft_delete.dart';
import 'package:sqflite/sqflite.dart';

Future<List<T>> _readQuery<T>(
  Database database,
  String query,
  T Function(Map<String, dynamic>) create,
) =>
    database.rawQuery(query).then((r) => r.map((e) => create(e)).toList());

/// BEGIN CARREGAOBRAS
Future<List<CarregaObrasRow>> performCarregaObras(
  Database database, {
  String? creatorUuid,
  String? currentUserUuid,
  int? tenantUserId,
  List<int>? allowedObraIds,
  bool? forceObraTravada,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final tenantId = tenantUserId ?? 0;
  final allowedIds = (allowedObraIds ?? [])
      .where((id) => id > 0)
      .toSet()
      .toList();
  final allowedInSql =
      allowedIds.isEmpty ? '' : allowedIds.map((id) => id.toString()).join(',');

  final obraTravadaFromDb = tenantId > 0
      ? '''
COALESCE(
  (SELECT eu.obra_travada FROM empresa_users AS eu
   WHERE eu.user_uuid = '${esc(currentUserUuid)}'
     AND eu.tenant_user_id = $tenantId
   LIMIT 1),
  (SELECT u.obra_travada FROM users AS u WHERE u.uuid = '${esc(currentUserUuid)}' LIMIT 1),
  0
)'''
      : '''
COALESCE(
  (SELECT u.obra_travada FROM users AS u WHERE u.uuid = '${esc(currentUserUuid)}' LIMIT 1),
  0
)''';
  // AppState (login) tem prioridade sobre SQLite atrasado no sync.
  final obraTravadaExpr = forceObraTravada == true
      ? '1'
      : (forceObraTravada == false ? '0' : obraTravadaFromDb);
  final tenantObraExists = tenantId > 0
      ? '''
EXISTS (
  SELECT 1
  FROM empresa_user_obra AS euo
  INNER JOIN empresa_users AS eu
    ON eu.id_server = euo.empresa_user_id_server
    OR eu.id = euo.empresa_user_id
  WHERE eu.tenant_user_id = $tenantId
    AND eu.user_uuid = '${esc(currentUserUuid)}'
    AND (
      (euo.obra_uuid IS NOT NULL AND euo.obra_uuid != '' AND euo.obra_uuid = o.uuid)
      OR ((euo.obra_uuid IS NULL OR euo.obra_uuid = '') AND euo.obra_id = o.id)
    )
    AND (euo.situacao IS NULL OR CAST(euo.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
)
OR '''
      : '';

  // Quando o login já trouxe allowed_obra_ids, aceita essas obras mesmo sem
  // vínculo local ainda sincronizado (evita lista vazia no iPhone/Android).
  final allowedIdsExists = allowedInSql.isNotEmpty
      ? 'o.id IN ($allowedInSql) OR '
      : '';

  final query = '''
SELECT o.*
FROM obras AS o
WHERE (
  (
    $obraTravadaExpr = 1
    AND o.user_uuid = '${esc(creatorUuid)}'
    AND (
      $allowedIdsExists
      $tenantObraExists
      EXISTS (
      SELECT 1
      FROM user_obras AS uo
      WHERE
        (
          (uo.obra_uuid IS NOT NULL AND uo.obra_uuid != '' AND uo.obra_uuid = o.uuid)
          OR
          ((uo.obra_uuid IS NULL OR uo.obra_uuid = '') AND uo.obra_id = o.id)
        )
        AND
        (
          (uo.user_uuid IS NOT NULL AND uo.user_uuid != '' AND uo.user_uuid = '${esc(currentUserUuid)}')
          OR
          (
            (uo.user_uuid IS NULL OR uo.user_uuid = '')
            AND uo.user_id = (
              SELECT id FROM users WHERE uuid = '${esc(currentUserUuid)}' LIMIT 1
            )
          )
        )
        AND (uo.situacao IS NULL OR CAST(uo.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
    )
    )
  )
  OR (
    $obraTravadaExpr != 1
    AND o.user_uuid = '${esc(creatorUuid)}'
  )
)
AND (o.situacao IS NULL OR CAST(o.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
ORDER BY o.nome;
''';
  return _readQuery(database, query, (d) => CarregaObrasRow(d));
}

class CarregaObrasRow extends SqliteRow {
  CarregaObrasRow(Map<String, dynamic> data) : super(data);

  String get nome => data['nome'] as String;
  int get id => data['id'] as int;
  String? get uuidPai => data['uuid_pai'] as String?;
  String get uuid => data['uuid'] as String;
  String? get userUuid => data['user_uuid'] as String?;

  String? get rua => data['rua'] as String?;
  String? get numero => data['numero'] as String?;
  String? get bairro => data['bairro'] as String?;
  String? get cidade => data['cidade'] as String?;
  String? get estado => data['estado'] as String?;
  String? get contrato => data['contrato'] as String?;
  String? get engenheiro => data['engenheiro'] as String?;
  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;

  int? get situacaoId {
    final v = data['situacao_id'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// END CARREGAOBRAS

/// BEGIN CARREGAPLANOS
Future<List<CarregaPlanosRow>> performCarregaPlanos(
  Database database,
) {
  final query = '''
select * from planos
''';
  return _readQuery(database, query, (d) => CarregaPlanosRow(d));
}

class CarregaPlanosRow extends SqliteRow {
  CarregaPlanosRow(Map<String, dynamic> data) : super(data);

  String get nome => data['nome'] as String;
}

/// END CARREGAPLANOS

/// BEGIN OBRADETALHES
Future<List<ObraDetalhesRow>> performObraDetalhes(
  Database database, {
  String? uuid,
  int? userId,
  /// [obras.user_uuid] do assinante (conta SaaS). Sem isto, outro tenant
  /// com o UUID na mesma base local veria a obra indevidamente.
  String? accountOwnerUuid,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final owner = (accountOwnerUuid ?? '').trim();
  if (owner.isEmpty) {
    return Future.value(<ObraDetalhesRow>[]);
  }
  final query = '''
SELECT * FROM obras WHERE uuid = '${esc(uuid)}' AND user_uuid = '${esc(owner)}'
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
''';
  return _readQuery(database, query, (d) => ObraDetalhesRow(d));
}

class ObraDetalhesRow extends SqliteRow {
  ObraDetalhesRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get nome => data['nome'] as String;
  String get uuid => data['uuid'] as String;
  String? get rua => data['rua'] as String?;
  String? get numero => data['numero'] as String?;
  String? get complemento => data['complemento'] as String?;
  String? get bairro => data['bairro'] as String?;
  String? get cidade => data['cidade'] as String?;
  String? get estado => data['estado'] as String?;
  int? get situacaoId => data['situacao_id'] as int?;

  int? get grupoId {
    final v = data['grupo_id'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get grupoUuid => data['grupo_uuid'] as String?;

  int? get clienteId {
    final v = data['cliente_id'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get clienteUuid => data['cliente_uuid'] as String?;

  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;
  String? get contrato => data['contrato'] as String?;
  String? get engenheiro => data['engenheiro'] as String?;
}

/// END OBRADETALHES

/// BEGIN RELATORIOSOBRA
Future<List<RelatoriosObraRow>> performRelatoriosObra(
  Database database, {
  String? obraUuid,
  String? accountOwnerUuid,
  int? limit,
  int? offset,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final owner = (accountOwnerUuid ?? '').trim();
  if (owner.isEmpty) {
    return Future.value(<RelatoriosObraRow>[]);
  }
  var limitOffset = '';
  if (limit != null) {
    final lim = limit.clamp(1, 500);
    final off = (offset ?? 0).clamp(0, 1000000);
    limitOffset = ' LIMIT $lim OFFSET $off';
  }
  final query = '''
SELECT
  r.*,
  sr.nome AS status_nome,
  COALESCE(
    u_criador_uuid.nome,
    u_criador_id.nome,
    u_created_by_uuid.nome,
    u_created_by_id.nome
  ) AS criador_nome
FROM relatorios AS r
INNER JOIN obras AS ob ON ob.uuid = r.obra_uuid AND ob.user_uuid = '${esc(owner)}'
  AND (ob.situacao IS NULL OR CAST(ob.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
LEFT JOIN status_relatorios AS sr
  ON sr.id = r.status_id
LEFT JOIN users AS u_criador_uuid
  ON u_criador_uuid.uuid = r.criador
LEFT JOIN users AS u_criador_id
  ON CAST(u_criador_id.id AS TEXT) = CAST(r.criador AS TEXT)
LEFT JOIN users AS u_created_by_uuid
  ON u_created_by_uuid.uuid = r.created_by
LEFT JOIN users AS u_created_by_id
  ON CAST(u_created_by_id.id AS TEXT) = CAST(r.created_by AS TEXT)
WHERE r.obra_uuid = '${esc(obraUuid)}'
  AND (r.situacao IS NULL OR CAST(r.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
ORDER BY COALESCE(NULLIF(trim(r.updated_at), ''), r.created_at) DESC, r.numero DESC, r.id DESC$limitOffset;
''';
  return _readQuery(database, query, (d) => RelatoriosObraRow(d));
}

class RelatoriosObraRow extends SqliteRow {
  RelatoriosObraRow(Map<String, dynamic> data) : super(data);

  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;
  int get id => data['id'] as int;
  String get dataExecutado => data['data_executado'] as String;
  int? get numero => data['numero'] as int?;
  String get uuid => data['uuid'] as String;
  String get obraUuid => data['obra_uuid'] as String;
  int? get statusId => data['status_id'] as int?;
  String? get statusNome => data['status_nome'] as String?;
  String? get criador => data['criador'] as String?;
  String? get criadorNome => data['criador_nome'] as String?;
}

/// Lista relatórios do [accountOwnerUuid], paginada.
/// Com [allowedObraUuids] (obra_travada), restringe às obras permitidas.
Future<List<RelatoriosGeraisRow>> performRelatoriosGerais(
  Database database, {
  required int limit,
  required int offset,
  String? accountOwnerUuid,
  List<String>? allowedObraUuids,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final owner = (accountOwnerUuid ?? '').trim();
  if (owner.isEmpty) {
    return Future.value(<RelatoriosGeraisRow>[]);
  }
  final allowed = (allowedObraUuids ?? [])
      .map((u) => u.trim())
      .where((u) => u.isNotEmpty)
      .toSet()
      .toList();
  // obra_travada ativa mas sem UUID resolvido → lista vazia (não vazar tudo).
  if (allowedObraUuids != null && allowed.isEmpty) {
    return Future.value(<RelatoriosGeraisRow>[]);
  }
  final allowedFilter = allowed.isEmpty
      ? ''
      : "AND r.obra_uuid IN (${allowed.map((u) => "'${esc(u)}'").join(',')})";
  final li = limit.clamp(1, 500);
  final off = offset < 0 ? 0 : offset;
  final query = '''
SELECT
  r.*,
  sr.nome AS status_nome,
  COALESCE(
    u_criador_uuid.nome,
    u_criador_id.nome,
    u_created_by_uuid.nome,
    u_created_by_id.nome
  ) AS criador_nome,
  o.nome AS obra_nome
FROM relatorios AS r
INNER JOIN obras AS o ON o.uuid = r.obra_uuid AND o.user_uuid = '${esc(owner)}'
  AND (o.situacao IS NULL OR CAST(o.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
LEFT JOIN status_relatorios AS sr
  ON sr.id = r.status_id
LEFT JOIN users AS u_criador_uuid
  ON u_criador_uuid.uuid = r.criador
LEFT JOIN users AS u_criador_id
  ON CAST(u_criador_id.id AS TEXT) = CAST(r.criador AS TEXT)
LEFT JOIN users AS u_created_by_uuid
  ON u_created_by_uuid.uuid = r.created_by
LEFT JOIN users AS u_created_by_id
  ON CAST(u_created_by_id.id AS TEXT) = CAST(r.created_by AS TEXT)
WHERE (r.situacao IS NULL OR CAST(r.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
$allowedFilter
ORDER BY COALESCE(r.data_executado, ''), r.id DESC
LIMIT $li OFFSET $off
''';
  return _readQuery(database, query, (d) => RelatoriosGeraisRow(d));
}

class RelatoriosGeraisRow extends SqliteRow {
  RelatoriosGeraisRow(Map<String, dynamic> data) : super(data);

  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;
  int get id => data['id'] as int;
  String get dataExecutado => data['data_executado'] as String;
  int? get numero => data['numero'] as int?;
  String get uuid => data['uuid'] as String;
  String get obraUuid => data['obra_uuid'] as String;
  int? get statusId => data['status_id'] as int?;
  String? get statusNome => data['status_nome'] as String?;
  String? get criador => data['criador'] as String?;
  String? get criadorNome => data['criador_nome'] as String?;
  String? get obraNome => data['obra_nome'] as String?;
}

/// END RELATORIOSOBRA

/// BEGIN RELATORIODETALHES
Future<List<RelatorioDetalhesRow>> performRelatorioDetalhes(
  Database database, {
  String? uuid,
  String? userUuid,
  String? accountOwnerUuid,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final owner = (accountOwnerUuid ?? '').trim();
  if (owner.isEmpty) {
    return Future.value(<RelatorioDetalhesRow>[]);
  }
  final query = '''
SELECT r.*
FROM relatorios r
INNER JOIN obras AS o ON o.uuid = r.obra_uuid AND o.user_uuid = '${esc(owner)}'
  AND (o.situacao IS NULL OR CAST(o.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
WHERE r.uuid = '${esc(uuid)}'
  AND ${sqlNaoExcluidoPorSituacao('r')}
LIMIT 1;

''';
  return _readQuery(database, query, (d) => RelatorioDetalhesRow(d));
}

class RelatorioDetalhesRow extends SqliteRow {
  RelatorioDetalhesRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get dataExecutado => data['data_executado'] as String?;
  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;
  int get obraId => data['obra_id'] as int;
  int? get numero => data['numero'] as int?;
  String? get entradaManha => data['entrada_manha'] as String?;
  String? get inicioIntervalo => data['inicio_intervalo'] as String?;
  String? get fimIntervalo => data['fim_intervalo'] as String?;
  String? get saidaTarde => data['saida_tarde'] as String?;
  int get statusId => data['status_id'] as int;
  String? get uuid => data['uuid'] as String?;
  String get obraUuid => data['obra_uuid'] as String;
}

/// END RELATORIODETALHES

/// BEGIN MODELOSRELATORIOS
Future<List<ModelosRelatoriosRow>> performModelosRelatorios(
  Database database, {
  String? obraUuid,
  String? accountOwnerUuid,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final owner = (accountOwnerUuid ?? '').trim();
  if (owner.isEmpty) {
    return Future.value(<ModelosRelatoriosRow>[]);
  }
  final query = '''
SELECT m.*
FROM modelo_relatorios AS m
INNER JOIN obras AS o ON o.uuid = m.obra_uuid AND o.user_uuid = '${esc(owner)}'
  AND (o.situacao IS NULL OR CAST(o.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
WHERE m.obra_uuid = '${esc(obraUuid)}'
  AND ${sqlNaoExcluidoPorSituacao('m')}
''';
  return _readQuery(database, query, (d) => ModelosRelatoriosRow(d));
}

class ModelosRelatoriosRow extends SqliteRow {
  ModelosRelatoriosRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get nome => data['nome'] as String;
  String get uuid => data['uuid'] as String;
  String? get logomarcaFotos => data['logomarca_fotos'] as String?;
}

/// END MODELOSRELATORIOS

/// BEGIN CARREGAULTIMORELATORIO
Future<List<CarregaUltimoRelatorioRow>> performCarregaUltimoRelatorio(
  Database database, {
  String? accountOwnerUuid,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final owner = (accountOwnerUuid ?? '').trim();
  if (owner.isEmpty) {
    return Future.value(<CarregaUltimoRelatorioRow>[]);
  }
  final query = '''
SELECT r.*
FROM relatorios r
INNER JOIN obras AS o ON o.uuid = r.obra_uuid AND o.user_uuid = '${esc(owner)}'
  AND (o.situacao IS NULL OR CAST(o.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
WHERE (r.situacao IS NULL OR CAST(r.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
ORDER BY r.numero DESC
LIMIT 1
''';
  return _readQuery(database, query, (d) => CarregaUltimoRelatorioRow(d));
}

class CarregaUltimoRelatorioRow extends SqliteRow {
  CarregaUltimoRelatorioRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get dataExecutado => data['data_executado'] as String;
  int? get numero => data['numero'] as int?;
  String? get uuid => data['uuid'] as String?;
}

/// END CARREGAULTIMORELATORIO

/// BEGIN LISTACOMENTARIOSRELATORIOS
Future<List<ListaComentariosRelatoriosRow>> performListaComentariosRelatorios(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT * FROM relatorio_comentarios WHERE relatorio_uuid = '${relatorioUuid}'
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
''';
  return _readQuery(database, query, (d) => ListaComentariosRelatoriosRow(d));
}

class ListaComentariosRelatoriosRow extends SqliteRow {
  ListaComentariosRelatoriosRow(Map<String, dynamic> data) : super(data);

  String? get texto => data['texto'] as String?;
  String get createdBy => data['created_by'] as String;
  String? get createdAt => data['created_at'] as String?;
  int get id => data['id'] as int;
  String get uuid => data['uuid'] as String;
}

/// END LISTACOMENTARIOSRELATORIOS

/// BEGIN CARREGAOCORRENCIASRELATORIO
Future<List<CarregaOcorrenciasRelatorioRow>> performCarregaOcorrenciasRelatorio(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT
  o.*,
  tp.nome AS tipo_nome,
  u.nome AS autor_nome
FROM relatorio_ocorrencias AS o
LEFT JOIN tipo_ocorrencias AS tp ON tp.uuid = o.tipo_uuid
LEFT JOIN users AS u ON u.uuid = o.created_by
WHERE o.relatorio_uuid = '${relatorioUuid}'
  AND ${sqlNaoExcluidoPorSituacao('o')}
ORDER BY o.id ASC
''';
  return _readQuery(database, query, (d) => CarregaOcorrenciasRelatorioRow(d));
}

class CarregaOcorrenciasRelatorioRow extends SqliteRow {
  CarregaOcorrenciasRelatorioRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get descricao => data['descricao'] as String? ?? '';
  String get uuid => data['uuid'] as String;
  String? get horaInicio => data['hora_inicio'] as String?;
  String? get horaSaida => data['hora_saida'] as String?;
  String? get tipoNome => data['tipo_nome'] as String?;
  String? get autorNome => data['autor_nome'] as String?;

  int? get situacao {
    final v = data['situacao'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// END CARREGAOCORRENCIASRELATORIO

/// BEGIN CARREGAITENSOBRA
Future<List<CarregaItensObraRow>> performCarregaItensObra(
  Database database, {
  String? tipo,
  int? obraId,
  String? obraUuid,
}) {
  final query = '''
SELECT * FROM obra_itens
WHERE obra_uuid = '${obraUuid}' AND tipo = '${tipo}'
  AND ${sqlNaoExcluidoPorSituacao()}
''';
  return _readQuery(database, query, (d) => CarregaItensObraRow(d));
}

class CarregaItensObraRow extends SqliteRow {
  CarregaItensObraRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] is int
      ? data['id'] as int
      : int.tryParse(data['id']?.toString() ?? '') ?? 0;
  String? get tipo => data['tipo']?.toString();
  String get descricao => data['descricao']?.toString() ?? '';
  int? get qtd {
    final v = data['qtd'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get unidade => data['unidade']?.toString();
  String? get valorUnitario => data['valor_unitario']?.toString();

  /// SQLite pode devolver int/real; antes era cast direto para String e quebrava.
  String? get qtdRealizada => data['qtd_realizada']?.toString();
  String? get cargoFuncao => data['cargo_funcao']?.toString();
  String? get tipoMaoObra => data['tipo_mao_obra']?.toString();

  int? get situacao {
    final v = data['situacao'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String get uuid => data['uuid']?.toString() ?? '';
}

/// END CARREGAITENSOBRA

/// BEGIN CARREGACOMENTARIOSOBRA
Future<List<CarregaComentariosObraRow>> performCarregaComentariosObra(
  Database database, {
  String? obraUuid,
}) {
  final query = '''
SELECT
  oco.*,
  rel.numero AS relatorio_numero,
  rel.criador AS relatorio_criador,
  COALESCE(
    u_criador_uuid.nome,
    u_criador_id.nome,
    u_comentario.nome
  ) AS autor_nome
FROM relatorio_comentarios AS oco
JOIN relatorios AS rel ON rel.uuid = oco.relatorio_uuid
LEFT JOIN users AS u_criador_uuid
  ON u_criador_uuid.uuid = rel.criador
LEFT JOIN users AS u_criador_id
  ON CAST(u_criador_id.id AS TEXT) = CAST(rel.criador AS TEXT)
LEFT JOIN users AS u_comentario
  ON u_comentario.uuid = oco.created_by
WHERE rel.obra_uuid = '${obraUuid}'
  AND ${sqlNaoExcluidoPorSituacao('rel')}
  AND ${sqlNaoExcluidoPorSituacao('oco')}
ORDER BY oco.created_at DESC
''';
  return _readQuery(database, query, (d) => CarregaComentariosObraRow(d));
}

class CarregaComentariosObraRow extends SqliteRow {
  CarregaComentariosObraRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get texto => data['texto'] as String?;
  String? get createdAt => data['created_at'] as String?;

  /// UUID do usuário autor (texto em `relatorio_comentarios.created_by`).
  String? get createdBy => data['created_by'] as String?;
  String get uuid => data['uuid'] as String;

  int? get relatorioNumero {
    final v = data['relatorio_numero'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get autorNome => data['autor_nome'] as String?;

  /// Valor bruto de `relatorios.criador` (uuid ou id do usuário).
  String? get relatorioCriador => data['relatorio_criador'] as String?;
}

/// END CARREGACOMENTARIOSOBRA

/// BEGIN CARREGAOCORRENCIASOBRA
Future<List<CarregaOcorrenciasObraRow>> performCarregaOcorrenciasObra(
  Database database, {
  String? obraUuid,
}) {
  final query = '''
SELECT
  oco.*,
  rel.numero AS relatorio_numero,
  rel.data_executado AS relatorio_data,
  rel.criador AS relatorio_criador,
  tp.nome AS tipo_nome,
  COALESCE(
    u_criador_uuid.nome,
    u_criador_id.nome,
    u_ocorrencia.nome
  ) AS autor_nome
FROM relatorio_ocorrencias AS oco
JOIN relatorios AS rel ON rel.uuid = oco.relatorio_uuid
LEFT JOIN tipo_ocorrencias AS tp ON tp.uuid = oco.tipo_uuid
LEFT JOIN users AS u_criador_uuid
  ON u_criador_uuid.uuid = rel.criador
LEFT JOIN users AS u_criador_id
  ON CAST(u_criador_id.id AS TEXT) = CAST(rel.criador AS TEXT)
LEFT JOIN users AS u_ocorrencia
  ON u_ocorrencia.uuid = oco.created_by
  OR CAST(u_ocorrencia.id AS TEXT) = TRIM(CAST(oco.created_by AS TEXT))
WHERE rel.obra_uuid = '${obraUuid}'
  AND ${sqlNaoExcluidoPorSituacao('rel')}
  AND ${sqlNaoExcluidoPorSituacao('oco')}
ORDER BY oco.id DESC
''';
  return _readQuery(database, query, (d) => CarregaOcorrenciasObraRow(d));
}

class CarregaOcorrenciasObraRow extends SqliteRow {
  CarregaOcorrenciasObraRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get descricao => data['descricao'] as String?;
  String? get createdAt => data['created_at'] as String?;
  String get uuid => data['uuid'] as String;
  String? get horaInicio => data['hora_inicio'] as String?;
  String? get horaSaida => data['hora_saida'] as String?;
  String? get tipoNome => data['tipo_nome'] as String?;
  String? get autorNome => data['autor_nome'] as String?;
  String? get relatorioData => data['relatorio_data'] as String?;
  String? get relatorioCriador => data['relatorio_criador'] as String?;

  int? get relatorioNumero {
    final v = data['relatorio_numero'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// END CARREGAOCORRENCIASOBRA

/// BEGIN LISTAETAPASOBRA
Future<List<ListaEtapasObraRow>> performListaEtapasObra(
  Database database, {
  String? obraUuid,
}) {
  final query = '''
SELECT * FROM obra_etapas
WHERE obra_uuid = '${obraUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
''';
  return _readQuery(database, query, (d) => ListaEtapasObraRow(d));
}

class ListaEtapasObraRow extends SqliteRow {
  ListaEtapasObraRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get item => data['item'] as String?;
  String? get nome => data['nome'] as String?;
  String get uuid => data['uuid'] as String;
}

/// END LISTAETAPASOBRA

/// BEGIN LISTATAREFASETAPASOBRA
Future<List<ListaTarefasEtapasObraRow>> performListaTarefasEtapasObra(
  Database database, {
  String? etapaUuid,
}) {
  final query = '''
SELECT * FROM obra_etapa_tarefas
WHERE etapa_uuid = '${etapaUuid}' AND tipo = 'tarefa'
  AND ${sqlNaoExcluidoPorSituacao()}
''';
  return _readQuery(database, query, (d) => ListaTarefasEtapasObraRow(d));
}

class ListaTarefasEtapasObraRow extends SqliteRow {
  ListaTarefasEtapasObraRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get tipo => data['tipo'] as String?;
  String? get descricao => data['descricao'] as String?;
  String? get item => data['item'] as String?;
  double? get porcentagem {
    final v = data['porcentagem'];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String get uuid => data['uuid'] as String;

  String? get tarefaPaiUuid {
    final v = data['tarefa_pai_uuid'];
    if (v == null) return null;
    final s = v.toString();
    return s.isEmpty ? null : s;
  }

  int? get tarefaPai {
    final v = data['tarefa_pai'];
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  double? get qtd {
    final v = data['qtd'];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? get unidade {
    final v = data['unidade'];
    if (v == null) return null;
    return v.toString();
  }

  double? get valorUnitario {
    final v = data['valor_unitario'];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  double? get meta {
    final v = data['meta'];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? get metaUnidade {
    final v = data['meta_unidade'];
    if (v == null) return null;
    return v.toString();
  }
}

/// Itens de planejamento da etapa (tarefas + composições), excluindo excluídos.
Future<List<ListaTarefasEtapasObraRow>> performListaPlanejamentoEtapasObra(
  Database database, {
  String? etapaUuid,
}) {
  final query = '''
SELECT * FROM obra_etapa_tarefas
WHERE etapa_uuid = '${etapaUuid}'
AND (situacao IS NULL OR situacao != ${kSituacaoExcluidoLogico})
ORDER BY item
''';
  return _readQuery(database, query, (d) => ListaTarefasEtapasObraRow(d));
}

/// END LISTATAREFASETAPASOBRA

/// BEGIN ULTIMOSRELATORIOSOBRA
Future<List<UltimosRelatoriosObraRow>> performUltimosRelatoriosObra(
  Database database, {
  int? obraId,
  int? userId,
}) {
  final query = '''
SELECT *
FROM relatorios
WHERE obra_id = ${obraId} AND user_id = ${userId}
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
ORDER BY COALESCE(NULLIF(trim(updated_at), ''), created_at) DESC, numero DESC, id DESC
LIMIT 7 OFFSET 0;
''';
  return _readQuery(database, query, (d) => UltimosRelatoriosObraRow(d));
}

class UltimosRelatoriosObraRow extends SqliteRow {
  UltimosRelatoriosObraRow(Map<String, dynamic> data) : super(data);

  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;
  int get id => data['id'] as int;
  String get dataExecutado => data['data_executado'] as String;
  int? get numero => data['numero'] as int?;
}

/// END ULTIMOSRELATORIOSOBRA

/// BEGIN CARREGAANEXOSRELATORIO
Future<List<CarregaAnexosRelatorioRow>> performCarregaAnexosRelatorio(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT * FROM relatorio_anexos WHERE relatorio_uuid = '${relatorioUuid}'
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
''';
  return _readQuery(database, query, (d) => CarregaAnexosRelatorioRow(d));
}

class CarregaAnexosRelatorioRow extends SqliteRow {
  CarregaAnexosRelatorioRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
  String get arquivo => data['arquivo'] as String;
  String get uuid => data['uuid'] as String;
}

/// END CARREGAANEXOSRELATORIO

/// BEGIN EQUIPAMENTOSRECEBIDOSOBRA
Future<List<EquipamentosRecebidosObraRow>> performEquipamentosRecebidosObra(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT 
  rer.id,
  rer.uuid,
  rer.equipamento_id,
  rer.equipamento_uuid,
  rer.quantidade,
  oi.descricao,
  oi.unidade
FROM relatorio_equipamento_recebido AS rer
JOIN obra_itens AS oi 
  ON oi.uuid = rer.equipamento_uuid
WHERE rer.relatorio_uuid = '${relatorioUuid}'
  AND ${sqlNaoExcluidoPorSituacao('rer')}
  AND ${sqlNaoExcluidoPorSituacao('oi')};
''';
  return _readQuery(database, query, (d) => EquipamentosRecebidosObraRow(d));
}

class EquipamentosRecebidosObraRow extends SqliteRow {
  EquipamentosRecebidosObraRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  int get equipamentoId => data['equipamento_id'] as int;
  num? get quantidade => data['quantidade'] as num?;
  String? get uuid => data['uuid'] as String?;
  String? get equipamentoUuid => data['equipamento_uuid'] as String?;
  String? get descricao => data['descricao'] as String?;
  String? get unidade => data['unidade'] as String?;
}

/// END EQUIPAMENTOSRECEBIDOSOBRA

/// BEGIN DETALHESMATERIALRECEBIDO
Future<List<DetalhesMaterialRecebidoRow>> performDetalhesMaterialRecebido(
  Database database, {
  String? uuid,
}) {
  final query = '''
SELECT * FROM obra_itens
WHERE uuid = '${uuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
LIMIT 1;
''';
  return _readQuery(database, query, (d) => DetalhesMaterialRecebidoRow(d));
}

class DetalhesMaterialRecebidoRow extends SqliteRow {
  DetalhesMaterialRecebidoRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get descricao => data['descricao'] as String?;
  String? get unidade => data['unidade'] as String?;
  String get uuid => data['uuid'] as String;
}

/// END DETALHESMATERIALRECEBIDO

/// BEGIN CARREGAULTIMAATIVIDADERELATORIO
Future<List<CarregaUltimaAtividadeRelatorioRow>>
    performCarregaUltimaAtividadeRelatorio(
  Database database,
) {
  final query = '''
SELECT * FROM relatorio_atividades WHERE id = last_insert_rowid();
''';
  return _readQuery(
      database, query, (d) => CarregaUltimaAtividadeRelatorioRow(d));
}

class CarregaUltimaAtividadeRelatorioRow extends SqliteRow {
  CarregaUltimaAtividadeRelatorioRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get uuid => data['uuid'] as String?;
}

/// END CARREGAULTIMAATIVIDADERELATORIO

/// BEGIN GETITENSDAOBRA
Future<List<GetitensdaobraRow>> performGetitensdaobra(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT 
  r.equipamento_id AS id,
  r.equipamento_uuid AS uuid,
  o.descricao AS nome
FROM relatorio_equipamento_recebido r
JOIN obra_itens o ON o.uuid = r.equipamento_uuid
WHERE r.relatorio_uuid = '${relatorioUuid}'
  AND ${sqlNaoExcluidoPorSituacao('r')}
  AND ${sqlNaoExcluidoPorSituacao('o')}
ORDER BY o.descricao;

''';
  return _readQuery(database, query, (d) => GetitensdaobraRow(d));
}

class GetitensdaobraRow extends SqliteRow {
  GetitensdaobraRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
  String? get uuid => data['uuid'] as String?;
}

/// END GETITENSDAOBRA

/// BEGIN GETITENSATIVIDADE
Future<List<GetItensAtividadeRow>> performGetItensAtividade(
  Database database, {
  String? atividadeUuid,
  String? tipo,
}) {
  final query = '''
SELECT 
  rai.id,
  rai.uuid,
  rai.relatorio_atividade_id,
  rai.relatorio_atividade_uuid,
  rai.tipo,
  rai.obra_item_id,
  rai.obra_item_uuid,
  rai.qtd_realizada,
  rai.qtd_utilizada,
  rai.qtd_produzida,
  oi.descricao,
  oi.cargo_funcao,
  oi.qtd AS obra_item_qtd,
  oi.unidade AS obra_item_unidade
FROM relatorio_atividades_itens AS rai
INNER JOIN relatorio_atividades AS ra
  ON ra.uuid = rai.relatorio_atividade_uuid
JOIN obra_itens AS oi 
  ON oi.uuid = rai.obra_item_uuid
WHERE rai.relatorio_atividade_uuid = '${atividadeUuid}' AND rai.tipo = '${tipo}'
  AND ${sqlNaoExcluidoPorSituacao('rai')}
  AND ${sqlNaoExcluidoPorSituacao('ra')}
  AND ${sqlNaoExcluidoPorSituacao('oi')};

''';
  return _readQuery(database, query, (d) => GetItensAtividadeRow(d));
}

class GetItensAtividadeRow extends SqliteRow {
  GetItensAtividadeRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  int? get obraItemId => data['obra_item_id'] as int?;
  int? get qtdUtilizada => data['qtd_utilizada'] as int?;
  int? get qtdRealizada => data['qtd_realizada'] as int?;
  num? get qtdProduzida {
    final v = data['qtd_produzida'];
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }
  String? get descricao => data['descricao'] as String?;
  String? get cargoFuncao => data['cargo_funcao']?.toString();
  String? get obraItemUuid =>
      data['obra_item_uuid'] as String? ?? data['obra_itemUuid'] as String?;
  String? get uuid => data['uuid'] as String?;

  /// Quantidade prevista / saldo do insumo na obra (`obra_itens.qtd`).
  int? get obraItemQtd {
    final v = data['obra_item_qtd'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get obraItemUnidade => data['obra_item_unidade'] as String?;
}

/// END GETITENSATIVIDADE

/// BEGIN CARREGAFOTOSATIVIDADE
Future<List<CarregaFotosAtividadeRow>> performCarregaFotosAtividade(
  Database database, {
  int? atividadeId,
}) {
  final query = '''
SELECT * FROM relatorio_atividade_fotos WHERE relatorio_atividade_id = ${atividadeId}
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
''';
  return _readQuery(database, query, (d) => CarregaFotosAtividadeRow(d));
}

class CarregaFotosAtividadeRow extends SqliteRow {
  CarregaFotosAtividadeRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
  String? get arquivo => data['arquivo'] as String?;
  int? get relatorioAtividadeId => data['relatorio_atividade_id'] as int?;
}

/// END CARREGAFOTOSATIVIDADE

/// BEGIN GETFOTOSATIVIDADE
Future<List<GetFotosAtividadeRow>> performGetFotosAtividade(
  Database database,
) {
  // Query genérica sem filtro de atividade (placeholder FlutterFlow): não liste fotos excluídas.
  final query = '''
SELECT arquivo
FROM relatorio_atividade_fotos
WHERE (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
ORDER BY id DESC
''';
  return _readQuery(database, query, (d) => GetFotosAtividadeRow(d));
}

class GetFotosAtividadeRow extends SqliteRow {
  GetFotosAtividadeRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
  String? get arquivo => data['arquivo'] as String?;
}

/// END GETFOTOSATIVIDADE

/// BEGIN GETDADOSATIVIDADE
Future<List<GetDadosAtividadeRow>> performGetDadosAtividade(
  Database database, {
  String? uuid,
}) {
  final query = '''
SELECT * FROM relatorio_atividades WHERE uuid = '${uuid}'
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico});
''';
  return _readQuery(database, query, (d) => GetDadosAtividadeRow(d));
}

class GetDadosAtividadeRow extends SqliteRow {
  GetDadosAtividadeRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  int? get ordemId {
    final v = data['ordem_id'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get ordemUuid {
    final v = data['ordem_uuid'];
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }
  String? get item => data['item'] as String?;
  String? get local => data['local'] as String?;
  String? get descricao => data['descricao'] as String?;
  int? get quantidade => data['quantidade'] as int?;
  String? get unidade => data['unidade'] as String?;
  int? get qtdRealizada => data['qtd_realizada'] as int?;
  int? get situacao => data['situacao'] as int?;
  String get uuid => data['uuid'] as String;

  int? get tarefaId {
    final v = data['tarefa_id'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get tarefaUuid {
    final v = data['tarefa_uuid'];
    if (v == null) return null;
    final t = v.toString().trim();
    return t.isEmpty ? null : t;
  }

  /// Sem [obra_etapa_tarefa] vinculada — só nesse caso a UI de “vincular só ordem” (avulsa) faz sentido.
  bool get isAtividadeAvulsa {
    final id = tarefaId;
    if (id != null && id > 0) return false;
    final u = tarefaUuid;
    if (u != null && u.isNotEmpty) return false;
    return true;
  }
}

/// END GETDADOSATIVIDADE

/// BEGIN GETATIVIDADESRELATORIO
Future<List<GetAtividadesRelatorioRow>> performGetAtividadesRelatorio(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT * FROM relatorio_atividades
WHERE relatorio_uuid = '${relatorioUuid}'
  AND (situacao IS NULL OR (CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico} AND CAST(situacao AS INTEGER) != -1))
ORDER BY id DESC
''';
  return _readQuery(database, query, (d) => GetAtividadesRelatorioRow(d));
}

class GetAtividadesRelatorioRow extends SqliteRow {
  GetAtividadesRelatorioRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  int? get ordemId => data['ordem_id'] as int?;
  String? get ordemUuid => data['ordem_uuid'] as String?;
  String? get item => data['item'] as String?;
  String? get local => data['local'] as String?;
  String? get descricao => data['descricao'] as String?;
  String? get unidade => data['unidade'] as String?;
  int? get qtdRealizada => data['qtd_realizada'] as int?;
  int get situacao => data['situacao'] as int;
  String? get uuid => data['uuid'] as String?;
}

/// END GETATIVIDADESRELATORIO

/// BEGIN GETORDENSSERVICO
Future<List<GetOrdensServicoRow>> performGetOrdensServico(
  Database database, {
  String? obraUuid,
  int? userId,
}) {
  final query = '''
SELECT * FROM ordens_servico
WHERE obra_uuid = '${obraUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
ORDER BY id DESC;
''';
  return _readQuery(database, query, (d) => GetOrdensServicoRow(d));
}

class GetOrdensServicoRow extends SqliteRow {
  GetOrdensServicoRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get codigo => data['codigo'] as String;
  String? get nome => data['nome'] as String?;
  String get dataEmissao => data['data_emissao'] as String;
  String get dataInicio => data['data_inicio'] as String;
  String get dataFim => data['data_fim'] as String;
  int get situacao => data['situacao'] as int;

  /// Fluxo igual ao endpoint `/show` (`status_id`). Não confundir com [situacao] (legado).
  int get statusId {
    final v = data['status_id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return 1;
  }

  String? get observacoes => data['observacoes'] as String?;
  String get uuid => data['uuid'] as String;
}

/// END GETORDENSSERVICO

/// BEGIN GETTAREFASORDEM
Future<List<GetTarefasOrdemRow>> performGetTarefasOrdem(
  Database database, {
  String? ordemUuid,
}) {
  final query = '''
SELECT 
  ost.obra_etapa_tarefa_uuid AS uuid,
  ost.qtd_programada,
  ost.qtd_realizada,
  ost.unidade,
  o.descricao AS nome
FROM ordem_servico_tarefas AS ost
JOIN obra_etapa_tarefas AS o  ON o.uuid = ost.obra_etapa_tarefa_uuid
WHERE ost.ordem_servico_uuid = '${ordemUuid}'
  AND ${sqlNaoExcluidoPorSituacao('ost')}
  AND ${sqlNaoExcluidoPorSituacao('o')}
ORDER BY o.descricao;
''';
  return _readQuery(database, query, (d) => GetTarefasOrdemRow(d));
}

class GetTarefasOrdemRow extends SqliteRow {
  GetTarefasOrdemRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
  String? get uuid => data['uuid'] as String?;
  int? get qtdProgramada => data['qtd_programada'] as int?;
  int? get qtdRealizada => data['qtd_realizada'] as int?;
  String? get unidade => data['unidade'] as String?;
}

/// END GETTAREFASORDEM

/// BEGIN GETDETALHESTAREFA
Future<List<GetDetalhesTarefaRow>> performGetDetalhesTarefa(
  Database database, {
  String? uuid,
}) {
  final query = '''
SELECT * FROM obra_etapa_tarefas
WHERE uuid = '${uuid}'
  AND ${sqlNaoExcluidoPorSituacao()};
''';
  return _readQuery(database, query, (d) => GetDetalhesTarefaRow(d));
}

class GetDetalhesTarefaRow extends SqliteRow {
  GetDetalhesTarefaRow(Map<String, dynamic> data) : super(data);

  int get id {
    final v = data['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  /// SQLite pode devolver [int], [double] ou [String] conforme o tipo da coluna.
  String? get item => data['item']?.toString();
  String? get tipo => data['tipo']?.toString();
  String? get local => data['local']?.toString();
  String? get descricao => data['descricao']?.toString();
  String? get qtd => data['qtd']?.toString();
  String? get unidade => data['unidade']?.toString();
  String? get valorUnitario => data['valor_unitario']?.toString();

  int? get qtdRealizada {
    final v = data['qtd_realizada'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  double? get porcentagem {
    final v = data['porcentagem'];
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  int? get status {
    final v = data['status'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  int? get situacao {
    final v = data['situacao'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get uuid => data['uuid']?.toString();
}

/// END GETDETALHESTAREFA

/// BEGIN GETTAREFASORDEMDETALHES
///
/// Localiza a linha OS×tarefa. Aceita IDs e/ou UUIDs — no SQLite costuma existir
/// só [ordemServicoUuid] sem [ordemId], ou só UUIDs da etapa tarefa.
Future<List<GetTarefasOrdemDetalhesRow>> performGetTarefasOrdemDetalhes(
  Database database, {
  int? tarefaId,
  int? ordemId,
  String? obraEtapaTarefaUuid,
  String? ordemServicoUuid,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");

  final tid = tarefaId;
  final oid = ordemId;
  final tu = obraEtapaTarefaUuid?.trim();
  final ou = ordemServicoUuid?.trim();

  final parts = <String>[];

  if (tid != null && tid > 0 && oid != null && oid > 0) {
    parts.add(
      '(obra_etapa_tarefa_id = $tid AND ordem_servico_id = $oid)',
    );
  }
  if (tu != null && tu.isNotEmpty && ou != null && ou.isNotEmpty) {
    parts.add(
      "(obra_etapa_tarefa_uuid = '${esc(tu)}' AND ordem_servico_uuid = '${esc(ou)}')",
    );
  }
  if (tid != null && tid > 0 && ou != null && ou.isNotEmpty) {
    parts.add(
      "(obra_etapa_tarefa_id = $tid AND ordem_servico_uuid = '${esc(ou)}')",
    );
  }
  if (tu != null && tu.isNotEmpty && oid != null && oid > 0) {
    parts.add(
      "(obra_etapa_tarefa_uuid = '${esc(tu)}' AND ordem_servico_id = $oid)",
    );
  }

  if (parts.isEmpty) {
    return Future.value([]);
  }

  final query = '''
SELECT * FROM ordem_servico_tarefas 
WHERE (${parts.join(' OR ')})
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
LIMIT 1;

''';
  return _readQuery(database, query, (d) => GetTarefasOrdemDetalhesRow(d));
}

class GetTarefasOrdemDetalhesRow extends SqliteRow {
  GetTarefasOrdemDetalhesRow(Map<String, dynamic> data) : super(data);

  int get id {
    final v = data['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  int? get qtdProgramada {
    final v = data['qtd_programada'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  int? get qtdRealizada {
    final v = data['qtd_realizada'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  String? get unidade => data['unidade']?.toString();
  String? get dataExecucaoInicio =>
      data['data_execucao_inicio']?.toString();
  String? get dataExecucaoFim => data['data_execucao_fim']?.toString();
  String? get status => data['status']?.toString();
}

/// END GETTAREFASORDEMDETALHES

/// BEGIN GETGRUPOSOBRAS
Future<List<GetGruposObrasRow>> performGetGruposObras(
  Database database, {
  String? userUuid,
}) {
  final query = '''
SELECT * FROM grupo_obra
WHERE user_uuid = '${userUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
ORDER BY nome DESC;
''';
  return _readQuery(database, query, (d) => GetGruposObrasRow(d));
}

class GetGruposObrasRow extends SqliteRow {
  GetGruposObrasRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get nome => data['nome'] as String;
  String? get uuid => data['uuid'] as String?;
}

/// END GETGRUPOSOBRAS

/// BEGIN GETCLIENTES
Future<List<GetClientesRow>> performGetClientes(
  Database database, {
  String? userUuid,
}) {
  final query = '''
SELECT * FROM clientes
WHERE user_uuid = '${userUuid}'
  AND (situacao IS NULL OR situacao <> ${kSituacaoExcluidoLogico})
ORDER BY nome desc;
''';
  return _readQuery(database, query, (d) => GetClientesRow(d));
}

class GetClientesRow extends SqliteRow {
  GetClientesRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get nome => data['nome'] as String;
  String? get uuid => data['uuid'] as String?;
  String? get email => data['email'] as String?;
  String? get telefone => data['telefone'] as String?;
}

/// END GETCLIENTES

/// BEGIN GETMODELOSCHECKLIST
Future<List<GetModelosChecklistRow>> performGetModelosChecklist(
  Database database, {
  int? obraId,
}) {
  final query = '''
SELECT 
    ct.id,
    ct.uuid,
    ct.nome,
    ct.descricao,
    ct.json_config,
    ct.versao,
    ct.status,
    cto.obra_id
FROM checklists_templates ct
INNER JOIN checklists_template_obras cto ON ct.id = cto.checklist_template_id
''';
  return _readQuery(database, query, (d) => GetModelosChecklistRow(d));
}

class GetModelosChecklistRow extends SqliteRow {
  GetModelosChecklistRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String get uuid => data['uuid'] as String;
  String get nome => data['nome'] as String;
}

/// END GETMODELOSCHECKLIST

/// BEGIN GETMAOOBRARELATORIO
Future<List<GetMaoObraRelatorioRow>> performGetMaoObraRelatorio(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT 
  rmo.id,
  rmo.uuid,
  rmo.obra_item_id,
  rmo.obra_item_uuid,
  rmo.status_presenca,
  rmo.hora_entrada,
  rmo.hora_saida,
  rmo.intervalo_inicio,
  rmo.intervalo_fim,
  rmo.horas_trabalhadas,
  rmo.motivo_ausencia,
  rmo.motivo_saida_cedo,
  rmo.motivo_atraso,
  oi.descricao,
  oi.cargo_funcao
FROM relatorio_mao_obra_presenca AS rmo
JOIN obra_itens AS oi 
  ON oi.uuid = rmo.obra_item_uuid
WHERE rmo.relatorio_uuid = '${relatorioUuid}'
  AND ${sqlNaoExcluidoPorSituacao('rmo')}
  AND ${sqlNaoExcluidoPorSituacao('oi')};
''';
  return _readQuery(database, query, (d) => GetMaoObraRelatorioRow(d));
}

class GetMaoObraRelatorioRow extends SqliteRow {
  GetMaoObraRelatorioRow(Map<String, dynamic> data) : super(data);

  String get statusPresenca => data['status_presenca'] as String;
  String? get horaEntrada => data['hora_entrada'] as String?;
  String? get horaSaida => data['hora_saida'] as String?;
  String? get intervaloInicio => data['intervalo_inicio'] as String?;
  String? get intervaloFim => data['intervalo_fim'] as String?;
  String? get motivoAusencia => data['motivo_ausencia'] as String?;
  String? get motivoSaidaCedo => data['motivo_saida_cedo'] as String?;
  String? get motivoAtraso => data['motivo_atraso'] as String?;
  int get id => data['id'] as int;
  int get obraItemId => data['obra_item_id'] as int;
  String? get descricao => data['descricao'] as String?;
  String? get cargoFuncao => data['cargo_funcao']?.toString();
  String? get obraItemUuid => data['obra_item_uuid'] as String?;
  String? get uuid => data['uuid'] as String?;
}

/// END GETMAOOBRARELATORIO

/// BEGIN GETMAOOBRARELATORIODETALHES
Future<List<GetMaoObraRelatorioDetalhesRow>> performGetMaoObraRelatorioDetalhes(
  Database database, {
  String? uuid,
}) {
  final query = '''
SELECT 
  rmo.id,
  rmo.uuid,
  rmo.obra_item_id,
  rmo.obra_item_uuid,
  rmo.status_presenca,
  rmo.hora_entrada,
  rmo.hora_saida,
  rmo.intervalo_inicio,
  rmo.intervalo_fim,
  rmo.horas_trabalhadas,
  rmo.motivo_ausencia,
  rmo.motivo_saida_cedo,
  rmo.motivo_atraso,
  oi.descricao
FROM relatorio_mao_obra_presenca AS rmo
JOIN obra_itens AS oi 
  ON oi.uuid = rmo.obra_item_uuid
WHERE rmo.uuid = '${uuid}'
  AND ${sqlNaoExcluidoPorSituacao('rmo')}
  AND ${sqlNaoExcluidoPorSituacao('oi')};
''';
  return _readQuery(database, query, (d) => GetMaoObraRelatorioDetalhesRow(d));
}

class GetMaoObraRelatorioDetalhesRow extends SqliteRow {
  GetMaoObraRelatorioDetalhesRow(Map<String, dynamic> data) : super(data);

  String get statusPresenca => data['status_presenca'] as String;
  String? get horaEntrada => data['hora_entrada'] as String?;
  String? get horaSaida => data['hora_saida'] as String?;
  String? get intervaloInicio => data['intervalo_inicio'] as String?;
  String? get intervaloFim => data['intervalo_fim'] as String?;
  String? get horasTrabalhadas => data['horas_trabalhadas'] as String?;
  String? get motivoAusencia => data['motivo_ausencia'] as String?;
  String? get motivoSaidaCedo => data['motivo_saida_cedo'] as String?;
  String? get motivoAtraso => data['motivo_atraso'] as String?;
  int get id => data['id'] as int;
  int get obraItemId => data['obra_item_id'] as int;
  String? get descricao => data['descricao'] as String?;
  String? get uuid => data['uuid'] as String?;
  String? get obraItemUuid => data['obra_item_uuid'] as String?;
}

/// END GETMAOOBRARELATORIODETALHES

/// BEGIN GETORDENSSERVICORELATORIO
Future<List<GetOrdensServicoRelatorioRow>> performGetOrdensServicoRelatorio(
  Database database, {
  String? relatorioUuid,
}) {
  final query = '''
SELECT 
  ros.id,
  ros.uuid,
  ros.ordem_servico_id,
  ros.ordem_servico_uuid,
  os.codigo,
  os.nome,
  os.data_emissao,
  os.data_inicio,
  os.data_fim,
  os.situacao,
  os.observacoes  
FROM relatorio_ordem_servico AS ros
JOIN ordens_servico AS os
  ON os.uuid = ros.ordem_servico_uuid
WHERE ros.relatorio_uuid = '${relatorioUuid}'
  AND ${sqlNaoExcluidoPorSituacao('ros')}
  AND ${sqlNaoExcluidoPorSituacao('os')};
''';
  return _readQuery(database, query, (d) => GetOrdensServicoRelatorioRow(d));
}

class GetOrdensServicoRelatorioRow extends SqliteRow {
  GetOrdensServicoRelatorioRow(Map<String, dynamic> data) : super(data);

  int get ordemServicoId => data['ordem_servico_id'] as int;
  String? get codigo => data['codigo'] as String?;
  String? get nome => data['nome'] as String?;
  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFim => data['data_fim'] as String?;
  int? get situacao => data['situacao'] as int?;
  String? get observacoes => data['observacoes'] as String?;
  int get id => data['id'] as int;
  String? get uuid => data['uuid'] as String?;
  String? get ordemServicoUuid => data['ordem_servico_uuid'] as String?;
}

/// END GETORDENSSERVICORELATORIO

/// BEGIN GETCUSTOSORDENSRELATORIOS
Future<List<GetCustosOrdensRelatoriosRow>> performGetCustosOrdensRelatorios(
  Database database, {
  String? ordemRelatorioUuid,
}) {
  final query = '''
SELECT 
  cosr.id,
  cosr.uuid,
  cosr.ordem_servico_custo_id,
  cosr.ordem_servico_custo_uuid,
  cosr.qtd_realizada,
  cos.descricao,
  cos.unidade,
  cos.qtd_prevista
FROM relatorio_custos AS cosr
JOIN ordem_servico_custos AS cos
  ON cos.uuid = cosr.ordem_servico_custo_uuid
WHERE cosr.relatorio_ordem_servico_uuid = '${ordemRelatorioUuid}'
  AND (cosr.situacao IS NULL OR CAST(cosr.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
  AND (cos.situacao IS NULL OR CAST(cos.situacao AS INTEGER) != ${kSituacaoExcluidoLogico});
''';
  return _readQuery(database, query, (d) => GetCustosOrdensRelatoriosRow(d));
}

class GetCustosOrdensRelatoriosRow extends SqliteRow {
  GetCustosOrdensRelatoriosRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  int? get ordemServicoCustoId => data['ordem_servico_custo_id'] as int?;
  int? get qtdRealizada => data['qtd_realizada'] as int?;
  String? get descricao => data['descricao'] as String?;
  String? get unidade => data['unidade'] as String?;
  double? get qtdPrevista => data['qtd_prevista'] as double?;
  String? get uuid => data['uuid'] as String?;
  String? get ordemServicoCustoUuid =>
      data['ordem_servico_custo_uuid'] as String?;
}

/// END GETCUSTOSORDENSRELATORIOS

/// BEGIN DETALHESCOMENTARIO
Future<List<DetalhesComentarioRow>> performDetalhesComentario(
  Database database, {
  int? id,
}) {
  final query = '''
SELECT * FROM relatorio_comentarios WHERE id = ${id}
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
''';
  return _readQuery(database, query, (d) => DetalhesComentarioRow(d));
}

class DetalhesComentarioRow extends SqliteRow {
  DetalhesComentarioRow(Map<String, dynamic> data) : super(data);

  String? get texto => data['texto'] as String?;
  int? get createdBy => data['created_by'] as int?;
}

/// END DETALHESCOMENTARIO

/// BEGIN DETALHESOCORRENCIA
Future<List<DetalhesOcorrenciaRow>> performDetalhesOcorrencia(
  Database database, {
  String? uuid,
}) {
  final query = '''
SELECT * FROM relatorio_ocorrencias WHERE uuid = '${uuid}'
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
''';
  return _readQuery(database, query, (d) => DetalhesOcorrenciaRow(d));
}

class DetalhesOcorrenciaRow extends SqliteRow {
  DetalhesOcorrenciaRow(Map<String, dynamic> data) : super(data);

  String? get descricao => data['descricao'] as String?;
  int? get createdBy => data['created_by'] as int?;
  String? get horaInicio => data['hora_inicio'] as String?;
  String? get horaSaida => data['hora_saida'] as String?;
  String? get uuid => data['uuid'] as String?;
  int? get situacao => data['situacao'] as int?;
}

/// END DETALHESOCORRENCIA

/// BEGIN GETDETALHESITEMATIVIDADE
Future<List<GetDetalhesItemAtividadeRow>> performGetDetalhesItemAtividade(
  Database database, {
  String? uuid,
}) {
  final query = '''
SELECT * FROM relatorio_atividades_itens WHERE uuid = '${uuid}'
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})

''';
  return _readQuery(database, query, (d) => GetDetalhesItemAtividadeRow(d));
}

class GetDetalhesItemAtividadeRow extends SqliteRow {
  GetDetalhesItemAtividadeRow(Map<String, dynamic> data) : super(data);

  int? get qtdUtilizada => data['qtd_utilizada'] as int?;
  int? get qtdRealizada => data['qtd_realizada'] as int?;
  num? get qtdProduzida {
    final v = data['qtd_produzida'];
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }
  int get id => data['id'] as int;
  String? get uuid => data['uuid'] as String?;
}

/// END GETDETALHESITEMATIVIDADE

/// BEGIN GETTIPOOCORRENCIADETALHES
Future<List<GetTipoOcorrenciaDetalhesRow>> performGetTipoOcorrenciaDetalhes(
  Database database, {
  int? id,
}) {
  final query = '''
SELECT * FROM tipo_ocorrencias
WHERE id = ${id}
  AND ${sqlNaoExcluidoPorSituacao()}

''';
  return _readQuery(database, query, (d) => GetTipoOcorrenciaDetalhesRow(d));
}

class GetTipoOcorrenciaDetalhesRow extends SqliteRow {
  GetTipoOcorrenciaDetalhesRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
}

/// END GETTIPOOCORRENCIADETALHES

/// BEGIN GETTIPOUSERDETALHESCOPY
Future<List<GetTipoUserDetalhesCopyRow>> performGetTipoUserDetalhesCopy(
  Database database, {
  int? idserver,
}) {
  final query = '''
SELECT * FROM users
WHERE id_server = ${idserver}
  AND ${sqlNaoExcluidoPorSituacao()}

''';
  return _readQuery(database, query, (d) => GetTipoUserDetalhesCopyRow(d));
}

class GetTipoUserDetalhesCopyRow extends SqliteRow {
  GetTipoUserDetalhesCopyRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
  String? get sobrenome => data['sobrenome'] as String?;
  String? get cargo => data['cargo'] as String?;
}

/// END GETTIPOUSERDETALHESCOPY

/// BEGIN GETSTATUSRELATORIODETALHES
Future<List<GetStatusRelatorioDetalhesRow>> performGetStatusRelatorioDetalhes(
  Database database, {
  int? id,
}) {
  final query = '''
SELECT * FROM status_relatorios WHERE id = ${id}

''';
  return _readQuery(database, query, (d) => GetStatusRelatorioDetalhesRow(d));
}

class GetStatusRelatorioDetalhesRow extends SqliteRow {
  GetStatusRelatorioDetalhesRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get nome => data['nome'] as String?;
}

/// END GETSTATUSRELATORIODETALHES

/// BEGIN GETIDSERVIDOR
Future<List<GetIdServidorRow>> performGetIdServidor(
  Database database, {
  String? tabela,
  String? uuid,
}) {
  final query = '''
SELECT * FROM sync_id_mapping WHERE tabela = '${tabela}' and uuid = '${uuid}' 
''';
  return _readQuery(database, query, (d) => GetIdServidorRow(d));
}

class GetIdServidorRow extends SqliteRow {
  GetIdServidorRow(Map<String, dynamic> data) : super(data);

  int? get idServidor => data['id_servidor'] as int?;
}

/// END GETIDSERVIDOR

/// BEGIN GETEQUIPAMENTOS
Future<List<GetEquipamentosRow>> performGetEquipamentos(
  Database database, {
  String? userUuid,
}) {
  final query = '''
SELECT * FROM equipamentos
WHERE created_by = '${userUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
ORDER BY nome desc;
''';
  return _readQuery(database, query, (d) => GetEquipamentosRow(d));
}

class GetEquipamentosRow extends SqliteRow {
  GetEquipamentosRow(Map<String, dynamic> data) : super(data);

  int? get id => data['id'] as int?;
  String? get uuid => data['uuid'] as String?;
  String? get nome => data['nome'] as String?;
  String? get unidadeMedida => data['unidade_medida'] as String?;
}

/// END GETEQUIPAMENTOS

/// BEGIN GETINSUMOS
Future<List<GetInsumosRow>> performGetInsumos(
  Database database, {
  String? userUuid,
}) {
  final query = '''
SELECT * FROM insumos
WHERE created_by = '${userUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
ORDER BY nome desc;
''';
  return _readQuery(database, query, (d) => GetInsumosRow(d));
}

class GetInsumosRow extends SqliteRow {
  GetInsumosRow(Map<String, dynamic> data) : super(data);

  int? get id => data['id'] as int?;
  String? get uuid => data['uuid'] as String?;
  String? get nome => data['nome'] as String?;
  String? get unidadeMedica => data['unidade_medica'] as String?;
  int? get estoqueAtual => data['estoque_atual'] as int?;
}

/// END GETINSUMOS

/// BEGIN GETLOCAIS
Future<List<GetLocaisRow>> performGetLocais(
  Database database, {
  String? userUuid,
}) {
  final query = '''
SELECT * FROM locais
WHERE created_by = '${userUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
ORDER BY nome desc;
''';
  return _readQuery(database, query, (d) => GetLocaisRow(d));
}

class GetLocaisRow extends SqliteRow {
  GetLocaisRow(Map<String, dynamic> data) : super(data);

  int? get id => data['id'] as int?;
  String? get uuid => data['uuid'] as String?;
  String? get nome => data['nome'] as String?;
}

/// END GETLOCAIS

/// BEGIN GETFUNCOESMAOOBRA
Future<List<GetFuncoesMaoObraRow>> performGetFuncoesMaoObra(
  Database database, {
  String? userUuid,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final query = '''
SELECT *
FROM funcoes_mao_obra
WHERE (created_by = '${esc(userUuid)}' OR created_by IS NULL OR TRIM(created_by) = '')
  AND (situacao IS NULL OR CAST(situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
ORDER BY nome COLLATE NOCASE ASC;
''';
  return _readQuery(database, query, (d) => GetFuncoesMaoObraRow(d));
}

class GetFuncoesMaoObraRow extends SqliteRow {
  GetFuncoesMaoObraRow(Map<String, dynamic> data) : super(data);

  int? get id => data['id'] as int?;
  String? get nome => data['nome']?.toString();
  String? get createdBy => data['created_by']?.toString();
  int? get situacao {
    final v = data['situacao'];
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}

/// END GETFUNCOESMAOOBRA

/// BEGIN GETMAOOBRA
Future<List<GetMaoObraRow>> performGetMaoObra(
  Database database, {
  String? userUuid,
}) {
  final query = '''
SELECT * FROM mao_obra_profissionais
WHERE created_by = '${userUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
ORDER BY nome_completo asc;
''';
  return _readQuery(database, query, (d) => GetMaoObraRow(d));
}

class GetMaoObraRow extends SqliteRow {
  GetMaoObraRow(Map<String, dynamic> data) : super(data);

  int? get id => data['id'] as int?;
  String? get uuid => data['uuid'] as String?;
  String? get nome => data['nome'] as String?;
  String? get cargoFuncao => data['cargo_funcao'] as String?;
}

/// END GETMAOOBRA

/// BEGIN GETUSUARIOS
Future<List<GetUsuariosRow>> performGetUsuarios(
  Database database, {
  String? userUuid,
  int? tenantUserId,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final tenantId = tenantUserId ?? 0;
  final query = tenantId > 0
      ? '''
SELECT
  u.id,
  u.uuid,
  u.nome,
  u.sobrenome,
  u.email,
  eu.type AS type,
  u.cargo,
  u.registro_profissional,
  eu.situacao AS situacao,
  eu.obra_travada AS obra_travada
FROM empresa_users AS eu
INNER JOIN users AS u
  ON (eu.user_id IS NOT NULL AND u.id = eu.user_id)
  OR (eu.user_uuid IS NOT NULL AND TRIM(eu.user_uuid) != '' AND u.uuid = eu.user_uuid)
WHERE eu.tenant_user_id = $tenantId
  AND (eu.situacao IS NULL OR CAST(eu.situacao AS INTEGER) <> ${kSituacaoExcluidoLogico})
ORDER BY u.nome ASC
'''
      : '''
SELECT * FROM users
WHERE created_by = '${esc(userUuid)}'
  AND (situacao IS NULL OR situacao <> ${kSituacaoExcluidoLogico})
ORDER BY nome asc;
''';
  return _readQuery(database, query, (d) => GetUsuariosRow(d));
}

class GetUsuariosRow extends SqliteRow {
  GetUsuariosRow(Map<String, dynamic> data) : super(data);

  int? get id => data['id'] as int?;
  String? get uuid => data['uuid'] as String?;
  String? get nome => data['nome'] as String?;
  String? get email => data['email'] as String?;
  String? get type => data['type'] as String?;
  String? get cargo => data['cargo'] as String?;
  String? get registroProfissional => data['registro_profissional'] as String?;
  int? get situacao => data['situacao'] as int?;
}

/// END GETUSUARIOS

/// BEGIN SITUACAOOBRA
Future<List<SituacaoObraRow>> performSituacaoObra(
  Database database, {
  int? id,
}) {
  final query = '''
SELECT * FROM situacao_obras WHERE id = ${id}

''';
  return _readQuery(database, query, (d) => SituacaoObraRow(d));
}

Future<List<SituacaoObraRow>> performListaSituacaoObras(Database database) {
  const query = '''
SELECT * FROM situacao_obras ORDER BY COALESCE(nome, '') ASC, id ASC
''';
  return _readQuery(database, query, (d) => SituacaoObraRow(d));
}

class SituacaoObraRow extends SqliteRow {
  SituacaoObraRow(Map<String, dynamic> data) : super(data);

  int? get id => data['id'] as int?;
  String? get nome => data['nome'] as String?;
}

/// END SITUACAOOBRA

/// BEGIN GETTIPOOCORRENCIAS
Future<List<GetTipoOcorrenciasRow>> performGetTipoOcorrencias(
  Database database, {
  String? userUuid,
}) {
  final query = '''
SELECT * FROM tipo_ocorrencias
WHERE user_uuid = '${userUuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
ORDER BY nome ASC;
''';
  return _readQuery(database, query, (d) => GetTipoOcorrenciasRow(d));
}

class GetTipoOcorrenciasRow extends SqliteRow {
  GetTipoOcorrenciasRow(Map<String, dynamic> data) : super(data);

  String? get uuid => data['uuid'] as String?;
  String? get id => data['id'] as String?;
  String? get nome => data['nome'] as String?;
}

/// END GETTIPOOCORRENCIAS

/// BEGIN RELATORIODETALHESCOPY
Future<List<RelatorioDetalhesCopyRow>> performRelatorioDetalhesCopy(
  Database database, {
  String? uuid,
  String? userUuid,
}) {
  final query = '''
SELECT *
FROM relatorios
WHERE uuid = '${uuid}'
  AND ${sqlNaoExcluidoPorSituacao()}
LIMIT 1;

''';
  return _readQuery(database, query, (d) => RelatorioDetalhesCopyRow(d));
}

class RelatorioDetalhesCopyRow extends SqliteRow {
  RelatorioDetalhesCopyRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  String? get dataExecutado => data['data_executado'] as String?;
  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;
  int get obraId => data['obra_id'] as int;
  int? get numero => data['numero'] as int?;
  String? get entradaManha => data['entrada_manha'] as String?;
  String? get inicioIntervalo => data['inicio_intervalo'] as String?;
  String? get fimIntervalo => data['fim_intervalo'] as String?;
  String? get saidaTarde => data['saida_tarde'] as String?;
  int get statusId => data['status_id'] as int;
  String? get uuid => data['uuid'] as String?;
  String get obraUuid => data['obra_uuid'] as String;
}

/// END RELATORIODETALHESCOPY

/// BEGIN RELATORIOSOBRAULTIMOS
Future<List<RelatoriosObraUltimosRow>> performRelatoriosObraUltimos(
  Database database, {
  String? obraUuid,
  String? accountOwnerUuid,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final owner = (accountOwnerUuid ?? '').trim();
  if (owner.isEmpty) {
    return Future.value(<RelatoriosObraUltimosRow>[]);
  }
  final query = '''
SELECT
  r.*,
  sr.nome AS status_nome,
  COALESCE(
    u_criador_uuid.nome,
    u_criador_id.nome,
    u_created_by_uuid.nome,
    u_created_by_id.nome
  ) AS criador_nome
FROM relatorios AS r
INNER JOIN obras AS ob ON ob.uuid = r.obra_uuid AND ob.user_uuid = '${esc(owner)}'
  AND (ob.situacao IS NULL OR CAST(ob.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
LEFT JOIN status_relatorios AS sr
  ON sr.id = r.status_id
LEFT JOIN users AS u_criador_uuid
  ON u_criador_uuid.uuid = r.criador
LEFT JOIN users AS u_criador_id
  ON CAST(u_criador_id.id AS TEXT) = CAST(r.criador AS TEXT)
LEFT JOIN users AS u_created_by_uuid
  ON u_created_by_uuid.uuid = r.created_by
LEFT JOIN users AS u_created_by_id
  ON CAST(u_created_by_id.id AS TEXT) = CAST(r.created_by AS TEXT)
WHERE r.obra_uuid = '${esc(obraUuid)}'
  AND (r.situacao IS NULL OR CAST(r.situacao AS INTEGER) != ${kSituacaoExcluidoLogico})
ORDER BY COALESCE(NULLIF(trim(r.updated_at), ''), r.created_at) DESC, r.numero DESC, r.id DESC
LIMIT 10;
''';
  return _readQuery(database, query, (d) => RelatoriosObraUltimosRow(d));
}

class RelatoriosObraUltimosRow extends SqliteRow {
  RelatoriosObraUltimosRow(Map<String, dynamic> data) : super(data);

  String? get dataInicio => data['data_inicio'] as String?;
  String? get dataFinal => data['data_final'] as String?;
  int get id => data['id'] as int;
  String get dataExecutado => data['data_executado'] as String;
  int? get numero => data['numero'] as int?;
  String get uuid => data['uuid'] as String;
  String get obraUuid => data['obra_uuid'] as String;
  int get statusId => data['status_id'] as int;
  String? get statusNome => data['status_nome'] as String?;
  String? get criador => data['criador'] as String?;
  String? get criadorNome => data['criador_nome'] as String?;
}

/// END RELATORIOSOBRAULTIMOS

/// BEGIN OBRALOCAIS
Future<List<ObraLocaisRow>> performObraLocais(
  Database database, {
  String? obraUuid,
}) {
  final query = '''
SELECT 
  ol.id,
  ol.uuid,
  ol.local_uuid,
  l.nome,
  m.id_servidor AS local_id_servidor
FROM obra_locais AS ol
JOIN locais AS l
  ON l.uuid = ol.local_uuid
LEFT JOIN sync_id_mapping AS m
  ON m.tabela = 'locais' AND m.uuid = l.uuid
WHERE ol.obra_uuid = '${obraUuid}'
  AND (ol.situacao IS NULL OR CAST(ol.situacao AS INTEGER) != ${kSituacaoExcluidoLogico});
''';
  return _readQuery(database, query, (d) => ObraLocaisRow(d));
}

class ObraLocaisRow extends SqliteRow {
  ObraLocaisRow(Map<String, dynamic> data) : super(data);

  String? get uuid => data['uuid'] as String?;
  String? get nome => data['nome'] as String?;
  String? get localUuid => data['local_uuid'] as String?;

  /// ID do local no servidor (FK em `relatorio_atividades.local` após sync).
  int? get localIdServidor => data['local_id_servidor'] as int?;
}

/// END OBRALOCAIS

/// BEGIN SYNCHISTORYRECENT
Future<List<SyncHistoryRecentRow>> performSyncHistoryRecent(
  Database database, {
  String? userUuid,
  int? userId,
  int limit = 10,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final safeLimit = limit <= 0 ? 10 : limit;
  final uid = userId ?? 0;
  final uUuid = (userUuid ?? '').trim();
  final where = uUuid.isNotEmpty
      ? "WHERE (user_uuid = '${esc(uUuid)}' OR user_id = $uid)"
      : (uid > 0 ? "WHERE user_id = $uid" : '');

  final query = '''
SELECT
  id,
  user_id,
  user_uuid,
  started_at,
  completed_at,
  status,
  created_at
FROM sync_history
$where
ORDER BY COALESCE(completed_at, started_at, created_at) DESC, id DESC
LIMIT $safeLimit;
''';
  return _readQuery(database, query, (d) => SyncHistoryRecentRow(d));
}

class SyncHistoryRecentRow extends SqliteRow {
  SyncHistoryRecentRow(Map<String, dynamic> data) : super(data);

  int get id => data['id'] as int;
  int? get userId => data['user_id'] as int?;
  String? get userUuid => data['user_uuid'] as String?;
  String? get startedAt => data['started_at'] as String?;
  String? get completedAt => data['completed_at'] as String?;
  String? get status => data['status'] as String?;
  String? get createdAt => data['created_at'] as String?;
}

/// END SYNCHISTORYRECENT

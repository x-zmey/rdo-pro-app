import 'package:sqflite/sqflite.dart';

import '/backend/sqlite/situacao_soft_delete.dart';

/// Atualiza `updated_at` e `synced = 0` no relatório pai (edição local / LWW).
Future<void> _touchRelatorioModificadoLocal(
  Database database,
  int? relatorioId,
) async {
  if (relatorioId == null || relatorioId < 1) return;
  final ts = DateTime.now().toUtc().toIso8601String();
  await database.rawUpdate(
    'UPDATE relatorios SET updated_at = ?, synced = ? WHERE id = ?',
    [ts, 0, relatorioId],
  );
}

String _sqlNowUtcEscaped() =>
    DateTime.now().toUtc().toIso8601String().replaceAll("'", "''");

/// Evita `'${null}'` em SQL (vira o texto `null`). Retorna `NULL` ou string quoted.
String _sqlNullableText(String? v) {
  if (v == null) return 'NULL';
  final t = v.trim();
  if (t.isEmpty || t.toLowerCase() == 'null') return 'NULL';
  return "'${t.replaceAll("'", "''")}'";
}

/// Horas como REAL sem aspas; [null] ou vazio → SQL NULL (não string `"null"`).
String _sqlNullableHoras(String? v) {
  if (v == null) return 'NULL';
  final t = v.trim();
  if (t.isEmpty || t.toLowerCase() == 'null') return 'NULL';
  final n = double.tryParse(t.replaceAll(',', '.'));
  if (n == null) return 'NULL';
  return n.toStringAsFixed(2);
}

/// Público para custom actions que alteram filhos do relatório fora deste arquivo.
Future<void> performTouchRelatorioModificadoLocal(
  Database database, {
  int? relatorioId,
}) =>
    _touchRelatorioModificadoLocal(database, relatorioId);

/// BEGIN CADASTRAROBRA
Future performCadastrarObra(
  Database database, {
  int? userId,
  String? nome,
}) {
  final query = '''
INSERT INTO obras (
  user_id,
  nome
) VALUES (
${userId},
'${nome}'
);
''';
  return database.rawQuery(query);
}

/// END CADASTRAROBRA

/// BEGIN CADASTRARRELATORIO
Future performCadastrarRelatorio(
  Database database, {
  int? userId,
  int? obraId,
  int? modeloId,
  String? dataexecutado,
  String? criador,
  int? numero,
  String? uuid,
  String? creatorUuid,
  String? userUuid,
  String? obraUuid,
  String? modeloUuid,
}) {
  String esc(String? s) => (s ?? '').replaceAll("'", "''");
  final now = esc(DateTime.now().toUtc().toIso8601String());
  final query = '''
INSERT INTO relatorios (
uuid,
user_id, 
user_uuid,
obra_id, 
obra_uuid,
modelo_id,
modelo_uuid,
numero, 
data_executado, 
horas_trabalhadas, 
entrada_manha,
saida_manha,
inicio_intervalo,
fim_intervalo,
entrada_tarde,
saida_tarde,
criador,
status_id, 
created_by, 
situacao,
updated_at,
synced) VALUES 
('${esc(uuid)}', ${userId}, '${esc(userUuid)}',  ${obraId}, '${esc(obraUuid)}', ${modeloId}, '${esc(modeloUuid)}',${numero}, '${esc(dataexecutado)}',  0, '08:00',  '11:00', '11:00', '13:00', '13:00',  '17:00', '${esc(criador)}', 1, '${esc(creatorUuid)}', 0, '$now', 0)

''';
  return database.rawQuery(query);
}

/// END CADASTRARRELATORIO

/// BEGIN UPDATEOBRA
Future performUpdateObra(
  Database database, {
  String? uuid,
  int? grupoId,
  String? grupoUuid,
  int? clienteId,
  String? clienteUuid,
  String? nome,
  String? rua,
  String? numero,
  String? complemento,
  String? bairro,
  String? cidade,
  String? estado,
  String? engenheiro,
  String? dataInicio,
  String? dataFinal,
  String? contrato,
}) {
  String esc(String? v) => (v ?? '').replaceAll("'", "''");
  final gid = grupoId ?? 0;
  final cid = clienteId ?? 0;
  final gu = esc(grupoUuid);
  final cu = esc(clienteUuid);
  final now = esc(DateTime.now().toIso8601String());
  final query = '''
UPDATE obras SET
  grupo_id = $gid,
  grupo_uuid = '$gu',
  cliente_id = $cid,
  cliente_uuid = '$cu',
  nome = '${esc(nome)}',
  rua = '${esc(rua)}',
  numero = '${esc(numero)}',
  complemento = '${esc(complemento)}',
  bairro = '${esc(bairro)}',
  cidade = '${esc(cidade)}',
  estado = '${esc(estado)}',
  engenheiro = '${esc(engenheiro)}',
  data_inicio = '${esc(dataInicio)}',
  data_final = '${esc(dataFinal)}',
  contrato = '${esc(contrato)}',
  synced = 0,
  updated_at = '$now'
WHERE uuid = '${esc(uuid)}'
''';
  return database.rawQuery(query);
}

/// END UPDATEOBRA

/// BEGIN ADDCOMENTARIORELATORIO
Future performAddComentarioRelatorio(
  Database database, {
  int? relatorioId,
  String? texto,
  String? createdBy,
  String? createdAt,
  String? relatorioUuid,
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final query = '''
INSERT INTO relatorio_comentarios (uuid, relatorio_id, relatorio_uuid, texto, created_by, situacao, created_at, updated_at, synced) VALUES 
('${uuid}',${relatorioId},  '${relatorioUuid}',  '${texto}', '${createdBy}', ${kSituacaoAtivo}, '${createdAt}', '$ts', 0)
''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END ADDCOMENTARIORELATORIO

/// BEGIN ADDOCORRENCIARELATORIO
Future performAddOcorrenciaRelatorio(
  Database database, {
  int? userId,
  int? relatorioId,
  String? descricao,
  String? horaInicio,
  String? horaFim,
  String? relatorioUuid,
  String? uuid,
  String? creatorUuid,
  String? userUuid,
  String? tipoUuid,
  int? situacao,
}) async {
  final sit = situacao ?? kSituacaoAtivo;
  final ts = _sqlNowUtcEscaped();
  final query = '''
INSERT INTO relatorio_ocorrencias (uuid, user_id, user_uuid, relatorio_id, relatorio_uuid, descricao, tipo_uuid, hora_inicio, hora_saida, created_by, situacao, updated_at, synced) VALUES
('${uuid}', ${userId}, '${creatorUuid}', ${relatorioId}, '${relatorioUuid}',  '${descricao}', '${tipoUuid}',  '${horaInicio}', '${horaFim}',  '${userUuid}', ${sit}, '$ts', 0)
''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END ADDOCORRENCIARELATORIO

/// BEGIN ADDANEXORELATORIO
Future performAddAnexoRelatorio(
  Database database, {
  int? relatorioId,
  String? nome,
  String? createdBy,
  String? createdAt,
  String? arquivo,
  String? relatorioUuid,
  String? uuid,
}) async {
  final now = DateTime.now().toUtc().toIso8601String();
  final rid = relatorioId ?? 0;
  await database.insert(
    'relatorio_anexos',
    {
      'uuid': uuid ?? '',
      'relatorio_id': rid,
      'relatorio_uuid': relatorioUuid ?? '',
      'nome': nome ?? '',
      'arquivo': arquivo ?? '',
      'created_by': createdBy ?? '',
      'created_at': (createdAt != null && createdAt.isNotEmpty) ? createdAt : now,
      'situacao': kSituacaoAtivo,
      'updated_at': now,
      'synced': 0,
    },
    conflictAlgorithm: ConflictAlgorithm.abort,
  );
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END ADDANEXORELATORIO

/// BEGIN UPDATENOMEANEXORELATORIO
Future performUpdateAnexoRelatorioNome(
  Database database, {
  required String uuid,
  required String nome,
}) async {
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_anexos WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  final now = DateTime.now().toUtc().toIso8601String();
  await database.rawUpdate(
    'UPDATE relatorio_anexos SET nome = ?, updated_at = ?, synced = 0 WHERE uuid = ?',
    [nome, now, uuid],
  );
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END UPDATENOMEANEXORELATORIO

/// BEGIN CADASTRAEQUIPAMENTORECEBIDORELATORIO
/// [createdBy]: UUID TEXT do **tenant** (conta) no SQLite, não do user logado (não id numérico).
Future performCadastraEquipamentoRecebidoRelatorio(
  Database database, {
  int? relatorioId,
  int? equipamentoId,
  num? quantidade,
  String? createdBy,
  String? relatorioUuid,
  String? equipamentoUuid,
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final q = quantidade ?? 0;
  final query = '''
INSERT INTO relatorio_equipamento_recebido (uuid, relatorio_id, relatorio_uuid, equipamento_id, equipamento_uuid,  quantidade, created_by, situacao, updated_at, synced) VALUES (
'${uuid}', ${relatorioId}, '${relatorioUuid}',  ${equipamentoId}, '${equipamentoUuid}', $q, '${createdBy}', ${kSituacaoAtivo}, '$ts', 0);
''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END CADASTRAEQUIPAMENTORECEBIDORELATORIO

Future<String?> _uuidPorId(Database database, String sql, List<Object?> args) async {
  final rows = await database.rawQuery(sql, args);
  if (rows.isEmpty) return null;
  final u = rows.first['uuid']?.toString().trim();
  if (u == null || u.isEmpty || u.toLowerCase() == 'null') return null;
  return u;
}

/// BEGIN INSERTATIVIDADERELATORIO
Future performInsertAtividadeRelatorio(
  Database database, {
  int? userId,
  int? relatorioId,
  String? createdBy,
  String? local,
  String? descricao,
  int? quantidade,
  int? qtdRealizada,
  String? unidade,
  String? item,
  int? tarefaId,
  int? ordemId,
  String? ordemUuid,
  String? relatorioUuid,
  String? uuid,
  String? userUuid,
  String? tarefaUuid,
}) async {
  String esc(String? s) => (s ?? '').replaceAll("'", "''");
  final loc = esc(local);
  final desc = esc(descricao);
  final uni = esc(unidade);
  final it = esc(item);
  final qtd = quantidade ?? 0;
  final qtdReal = qtdRealizada ?? 0;
  final ts = _sqlNowUtcEscaped();

  var relatorioUuidEff = (relatorioUuid ?? '').trim();
  if (relatorioUuidEff.isEmpty && relatorioId != null) {
    relatorioUuidEff = (await _uuidPorId(
          database,
          'SELECT uuid FROM relatorios WHERE id = ? LIMIT 1',
          [relatorioId],
        )) ??
        '';
  }

  var userUuidEff = (userUuid ?? '').trim();
  if (userUuidEff.isEmpty && userId != null) {
    userUuidEff = (await _uuidPorId(
          database,
          'SELECT uuid FROM users WHERE id = ? LIMIT 1',
          [userId],
        )) ??
        '';
  }

  var tarefaUuidEff = (tarefaUuid ?? '').trim();
  if (tarefaUuidEff.isEmpty && tarefaId != null) {
    tarefaUuidEff = (await _uuidPorId(
          database,
          'SELECT uuid FROM obra_etapa_tarefas WHERE id = ? LIMIT 1',
          [tarefaId],
        )) ??
        '';
  }

  var ordemUuidEff = (ordemUuid ?? '').trim();
  if (ordemUuidEff.isEmpty && ordemId != null) {
    ordemUuidEff = (await _uuidPorId(
          database,
          'SELECT uuid FROM ordens_servico WHERE id = ? LIMIT 1',
          [ordemId],
        )) ??
        '';
  }

  final ordemIdSql = ordemId != null ? ordemId.toString() : 'NULL';
  final ordemUuidSql = ordemUuidEff.isNotEmpty ? "'${esc(ordemUuidEff)}'" : 'NULL';
  final query = '''
INSERT INTO relatorio_atividades (uuid,
  user_id, user_uuid, relatorio_id, relatorio_uuid, ordem_id, ordem_uuid, tarefa_id, tarefa_uuid, item, local, descricao, quantidade, unidade, qtd_realizada, created_by, situacao, updated_at, synced
) 
VALUES (
  '${esc(uuid)}', ${userId}, '${esc(userUuidEff)}', ${relatorioId}, '${esc(relatorioUuidEff)}', $ordemIdSql, $ordemUuidSql, ${tarefaId}, '${esc(tarefaUuidEff)}', '$it', '$loc', '$desc', $qtd, '$uni', $qtdReal, '${esc(createdBy)}', ${kSituacaoAtivo}, '$ts', 0
);

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END INSERTATIVIDADERELATORIO

/// BEGIN SETITEMATIVIDADE
Future performSetItemAtividade(
  Database database, {
  int? relatorioAtividadeId,
  String? tipo,
  int? obraItemId,
  String? relatorioAtividadeUuid,
  String? uuid,
  String? obraItemUuid,
  /// UUID do assinante (`FFAppState().creatorUuid`) — alinhado ao MySQL `created_by` (texto).
  String? createdBy,
}) async {
  String esc(String? s) {
    final v = s ?? '';
    return v.replaceAll(r"'", r"''");
  }

  var raUuid = (relatorioAtividadeUuid ?? '').trim();
  if (raUuid.isEmpty && relatorioAtividadeId != null) {
    raUuid = (await _uuidPorId(
          database,
          'SELECT uuid FROM relatorio_atividades WHERE id = ? LIMIT 1',
          [relatorioAtividadeId],
        )) ??
        '';
  }

  var oiUuid = (obraItemUuid ?? '').trim();
  if (oiUuid.isEmpty && obraItemId != null) {
    oiUuid = (await _uuidPorId(
          database,
          'SELECT uuid FROM obra_itens WHERE id = ? LIMIT 1',
          [obraItemId],
        )) ??
        '';
  }

  final ts = _sqlNowUtcEscaped();
  final raIdSql =
      relatorioAtividadeId != null ? relatorioAtividadeId.toString() : 'NULL';
  final oiIdSql = obraItemId != null ? obraItemId.toString() : 'NULL';
  final createdByEff = esc((createdBy ?? '').trim());
  final query = '''
INSERT INTO relatorio_atividades_itens (uuid, relatorio_atividade_id,  relatorio_atividade_uuid, tipo, obra_item_id, obra_item_uuid,  qtd_utilizada, qtd_realizada, qtd_produzida, situacao, created_by, updated_at, synced) VALUES (
'${esc(uuid)}', $raIdSql, '${esc(raUuid)}',  '${esc(tipo)}', $oiIdSql, '${esc(oiUuid)}', 1,1,0,${kSituacaoAtivo}, '$createdByEff', '$ts', 0);

''';
  await database.rawQuery(query);
  if (relatorioAtividadeId != null) {
    final rows = await database.rawQuery(
      'SELECT relatorio_id FROM relatorio_atividades WHERE id = ? LIMIT 1',
      [relatorioAtividadeId],
    );
    final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
    await _touchRelatorioModificadoLocal(database, rid);
  }
}

/// END SETITEMATIVIDADE

/// BEGIN UPDATEITEMATIVIDADE
Future performUpdateItemAtividade(
  Database database, {
  int? qtdRealizada,
  String? uuid,
  int? qtdUtilizada,
  num? qtdProduzida,
}) async {
  if (uuid == null || uuid.trim().isEmpty) return;

  final current = await database.query(
    'relatorio_atividades_itens',
    columns: ['qtd_utilizada', 'qtd_realizada', 'qtd_produzida'],
    where: 'uuid = ?',
    whereArgs: [uuid],
    limit: 1,
  );
  if (current.isEmpty) return;

  final row = current.first;
  final util = qtdUtilizada ?? _asIntQtdItem(row['qtd_utilizada']) ?? 0;
  final real = qtdRealizada ?? _asIntQtdItem(row['qtd_realizada']) ?? 0;
  final prod = qtdProduzida ?? _asNumQtdItem(row['qtd_produzida']) ?? 0;
  final ts = DateTime.now().toUtc().toIso8601String();

  await database.rawUpdate(
    '''
UPDATE relatorio_atividades_itens
SET
  qtd_utilizada = ?,
  qtd_realizada = ?,
  qtd_produzida = ?,
  updated_at = ?,
  synced = 0
WHERE uuid = ?
''',
    [util, real, prod, ts, uuid],
  );

  final rows = await database.rawQuery(
    '''SELECT ra.relatorio_id FROM relatorio_atividades_itens rai
       INNER JOIN relatorio_atividades ra ON ra.id = rai.relatorio_atividade_id
       WHERE rai.uuid = ? LIMIT 1''',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await _touchRelatorioModificadoLocal(database, rid);
}

int? _asIntQtdItem(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString().trim());
}

num? _asNumQtdItem(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString().trim().replaceAll(',', '.'));
}

/// END UPDATEITEMATIVIDADE

/// BEGIN DELETEITEMATIVIDADE
Future performDeleteItemAtividade(
  Database database, {
  int? id,
}) async {
  final rows = await database.rawQuery(
    '''SELECT ra.relatorio_id FROM relatorio_atividades_itens rai
       INNER JOIN relatorio_atividades ra ON ra.id = rai.relatorio_atividade_id
       WHERE rai.id = ? LIMIT 1''',
    [id],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  final ts = _sqlNowUtcEscaped();
  final query = '''
UPDATE relatorio_atividades_itens
SET situacao = ${kSituacaoExcluidoLogico}, updated_at = '$ts', synced = 0
WHERE id = ${id};

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETEITEMATIVIDADE

/// BEGIN UPDATEATIVIDADE
Future performUpdateAtividade(
  Database database, {
  required String uuid,
  String? local,
  String? descricao,
  int? qtdRealizada,
  String? unidade,
  int? situacao,
  int? ordemId,
  String? ordemUuid,
  bool updateOrdemVinculo = false,
}) async {
  final ts = DateTime.now().toUtc().toIso8601String();
  if (updateOrdemVinculo) {
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades SET
  local = ?,
  descricao = ?,
  qtd_realizada = ?,
  unidade = ?,
  situacao = ?,
  ordem_id = ?,
  ordem_uuid = ?,
  updated_at = ?,
  synced = 0
WHERE uuid = ?
''',
      <Object?>[
        local,
        descricao,
        qtdRealizada,
        unidade,
        situacao,
        ordemId,
        ordemUuid,
        ts,
        uuid,
      ],
    );
  } else {
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades SET
  local = ?,
  descricao = ?,
  qtd_realizada = ?,
  unidade = ?,
  situacao = ?,
  updated_at = ?,
  synced = 0
WHERE uuid = ?
''',
      <Object?>[
        local,
        descricao,
        qtdRealizada,
        unidade,
        situacao,
        ts,
        uuid,
      ],
    );
  }
  if (situacao != null && situacao == kSituacaoExcluidoLogico) {
    final idRows = await database.rawQuery(
      'SELECT id FROM relatorio_atividades WHERE uuid = ? LIMIT 1',
      [uuid],
    );
    final atividadeId =
        idRows.isEmpty ? null : idRows.first['id'] as int?;
    if (atividadeId != null) {
      await database.rawUpdate(
        '''
UPDATE relatorio_atividades_itens
SET situacao = ?, updated_at = ?, synced = 0
WHERE relatorio_atividade_id = ?
''',
        [kSituacaoExcluidoLogico, ts, atividadeId],
      );
      await database.rawUpdate(
        '''
UPDATE relatorio_atividade_fotos
SET situacao = ?, updated_at = ?, synced = 0
WHERE relatorio_atividade_id = ?
''',
        [kSituacaoExcluidoLogico, ts, atividadeId],
      );
    }
  }
  final rRows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_atividades WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid =
      rRows.isEmpty ? null : rRows.first['relatorio_id'] as int?;
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END UPDATEATIVIDADE

/// BEGIN UPDATERELATORIO
Future performUpdateRelatorio(
  Database database, {
  String? dataExecutado,
  String? horas,
  String? id,
  String? entradaManha,
  String? inicioIntervalo,
  String? fimIntervalo,
  String? saidaTarde,
}) {
  final ts = _sqlNowUtcEscaped();
  final query = '''
UPDATE relatorios set 
data_executado = '${dataExecutado}',  
horas_trabalhadas = '${horas}',
entrada_manha = '${entradaManha}',
saida_manha = '${inicioIntervalo}',
inicio_intervalo = '${inicioIntervalo}',
fim_intervalo = '${fimIntervalo}',
entrada_tarde = '${fimIntervalo}',
saida_tarde = '${saidaTarde}',
updated_at = '$ts',
synced = 0
WHERE id = ${id};
''';
  return database.rawQuery(query);
}

/// END UPDATERELATORIO

/// BEGIN SETMAOOBRARELATORIO
Future performSetMaoObraRelatorio(
  Database database, {
  int? relatorioId,
  int? companyId,
  int? obraItemId,
  String? dataReferencia,
  String? statusPresenca,
  String? horaEntrada,
  String? horaSaida,
  String? intervaloInicio,
  String? intervaloFim,
  String? horasTrabalhadas,
  String? createdBy,
  String? createdAt,
  String? relatorioUuid,
  String? uuid,
  String? companyUuid,
  String? obraItemUuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final horasSql = _sqlNullableHoras(horasTrabalhadas);
  final query = '''
INSERT INTO relatorio_mao_obra_presenca (
uuid,
relatorio_id, 
relatorio_uuid,
company_id, 
company_uuid,
obra_item_id, 
obra_item_uuid,
data_referencia, 
status_presenca, 
hora_entrada,
hora_saida,
intervalo_inicio,
intervalo_fim,
horas_trabalhadas, 
created_by,
created_at,
situacao,
motivo_saida_cedo,
updated_at,
synced) 
VALUES 
(
'${uuid}',
${relatorioId}, 
'${relatorioUuid}',
${companyId},
'${companyUuid}',
${obraItemId},
'${obraItemUuid}',
'${dataReferencia}',
'${statusPresenca}',
'${horaEntrada}',
'${horaSaida}',
'${intervaloInicio}',
'${intervaloFim}',
$horasSql,
'${createdBy}', 
'${createdAt}',
${kSituacaoAtivo},
NULL,
'$ts',
0
);
''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END SETMAOOBRARELATORIO

/// BEGIN UPDATEMAOOBRARELATORIO
Future performUpdateMaoObraRelatorio(
  Database database, {
  String? status,
  String? horaEntrada,
  String? horaSaida,
  String? intervaloInicio,
  String? intervaloFim,
  String? horasTrabalhadas,
  String? motivoAusencia,
  String? motivoSaidaCedo,
  String? motivoAtraso,
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final uuidEsc = (uuid ?? '').replaceAll("'", "''");
  final query = '''
UPDATE relatorio_mao_obra_presenca 
set 
status_presenca = ${_sqlNullableText(status)}, 
hora_entrada = ${_sqlNullableText(horaEntrada)}, 
hora_saida = ${_sqlNullableText(horaSaida)}, 
intervalo_inicio = ${_sqlNullableText(intervaloInicio)},
intervalo_fim = ${_sqlNullableText(intervaloFim)},
horas_trabalhadas = ${_sqlNullableHoras(horasTrabalhadas)},
motivo_ausencia = ${_sqlNullableText(motivoAusencia)},
motivo_saida_cedo = ${_sqlNullableText(motivoSaidaCedo)},
motivo_atraso = ${_sqlNullableText(motivoAtraso)},
updated_at = '$ts',
synced = 0
WHERE uuid = '$uuidEsc';
''';
  await database.rawQuery(query);
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_mao_obra_presenca WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END UPDATEMAOOBRARELATORIO

/// BEGIN SETORDEMRELATORIO
Future performSetOrdemRelatorio(
  Database database, {
  int? relatorioId,
  int? ordemId,
  int? userId,
  String? relatorioUuid,
}) async {
  final query = '''
INSERT INTO relatorio_ordem_servico (
relatorio_id,
relatorio_uuid,
ordem_servico_id, 
created_by,
situacao) 
VALUES 
(
${relatorioId}, 
'${relatorioUuid}',
${ordemId}, 
${userId},
${kSituacaoAtivo}
);
''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END SETORDEMRELATORIO

/// BEGIN SETCUSTOSORDEMRELATORIO
Future performSetCustosOrdemRelatorio(
  Database database, {
  int? relatorioId,
  int? ordemId,
  int? relatorioOrdemServicoId,
  int? ordemServicoCustoId,
  double? qtdRealizada,
  double? valorUnitario,
  double? valorTotal,
  String? observacao,
  int? userId,
  String? relatorioUuid,
  String? relatorioOrdemServicoUuid,
  String? ordemServicoCustoUuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final query = '''
INSERT INTO relatorio_custos (
relatorio_id, 
relatorio_uuid,
ordem_servico_id, 
relatorio_ordem_servico_id,
relatorio_ordem_servico_uuid,
ordem_servico_custo_id,
ordem_servico_custo_uuid,
qtd_realizada,
valor_unitario_real,
valor_total_real,
observacao,
created_by,
situacao,
updated_at,
synced) 
VALUES 
(
${relatorioId}, 
'${relatorioUuid}',
${ordemId}, 
${relatorioOrdemServicoId},
'${relatorioOrdemServicoUuid}',
${ordemServicoCustoId},
'${ordemServicoCustoUuid}',
${qtdRealizada},
${valorUnitario},
${valorTotal},
'${observacao}',
${userId},
${kSituacaoAtivo},
'$ts',
0
);
''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, relatorioId);
}

/// END SETCUSTOSORDEMRELATORIO

/// BEGIN UPDATERELATORIOCUSTOQTDREALIZADA
Future<void> performUpdateRelatorioCustoQtdRealizada(
  Database database, {
  String? uuid,
  double? qtdRealizada,
}) async {
  if (uuid == null || uuid.isEmpty) return;
  final q = qtdRealizada ?? 0.0;
  final ts = DateTime.now().toUtc().toIso8601String();
  await database.rawUpdate(
    '''
UPDATE relatorio_custos SET
  qtd_realizada = ?,
  valor_total_real = ? * COALESCE(valor_unitario_real, 0),
  updated_at = ?,
  synced = 0
WHERE uuid = ?
''',
    [q, q, ts, uuid],
  );
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_custos WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END UPDATERELATORIOCUSTOQTDREALIZADA

/// BEGIN UPDATEEQUIPAMENTORECEBIDO
Future performUpdateEquipamentoRecebido(
  Database database, {
  num? qtd,
  String? uuid,
}) async {
  final u = (uuid ?? '').trim();
  if (u.isEmpty) return;
  final ts = DateTime.now().toUtc().toIso8601String();
  final q = (qtd ?? 0).toDouble();
  await database.rawUpdate(
    '''
UPDATE relatorio_equipamento_recebido
SET quantidade = ?, updated_at = ?, synced = 0
WHERE uuid = ?
''',
    [q, ts, u],
  );
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_equipamento_recebido WHERE uuid = ? LIMIT 1',
    [u],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END UPDATEEQUIPAMENTORECEBIDO

/// BEGIN DELETEANEXORELATORIO
Future performDeleteAnexoRelatorio(
  Database database, {
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_anexos WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  final query = '''
UPDATE relatorio_anexos
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE uuid = '${uuid}';

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETEANEXORELATORIO

/// BEGIN DELETEEQUIPAMENTORECEBIDO
Future performDeleteEquipamentoRecebido(
  Database database, {
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_equipamento_recebido WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  final query = '''
UPDATE relatorio_equipamento_recebido
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE uuid = '${uuid}';

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETEEQUIPAMENTORECEBIDO

/// BEGIN DELETEOCORRENCIASRELATORIO
Future performDeleteOcorrenciasRelatorio(
  Database database, {
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_ocorrencias WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  final query = '''
UPDATE relatorio_ocorrencias
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE uuid = '${uuid}'

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETEOCORRENCIASRELATORIO

/// BEGIN DELETECOMENTARIOELATORIO
Future performDeleteComentarioelatorio(
  Database database, {
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_comentarios WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  final query = '''
UPDATE relatorio_comentarios
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE uuid = '${uuid}';

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETECOMENTARIOELATORIO

/// BEGIN DELETEATIVIDADERELATORIO
Future performDeleteAtividadeRelatorio(
  Database database, {
  int? id,
}) async {
  final ts = _sqlNowUtcEscaped();
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_atividades WHERE id = ? LIMIT 1',
    [id],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await database.rawQuery(
    '''
UPDATE relatorio_atividades_itens
SET situacao = ${kSituacaoExcluidoLogico}, updated_at = '$ts', synced = 0
WHERE relatorio_atividade_id = ${id};
''',
  );
  await database.rawQuery(
    '''
UPDATE relatorio_atividade_fotos
SET situacao = ${kSituacaoExcluidoLogico}, updated_at = '$ts', synced = 0
WHERE relatorio_atividade_id = ${id};
''',
  );
  final query = '''
UPDATE relatorio_atividades
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE id = ${id};

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETEATIVIDADERELATORIO

/// BEGIN DELETEORDEMRELATORIO
Future performDeleteOrdemRelatorio(
  Database database, {
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_ordem_servico WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await database.rawQuery(
    '''
UPDATE relatorio_custos
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE relatorio_ordem_servico_uuid = '${uuid}';
''',
  );
  final query = '''
UPDATE relatorio_ordem_servico
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE uuid = '${uuid}';

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETEORDEMRELATORIO

/// BEGIN DELETEMAOOBRARELATORIO
Future performDeleteMaoObraRelatorio(
  Database database, {
  String? uuid,
}) async {
  final ts = _sqlNowUtcEscaped();
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_mao_obra_presenca WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  final query = '''
UPDATE relatorio_mao_obra_presenca
SET situacao = ${kSituacaoExcluidoLogico}, synced = 0, updated_at = '$ts'
WHERE uuid = '${uuid}';

''';
  await database.rawQuery(query);
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END DELETEMAOOBRARELATORIO

/// BEGIN SOFTDELETERELATORIO
Future performSoftDeleteRelatorio(
  Database database, {
  String? uuid,
}) async {
  if (uuid == null || uuid.isEmpty) return;

  final ts = _sqlNowUtcEscaped();
  const ex = kSituacaoExcluidoLogico;

  final relRows = await database.rawQuery(
    'SELECT id FROM relatorios WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  if (relRows.isEmpty) return;

  final relatorioId = relRows.first['id'] as int;

  final ativRows = await database.rawQuery(
    '''
SELECT id FROM relatorio_atividades
WHERE relatorio_id = ? AND (situacao IS NULL OR situacao <> ?)
''',
    [relatorioId, ex],
  );

  for (final row in ativRows) {
    final atividadeId = row['id'] as int;
    await database.rawUpdate(
      '''
UPDATE relatorio_atividades_itens
SET situacao = ?, updated_at = ?, synced = 0
WHERE relatorio_atividade_id = ? AND (situacao IS NULL OR situacao <> ?)
''',
      [ex, ts, atividadeId, ex],
    );
    await database.rawUpdate(
      '''
UPDATE relatorio_atividade_fotos
SET situacao = ?, updated_at = ?, synced = 0
WHERE relatorio_atividade_id = ? AND (situacao IS NULL OR situacao <> ?)
''',
      [ex, ts, atividadeId, ex],
    );
  }

  const filhasPorRelatorioId = <String>[
    'relatorio_atividades',
    'relatorio_comentarios',
    'relatorio_ocorrencias',
    'relatorio_mao_obra_presenca',
    'relatorio_equipamento_recebido',
    'relatorio_anexos',
    'relatorio_ordem_servico',
    'relatorio_custos',
  ];

  for (final tabela in filhasPorRelatorioId) {
    await database.rawUpdate(
      '''
UPDATE $tabela
SET situacao = ?, updated_at = ?, synced = 0
WHERE relatorio_id = ? AND (situacao IS NULL OR situacao <> ?)
''',
      [ex, ts, relatorioId, ex],
    );
  }

  await database.rawUpdate(
    '''
UPDATE relatorios
SET situacao = ?, synced = 0, updated_at = ?
WHERE uuid = ?
''',
    [ex, ts, uuid],
  );
}

/// END SOFTDELETERELATORIO

/// BEGIN UPDATECOMENTARIO
Future performUpdateComentario(
  Database database, {
  String? uuid,
  String? texto,
}) async {
  final ts = _sqlNowUtcEscaped();
  final query = '''
UPDATE relatorio_comentarios SET texto = '${texto}', updated_at = '$ts', synced = 0 WHERE uuid = '${uuid}'
''';
  await database.rawQuery(query);
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_comentarios WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END UPDATECOMENTARIO

/// BEGIN UPDATEOCORRENCIA
Future performUpdateOcorrencia(
  Database database, {
  String? uuid,
  String? descricao,
  String? horaInicio,
  String? horaFim,
  int? situacao,
}) async {
  final sit = situacao ?? kSituacaoAtivo;
  final ts = _sqlNowUtcEscaped();
  final query = '''
UPDATE relatorio_ocorrencias 
SET descricao = '${descricao}',  
hora_inicio = '${horaInicio}', 
hora_saida = '${horaFim}',
situacao = ${sit},
updated_at = '$ts',
synced = 0
WHERE uuid = '${uuid}'
''';
  await database.rawQuery(query);
  final rows = await database.rawQuery(
    'SELECT relatorio_id FROM relatorio_ocorrencias WHERE uuid = ? LIMIT 1',
    [uuid],
  );
  final rid = rows.isEmpty ? null : rows.first['relatorio_id'] as int?;
  await _touchRelatorioModificadoLocal(database, rid);
}

/// END UPDATEOCORRENCIA

/// BEGIN ALTERARSTATUSRELATORIO
Future performAlterarStatusRelatorio(
  Database database, {
  String? id,
  int? status,
}) {
  final ts = _sqlNowUtcEscaped();
  final query = '''
UPDATE relatorios set status_id = ${status}, updated_at = '$ts', synced = 0 WHERE id = ${id};
''';
  return database.rawQuery(query);
}

/// END ALTERARSTATUSRELATORIO

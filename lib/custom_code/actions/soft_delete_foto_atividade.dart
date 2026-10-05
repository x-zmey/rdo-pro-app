// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart';
import '/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_config.dart';

import '/backend/sqlite/situacao_soft_delete.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'dart:io';

Future<bool> _tabelaTemColuna(Database db, String tabela, String coluna) async {
  final rows = await db.rawQuery('PRAGMA table_info($tabela)');
  for (final r in rows) {
    if (r['name'] == coluna) return true;
  }
  return false;
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Remove foto da atividade: soft delete local (`situacao` = excluído lógico; ver [kSituacaoExcluidoLogico]) quando a coluna
/// existir; caso contrário remove o registro. Se já estava sincronizada, tenta
/// `DELETE` na API com o id do servidor (`sync_id_mapping`).
Future<void> softDeleteFotoAtividade(int localFotoId) async {
  final db = SQLiteManager.instance.database;
  final rows = await db.query(
    'relatorio_atividade_fotos',
    where: 'id = ?',
    whereArgs: [localFotoId],
  );
  if (rows.isEmpty) return;

  final row = rows.first;
  final arquivo = row['arquivo']?.toString() ?? '';
  final uuid = row['uuid']?.toString() ?? '';
  final synced = _asInt(row['synced']) ?? 0;
  final relatorioAtividadeId = _asInt(row['relatorio_atividade_id']);

  final token = FFAppState().UserToken.trim();

  if (synced == 1 && token.isNotEmpty && uuid.isNotEmpty) {
    final map = await db.query(
      'sync_id_mapping',
      where: 'tabela = ? AND uuid = ?',
      whereArgs: ['relatorio_atividade_fotos', uuid],
    );
    final serverId = map.isNotEmpty ? _asInt(map.first['id_servidor']) : null;
    if (serverId != null && serverId > 0) {
      final uri = Uri.parse(
        '$kApiBaseUrl/api/relatorio/atividade/foto/$serverId/delete',
      );
      final resp = await http.delete(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        throw Exception(
          'Não foi possível excluir no servidor (${resp.statusCode}).',
        );
      }
    }
  }

  final hasSituacao =
      await _tabelaTemColuna(db, 'relatorio_atividade_fotos', 'situacao');

  final tsUtc = DateTime.now().toUtc().toIso8601String();

  if (hasSituacao) {
    await db.update(
      'relatorio_atividade_fotos',
      {
        'situacao': kSituacaoExcluidoLogico,
        'synced': 0,
        'updated_at': tsUtc,
      },
      where: 'id = ?',
      whereArgs: [localFotoId],
    );
  } else {
    await db.delete(
      'relatorio_atividade_fotos',
      where: 'id = ?',
      whereArgs: [localFotoId],
    );
    if (arquivo.isNotEmpty &&
        !arquivo.toLowerCase().startsWith('http://') &&
        !arquivo.toLowerCase().startsWith('https://')) {
      try {
        final f = File(arquivo);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }
  }

  if (relatorioAtividadeId != null && relatorioAtividadeId > 0) {
    await db.rawUpdate(
      'UPDATE relatorio_atividades SET updated_at = ?, synced = 0 WHERE id = ?',
      [tsUtc, relatorioAtividadeId],
    );
    final ra = await db.rawQuery(
      'SELECT relatorio_id FROM relatorio_atividades WHERE id = ? LIMIT 1',
      [relatorioAtividadeId],
    );
    final rid = ra.isEmpty ? null : _asInt(ra.first['relatorio_id']);
    if (rid != null && rid > 0) {
      await SQLiteManager.instance.touchRelatorioModificadoLocal(
        relatorioId: rid,
      );
    }
  }
}

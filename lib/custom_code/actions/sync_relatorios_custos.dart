// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
import 'sync_last_sync_for_creator.dart';

// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_config.dart';

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import 'sync_relatorio_download_merge_guard.dart';

const String _kUrlUploadRelatorioCustos =
    '$kApiBaseUrl/api/v1/sync/relatorios/ordens-custos/upload';
const String _kUrlDownloadRelatorioCustos =
    '$kApiBaseUrl/api/v1/sync/relatorios/ordens-custos/download';

Uri _uriRelatorioCustosUpload() =>
    Uri.parse(_kUrlUploadRelatorioCustos.trim());

Uri _uriRelatorioCustosDownload() =>
    Uri.parse(_kUrlDownloadRelatorioCustos.trim());

// ===== FUNÇÕES UTILITÁRIAS (já existentes - copie da action anterior) =====

Future<void> _salvarMapeamento(
    String tabela, int idServidor, String uuid) async {
  final db = await SQLiteManager.instance.database;
  try {
    await db.insert('sync_id_mapping', {
      'tabela': tabela,
      'id_servidor': idServidor,
      'uuid': uuid,
      'created_at': DateTime.now().toIso8601String(),
    });

    print('mapeamento salvo');
  } catch (e) {
    if (!e.toString().contains('UNIQUE constraint')) {
      print('❌ Erro ao salvar mapeamento: $e');
    }
  }
}

Future<int?> _getIdLocalPorIdServidor(String tabela, int idServidor) async {
  final db = await SQLiteManager.instance.database;
  try {
    final mapeamento = await db.query(
      'sync_id_mapping',
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: [tabela, idServidor],
    );
    if (mapeamento.isEmpty) return null;
    final uuid = mapeamento.first['uuid'] as String;
    final registro =
        await db.query(tabela, where: 'uuid = ?', whereArgs: [uuid]);
    return registro.isNotEmpty ? registro.first['id'] as int : null;
  } catch (e) {
    print('❌ Erro ao buscar mapeamento: $e');
    return null;
  }
}

Future<int?> _getIdLocalPorUuid(String tabela, String uuid) async {
  final db = await SQLiteManager.instance.database;
  final registro = await db.query(tabela, where: 'uuid = ?', whereArgs: [uuid]);
  return registro.isNotEmpty ? registro.first['id'] as int : null;
}

Future<String> _getUltimaSync(String tabela) async {
  return lastSyncDateForCurrentCreator(tabela);
}

String _generateUuid() {
  final random = Random();
  final hexDigits = '0123456789abcdef';
  String generatePart(int length) {
    return List.generate(length, (index) => hexDigits[random.nextInt(16)])
        .join();
  }

  return '${generatePart(8)}-${generatePart(4)}-4${generatePart(3)}-${generatePart(4)}-${generatePart(12)}';
}

String? _nonEmptyStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _createdByLocal(Map<String, dynamic> row) {
  // SQLite (`nova.sql`): `created_by` é UUID TEXT.
  final byUuid = _nonEmptyStr(row['created_by_uuid']);
  if (byUuid != null) return byUuid;

  final createdBy = _nonEmptyStr(row['created_by']);
  if (createdBy != null && createdBy.contains('-')) return createdBy;

  // Mantém NOT NULL no SQLite sem introduzir um número em vez de UUID.
  return '';
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncRelatoriosCustos() async {
  try {
    final db = await SQLiteManager.instance.database;
    final token = await _getAuthToken();

    if (token.isEmpty) {
      _updateSyncStatus(false, 'Usuário não autenticado', 0, 0);
      return;
    }

    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };

    int uploadedCount = 0;
    int downloadedCount = 0;

    // ===== 1. UPLOAD — só [relatorio_custos]: created_by = tenant, sem JOIN =====
    try {
      await stampPendingRelatorioCustosCreatedByTenantFallback(db);

      var relatorioCustosNaoSincronizadas =
          await pendingRelatorioCustosForTenantSimple(db);

      if (relatorioCustosNaoSincronizadas.isNotEmpty) {
        for (final relatorioCusto in relatorioCustosNaoSincronizadas) {
          if (relatorioCusto['uuid'] == null ||
              (relatorioCusto['uuid'] as String?)?.trim().isEmpty == true) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_custos',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorioCusto['id']],
            );
            print(
                '✅ Gerado UUID para relatorio custo: ${relatorioCusto['id']} -> $newUuid');
          }
        }

        final relatorioCustosComUuid =
            await pendingRelatorioCustosForTenantSimple(db);

        final relatorioCustosParaEnviar = <Map<String, dynamic>>[];
        for (final rowC in relatorioCustosComUuid) {
          final linha = Map<String, dynamic>.from(rowC);
          await backfillRelatorioUuidForPayloadRow(db, linha);
          relatorioCustosParaEnviar.add({
            'uuid': linha['uuid'],
            'relatorio_id': linha['relatorio_id'],
            'relatorio_uuid': _nonEmptyStr(linha['relatorio_uuid']),
            'relatorio_ordem_servico_id':
                linha['relatorio_ordem_servico_id'],
            'relatorio_ordem_servico_uuid':
                _nonEmptyStr(linha['relatorio_ordem_servico_uuid']),
            'ordem_servico_custo_id': linha['ordem_servico_custo_id'],
            'ordem_servico_custo_uuid':
                _nonEmptyStr(linha['ordem_servico_custo_uuid']),
            'qtd_realizada': linha['qtd_realizada'],
            'qtd_manual': linha['qtd_manual'] == true ||
                    linha['qtd_manual'] == 1 ||
                    linha['qtd_manual'] == '1'
                ? 1
                : 0,
            'valor_unitario_real': linha['valor_unitario_real'],
            'valor_total_real': linha['valor_total_real'],
            'observacao': linha['observacao'],
            'created_by_uuid': _nonEmptyStr(linha['created_by']),
            'created_at': linha['created_at'],
            'updated_at': linha['updated_at'],
          });
        }

        print(
            '📤 Enviando ${relatorioCustosParaEnviar.length} relatorios ordens custos...');
        print('📤 POST ${_uriRelatorioCustosUpload()}');

        final uploadResponse = await http.post(
          _uriRelatorioCustosUpload(),
          headers: headers,
          body: json.encode({'dados': relatorioCustosParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadBody =
              mapaRespostaSyncJson(json.decode(uploadResponse.body));
          final stUpload = serverTimeDoJsonResposta(uploadBody);

          for (final rowSrv in servidorVenceuLwwDoJson(uploadBody)) {
            await _processarOrdemTarefa(rowSrv, stUpload,
                prioridadeServidor: true);
          }

          // MARCAR RELATORIOS TAREFAS COMO SINCRONIZADAS
          final sinc = uploadBody['sincronizados'];
          for (var relatorioCusto in (sinc is List ? sinc : const [])) {
            if (relatorioCusto is! Map) continue;
            final u = relatorioCusto['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_custos',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [u],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount relatorios ordens');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioCusto in relatorioCustosComUuid) {
            final currentCount = relatorioCusto['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_custos',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioCusto['uuid']],
            );
          }
          print(
              '❌ Erro no upload: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhuma relatorio ordem custo para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_custos');
      print('📥 Buscando relatorios ordens custos desde: $lastSync');
      print('📥 POST ${_uriRelatorioCustosDownload()}');

      final downloadResponse = await http.post(
        _uriRelatorioCustosDownload(),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatorioCustosDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${relatorioCustosDoServidor.length} ordens custos');

        for (var relatorioCustoServer in relatorioCustosDoServidor) {
          await _processarOrdemTarefa(
              relatorioCustoServer, downloadResult['server_time']);
          downloadedCount++;
        }

        if (relatorioCustosDoServidor.isNotEmpty) {
          await updateLastSyncRelatorioCustosSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print(
            '✅ Download concluído: $downloadedCount relatorios ordens custos');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print(
            '❌ Erro no download: ${downloadResponse.statusCode} — ${downloadResponse.body}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync ordens custos concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios ordens custos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios  ordens: $e');
    _updateSyncStatus(
        false, 'Erro geral sync relatorios ordens custos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioCustoServer, String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = relatorioCustoServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioCustoServer['id'] != null) {
    await _salvarMapeamento(
        'relatorio_custos', relatorioCustoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorio_custos',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: relatorioCustoServer,
          tabela: 'relatorio_custos',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    // UPDATE
    await db.update(
      'relatorio_custos',
      {
        'relatorio_id': relatorioCustoServer['relatorio_id'],
        'relatorio_uuid': _nonEmptyStr(relatorioCustoServer['relatorio_uuid']),
        'relatorio_ordem_servico_id':
            relatorioCustoServer['relatorio_ordem_servico_id'],
        'relatorio_ordem_servico_uuid':
            _nonEmptyStr(relatorioCustoServer['relatorio_ordem_servico_uuid']),
        'ordem_servico_custo_id':
            relatorioCustoServer['ordem_servico_custo_id'],
        'ordem_servico_custo_uuid':
            _nonEmptyStr(relatorioCustoServer['ordem_servico_custo_uuid']),
        'qtd_realizada': relatorioCustoServer['qtd_realizada'],
        'qtd_manual': relatorioCustoServer['qtd_manual'] == true ||
                relatorioCustoServer['qtd_manual'] == 1 ||
                relatorioCustoServer['qtd_manual'] == '1'
            ? 1
            : 0,
        'valor_unitario_real': relatorioCustoServer['valor_unitario_real'],
        'valor_total_real': relatorioCustoServer['valor_total_real'],
        'observacao': relatorioCustoServer['observacao'],
        'created_by': _createdByLocal(relatorioCustoServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': relatorioCustoServer['created_at'],
        'updated_at': relatorioCustoServer['updated_at']
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert('relatorio_custos', {
      'uuid': uuid,
      'relatorio_id': relatorioCustoServer['relatorio_id'],
      'relatorio_uuid': _nonEmptyStr(relatorioCustoServer['relatorio_uuid']),
      'relatorio_ordem_servico_id':
          relatorioCustoServer['relatorio_ordem_servico_id'],
      'relatorio_ordem_servico_uuid':
          _nonEmptyStr(relatorioCustoServer['relatorio_ordem_servico_uuid']),
      'ordem_servico_custo_id': relatorioCustoServer['ordem_servico_custo_id'],
      'ordem_servico_custo_uuid':
          _nonEmptyStr(relatorioCustoServer['ordem_servico_custo_uuid']),
      'qtd_realizada': relatorioCustoServer['qtd_realizada'],
      'qtd_manual': relatorioCustoServer['qtd_manual'] == true ||
              relatorioCustoServer['qtd_manual'] == 1 ||
              relatorioCustoServer['qtd_manual'] == '1'
          ? 1
          : 0,
      'valor_unitario_real': relatorioCustoServer['valor_unitario_real'],
      'valor_total_real': relatorioCustoServer['valor_total_real'],
      'observacao': relatorioCustoServer['observacao'],
      'created_by': _createdByLocal(relatorioCustoServer),
      'synced': 1,
      'last_sync_date': serverTime,
      'created_at': relatorioCustoServer['created_at'],
      'updated_at': relatorioCustoServer['updated_at']
    });
  }
}

// ===== FUNÇÕES RESTANTES =====

void _updateSyncStatus(
    bool success, String message, int uploaded, int downloaded) {
  try {
    FFAppState().update(() {
      FFAppState().syncSuccess = success;
      FFAppState().syncMessage = message;
      FFAppState().syncUploadedCount = uploaded;
      FFAppState().syncDownloadedCount = downloaded;
      FFAppState().lastSyncTime = DateTime.now().toIso8601String();
    });
  } catch (e) {
    print('❌ Erro ao atualizar AppState: $e');
  }
}

Future<String> _getAuthToken() async {
  try {
    return FFAppState().UserToken;
  } catch (e) {
    return '';
  }
}

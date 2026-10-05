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

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import 'dart:convert';
import 'dart:math';

import 'sync_relatorio_download_merge_guard.dart';

/// Trim evita newline final na URL (Laravel devolvia MethodNotAllowed com `%0A`).
const String _kUrlUploadEquipamentoRecebido =
    '$kApiBaseUrl/api/v1/sync/relatorios/equipamentos-recebidos/upload';
const String _kUrlDownloadEquipamentoRecebido =
    '$kApiBaseUrl/api/v1/sync/relatorios/equipamentos-recebidos/download';

Uri _uriEquipamentoRecebidoUpload() =>
    Uri.parse(_kUrlUploadEquipamentoRecebido.trim());

Uri _uriEquipamentoRecebidoDownload() =>
    Uri.parse(_kUrlDownloadEquipamentoRecebido.trim());

/// Fila simples por `created_by` = tenant; se vazio com pendências globais, diagnóstico aqui.
Future<void> _logDiagnosticoFilaEquipamentoRecebidoVazia(Database db) async {
  final cu = currentCreatorUuidForSync();
  final cid = currentCreatorIdForSync();
  print(
      '🔎 [equip.receb.] fila tenant vazia — creatorUuid.len=${cu.length} creatorId=$cid');
  if (cu.isEmpty) {
    print(
        '🔎 [equip.receb.] … sem creatorUuid: não filtra materiais recebidos por tenant.');
    return;
  }
  try {
    final cnt = await db.rawQuery(
      '''
SELECT COUNT(*) AS c FROM relatorio_equipamento_recebido
WHERE synced IS NULL OR synced = 0
''',
    );
    final n = cnt.isEmpty
        ? 0
        : ((cnt.first['c'] as num?) ?? 0).toInt();
    final cntTenant = await db.rawQuery(
      '''
SELECT COUNT(*) AS c FROM relatorio_equipamento_recebido
WHERE (synced IS NULL OR synced = 0)
  AND LOWER(TRIM(COALESCE(created_by, ''))) = LOWER(?)
''',
      [cu],
    );
    final nt = cntTenant.isEmpty
        ? 0
        : ((cntTenant.first['c'] as num?) ?? 0).toInt();
    print(
        '🔎 [equip.receb.] pendentes globais: $n | pendentes com created_by=tenant: $nt');
    if (n < 1) return;
    final rows = await db.rawQuery(
      '''
SELECT uuid, relatorio_id, relatorio_uuid, equipamento_uuid, created_by, synced, quantidade
FROM relatorio_equipamento_recebido
WHERE synced IS NULL OR synced = 0
LIMIT 5
''',
    );
    print(
        '🔎 [equip.receb.] amostra (até 5) — se global>0 e tenant=0, `created_by` não bate com creatorUuid:');
    for (final r in rows) {
      print('🔎 [equip.receb.] … $r');
    }
  } catch (e) {
    print('🔎 [equip.receb.] diagnóstico falhou: $e');
  }
}

/// Âncora LWW na API: usar instante do envio evita rejeição quando o relógio do aparelho
/// está atrás do servidor ou o SQLite guardou `updated_at` anterior ao MySQL.
String _updatedAtUtcParaUploadEquipamentoRecebido() =>
    DateTime.now().toUtc().toIso8601String();

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
  // No SQLite (`nova.sql`), `created_by` é TEXT (UUID).
  return _nonEmptyStr(row['created_by_uuid']) ??
      _nonEmptyStr(row['created_by']) ??
      '';
}

// ===== FUNÇÃO PRINCIPAL =====

Future synRelatorioEquipamentoRecebido() async {
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

    // ===== 1. UPLOAD — só [relatorio_equipamento_recebido]: tenant em created_by, sem JOIN =====
    try {
      await stampPendingRelatorioEquipamentoRecebidoCreatedByTenantFallback(db);

      var relatoriosEquipamentosRecebidosNaoSincronizadas =
          await pendingRelatorioEquipamentoRecebidoForTenantSimple(db);

      if (relatoriosEquipamentosRecebidosNaoSincronizadas.isNotEmpty) {
        for (final relatorioEquipamentoRecebido
            in relatoriosEquipamentosRecebidosNaoSincronizadas) {
          if (relatorioEquipamentoRecebido['uuid'] == null ||
              (relatorioEquipamentoRecebido['uuid'] as String?)?.trim().isEmpty ==
                  true) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_equipamento_recebido',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorioEquipamentoRecebido['id']],
            );
            print(
                '✅ Gerado UUID para relatorio equipamento recebido: ${relatorioEquipamentoRecebido['id']} -> $newUuid');
          }
        }

        final relatoriosEquipamentosRecebidosComUuid =
            await pendingRelatorioEquipamentoRecebidoForTenantSimple(db);

        final relatoriosEquipamentosRecebidosParaEnviar =
            <Map<String, dynamic>>[];
        for (final rowEr in relatoriosEquipamentosRecebidosComUuid) {
          final linha = Map<String, dynamic>.from(rowEr);
          await backfillRelatorioUuidForPayloadRow(db, linha);
          relatoriosEquipamentosRecebidosParaEnviar.add({
            'uuid': linha['uuid'],
            'relatorio_id': linha['relatorio_id'],
            'relatorio_uuid': linha['relatorio_uuid'],
            'equipamento_id': linha['equipamento_id'],
            'equipamento_uuid': linha['equipamento_uuid'],
            'quantidade': linha['quantidade'],
            'situacao': linha['situacao'],
            'created_at': linha['created_at'],
            'updated_at': _updatedAtUtcParaUploadEquipamentoRecebido(),
          });
        }

        print(
            '📤 Enviando ${relatoriosEquipamentosRecebidosParaEnviar.length} relatorios equipamentos recebidos...');
        final uploadUri = _uriEquipamentoRecebidoUpload();
        print('📤 POST $uploadUri');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          uploadUri,
          headers: headers,
          body:
              json.encode({'dados': relatoriosEquipamentosRecebidosParaEnviar}),
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
          for (var relatorioEquipamentoRecebido
              in (sinc is List ? sinc : const [])) {
            if (relatorioEquipamentoRecebido is! Map) continue;
            final u = relatorioEquipamentoRecebido['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_equipamento_recebido',
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
          final sincN = uploadBody['sincronizados'];
          final nSrv =
              sincN is List ? sincN.length : 0;
          print(
              '✅ Upload concluído: marcados local=$uploadedCount | sincronizados na resposta=$nSrv');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioEquipamentoRecebido
              in relatoriosEquipamentosRecebidosComUuid) {
            final currentCount =
                relatorioEquipamentoRecebido['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_equipamento_recebido',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioEquipamentoRecebido['uuid']],
            );
          }
          print(
              '❌ Erro no upload: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhuma relatorio equipamento recebido para enviar');
        await _logDiagnosticoFilaEquipamentoRecebidoVazia(db);
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_equipamento_recebido');
      print('📥 Buscando relatorios equipamentos recebidos desde: $lastSync');
      final downloadUri = _uriEquipamentoRecebidoDownload();
      print('📥 POST $downloadUri');

      final downloadResponse = await http.post(
        downloadUri,
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosEquipamentosRecebidosDoServidor =
            downloadResult['dados'] as List;

        print(
            '📥 Recebidas ${relatoriosEquipamentosRecebidosDoServidor.length} equipamentos recebidos');

        for (var relatorioEquipamentoRecebidoServer
            in relatoriosEquipamentosRecebidosDoServidor) {
          await _processarOrdemTarefa(relatorioEquipamentoRecebidoServer,
              downloadResult['server_time']);
          downloadedCount++;
        }

        if (relatoriosEquipamentosRecebidosDoServidor.isNotEmpty) {
          await updateLastSyncEquipamentoRecebidoSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print(
            '✅ Download concluído: $downloadedCount relatorios equipamentos recebidos');
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
      'Sync equipamentos concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios equipamentos recebidos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios equipamentos: $e');
    _updateSyncStatus(
        false, 'Erro geral sync relatorios equipamentos recebidos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioEquipamentoRecebidoServer,
    String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = relatorioEquipamentoRecebidoServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioEquipamentoRecebidoServer['id'] != null) {
    await _salvarMapeamento('relatorio_equipamento_recebido',
        relatorioEquipamentoRecebidoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorio_equipamento_recebido',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: relatorioEquipamentoRecebidoServer,
          tabela: 'relatorio_equipamento_recebido',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    // UPDATE
    await db.update(
      'relatorio_equipamento_recebido',
      {
        'relatorio_id': relatorioEquipamentoRecebidoServer['relatorio_id'],
        'relatorio_uuid':
            _nonEmptyStr(relatorioEquipamentoRecebidoServer['relatorio_uuid']),
        'equipamento_id': relatorioEquipamentoRecebidoServer['equipamento_id'],
        'equipamento_uuid': _nonEmptyStr(
            relatorioEquipamentoRecebidoServer['equipamento_uuid']),
        'quantidade':
            parseQuantidadeRelatorio(relatorioEquipamentoRecebidoServer['quantidade']),
        'created_by': _createdByLocal(relatorioEquipamentoRecebidoServer),
        'situacao': relatorioEquipamentoRecebidoServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': relatorioEquipamentoRecebidoServer['created_at'],
        'updated_at': relatorioEquipamentoRecebidoServer['updated_at']
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert('relatorio_equipamento_recebido', {
      'uuid': uuid,
      'relatorio_id': relatorioEquipamentoRecebidoServer['relatorio_id'],
      'relatorio_uuid':
          _nonEmptyStr(relatorioEquipamentoRecebidoServer['relatorio_uuid']),
      'equipamento_id': relatorioEquipamentoRecebidoServer['equipamento_id'],
      'equipamento_uuid':
          _nonEmptyStr(relatorioEquipamentoRecebidoServer['equipamento_uuid']),
      'quantidade':
          parseQuantidadeRelatorio(relatorioEquipamentoRecebidoServer['quantidade']),
      'created_by': _createdByLocal(relatorioEquipamentoRecebidoServer),
      'situacao': relatorioEquipamentoRecebidoServer['situacao'],
      'synced': 1,
      'last_sync_date': serverTime,
      'created_at': relatorioEquipamentoRecebidoServer['created_at'],
      'updated_at': relatorioEquipamentoRecebidoServer['updated_at']
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
    return FFAppState().UserToken ?? '';
  } catch (e) {
    return '';
  }
}

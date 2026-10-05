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

Future synRelatoriosAnexos() async {
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

    // ===== 1. UPLOAD - Enviar dados locais =====
    try {
      final relatoriosAnexosNaoSincronizadas =
          await pendingRowsForCurrentCreatorViaRelatorio(
        db,
        table: 'relatorio_anexos',
        alias: 'an',
        pendingSql: 'an.synced = 0',
      );

      if (relatoriosAnexosNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA RELATORIOS SEM UUID
        for (var relatorioAnexo in relatoriosAnexosNaoSincronizadas) {
          if (relatorioAnexo['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_anexos',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorioAnexo['id']],
            );
            print(
                '✅ Gerado UUID para relatorio anexo: ${relatorioAnexo['id']} -> $newUuid');
          }
        }

        final relatoriosAnexosComUuid =
            await pendingRowsForCurrentCreatorViaRelatorio(
          db,
          table: 'relatorio_anexos',
          alias: 'an',
          pendingSql: 'an.synced = 0',
        );

        // PREPARAR DADOS PARA ENVIO
        final relatoriosAnexosParaEnviar =
            relatoriosAnexosComUuid.map((relatorioAnexo) {
          return {
            'uuid': relatorioAnexo['uuid'],
            'relatorio_id': relatorioAnexo['relatorio_id'],
            'relatorio_uuid': relatorioAnexo['relatorio_uuid'],
            'nome': relatorioAnexo['nome'],
            'arquivo': relatorioAnexo['arquivo'],
            // No SQLite, `created_by` já é UUID (TEXT). O backend resolve para o id numérico.
            'created_by_uuid': relatorioAnexo['created_by'],
            'created_at': relatorioAnexo['created_at'],
            'updated_at': relatorioAnexo['updated_at']
          };
        }).toList();

        print(
            '📤 Enviando ${relatoriosAnexosParaEnviar.length} relatorios anexos...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              '$kApiBaseUrl/api/v1/sync/relatorios/anexos/upload'),
          headers: headers,
          body: json.encode({'dados': relatoriosAnexosParaEnviar}),
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
          for (var relatorioAnexo in (sinc is List ? sinc : const [])) {
            if (relatorioAnexo is! Map) continue;
            final u = relatorioAnexo['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_anexos',
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
          print('✅ Upload concluído: $uploadedCount relatorios anexos');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioAnexo in relatoriosAnexosComUuid) {
            final currentCount = relatorioAnexo['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_anexos',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioAnexo['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhuma relatorio anexo para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_anexos');
      print('📥 Buscando relatorios anexos desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/relatorios/anexos/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosAnexosDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${relatoriosAnexosDoServidor.length} anexos');

        for (var relatorioAnexoServer in relatoriosAnexosDoServidor) {
          await _processarOrdemTarefa(
              relatorioAnexoServer, downloadResult['server_time']);
          downloadedCount++;
        }

        if (relatoriosAnexosDoServidor.isNotEmpty) {
          await updateLastSyncForSyncedRowsViaRelatorioIdForCurrentTenant(
            db,
            table: 'relatorio_anexos',
            alias: 'an',
            serverTime: downloadResult['server_time'].toString(),
          );
        }
        print('✅ Download concluído: $downloadedCount relatorios anexos');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync anexos concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios anexos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios  anexos: $e');
    _updateSyncStatus(false, 'Erro geral sync relatorios anexos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioAnexoServer, String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = relatorioAnexoServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioAnexoServer['id'] != null) {
    await _salvarMapeamento(
        'relatorio_anexos', relatorioAnexoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorio_anexos',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: relatorioAnexoServer,
          tabela: 'relatorio_anexos',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    // UPDATE
    await db.update(
      'relatorio_anexos',
      {
        'relatorio_id': relatorioAnexoServer['relatorio_id'],
        'relatorio_uuid': _nonEmptyStr(relatorioAnexoServer['relatorio_uuid']),
        'nome': relatorioAnexoServer['nome'],
        'arquivo': relatorioAnexoServer['arquivo'],
        'created_by': _createdByLocal(relatorioAnexoServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': relatorioAnexoServer['created_at'],
        'updated_at': relatorioAnexoServer['updated_at']
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert('relatorio_anexos', {
      'uuid': uuid,
      'relatorio_id': relatorioAnexoServer['relatorio_id'],
      'relatorio_uuid': _nonEmptyStr(relatorioAnexoServer['relatorio_uuid']),
      'nome': relatorioAnexoServer['nome'],
      'arquivo': relatorioAnexoServer['arquivo'],
      'created_by': _createdByLocal(relatorioAnexoServer),
      'synced': 1,
      'last_sync_date': serverTime,
      'created_at': relatorioAnexoServer['created_at'],
      'updated_at': relatorioAnexoServer['updated_at']
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

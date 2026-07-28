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

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

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

/// `created_by` na SQLite é TEXT com UUID.
/// Preferimos `created_by_uuid` vindo da API; caso não exista, fazemos fallback
/// para `created_by` (id numérico) convertido para string.
String _createdByLocal(Map<String, dynamic> row) {
  return _nonEmptyStr(row['created_by_uuid']) ??
      _nonEmptyStr(row['created_by']) ??
      '';
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncOrdensTarefas() async {
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
    bool hadError = false;

    // ===== 1. UPLOAD - Enviar dados locais =====
    /*try {
      final ordensTarefasNaoSincronizadas = await db.query(
        'ordem_servico_tarefas',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (ordensTarefasNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA ORDENS SEM UUID
        for (var ordemTarefa in ordensTarefasNaoSincronizadas) {
          if (ordemTarefa['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'ordem_servico_tarefas',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [ordemTarefa['id']],
            );
            print(
                '✅ Gerado UUID para ordem tarefa: ${ordemTarefa['nome']} -> $newUuid');
          }
        }

        // BUSCAR ORDENS TAREFAS ATUALIZADAS
        final ordensTarefasComUuid = await db.query(
          'ordens_servico_tarefas',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final ordensTarefasParaEnviar = ordensTarefasComUuid.map((ordemTarefa) {
          return {
            'uuid': ordemTarefa['uuid'],
            'ordem_servico_id': ordemTarefa['ordem_servico_id'],
            'obra_etapa_tarefa_id': ordemTarefa['obra_etapa_tarefa_id'],
            'qtd_programada': ordemTarefa['qtd_programada'],
            'qtd_realizada': ordemTarefa['qtd_realizada'],
            'unidade': ordemTarefa['unidade'],
            'data_execucao_inicio': ordemTarefa['data_execucao_inicio'],
            'data_execucao_fim': ordemTarefa['data_execucao_fim'],
            'status': ordemTarefa['status'],
            'created_by': ordemTarefa['created_by'],
            'created_at': ordemTarefa['created_at'],
            'updated_at': ordemTarefa['updated_at'],
          };
        }).toList();

        print(
            '📤 Enviando ${ordensTarefasParaEnviar.length} ordens tarefas...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              'https://api.rdopro.com.br/api/v1/sync/ordens/tarefas-upload'),
          headers: headers,
          body: json.encode({'dados': ordensTarefasParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          // MARCAR ORDENS TAREFAS COMO SINCRONIZADAS
          for (var ordemTarefa in uploadResult['sincronizados']) {
            await db.update(
              'ordem_servico_tarefas',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [ordemTarefa['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount ordens tarefas');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var ordemTarefa in ordensTarefasComUuid) {
            final currentCount = ordemTarefa['sync_try_count'] as int? ?? 0;
            await db.update(
              'ordem_servico_tarefas',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [ordemTarefa['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhuma ordem tarefa para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }*/

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('ordem_servico_tarefas');
      print('📥 Buscando ordens tarefas desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/ordens-servico/tarefas/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final ordensTarefasDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${ordensTarefasDoServidor.length} ordens');

        for (var ordemTarefaServer in ordensTarefasDoServidor) {
          await _processarOrdemTarefa(
              ordemTarefaServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (ordensTarefasDoServidor.isNotEmpty) {
          await db.update(
            'ordem_servico_tarefas',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount ordens tarefas');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no download: $e');
    }

    if (hadError) {
      throw Exception('Falha parcial no sync de ordem_servico_tarefas');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync ordens concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync ordens tarefas concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync ordens tarefas: $e');
    _updateSyncStatus(false, 'Erro geral sync ordens tarefas: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> ordemTarefaServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = ordemTarefaServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (ordemTarefaServer['id'] != null) {
    await _salvarMapeamento(
        'ordem_servico_tarefas', ordemTarefaServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'ordem_servico_tarefas',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'ordem_servico_tarefas',
      {
        'ordem_servico_id': ordemTarefaServer['ordem_servico_id'],
        'ordem_servico_uuid':
            _nonEmptyStr(ordemTarefaServer['ordem_servico_uuid']),
        'obra_etapa_tarefa_id': ordemTarefaServer['obra_etapa_tarefa_id'],
        'obra_etapa_tarefa_uuid':
            _nonEmptyStr(ordemTarefaServer['obra_etapa_tarefa_uuid']),
        'qtd_programada': ordemTarefaServer['qtd_programada'],
        'qtd_realizada': ordemTarefaServer['qtd_realizada'],
        'unidade': ordemTarefaServer['unidade'],
        'data_execucao_inicio': ordemTarefaServer['data_execucao_inicio'],
        'data_execucao_fim': ordemTarefaServer['data_execucao_fim'],
        'status': ordemTarefaServer['status'],
        'created_by': _createdByLocal(ordemTarefaServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': ordemTarefaServer['created_at'],
        'updated_at': ordemTarefaServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert(
      'ordem_servico_tarefas',
      {
        'uuid': uuid,
        'ordem_servico_id': ordemTarefaServer['ordem_servico_id'],
        'ordem_servico_uuid':
            _nonEmptyStr(ordemTarefaServer['ordem_servico_uuid']),
        'obra_etapa_tarefa_id': ordemTarefaServer['obra_etapa_tarefa_id'],
        'obra_etapa_tarefa_uuid':
            _nonEmptyStr(ordemTarefaServer['obra_etapa_tarefa_uuid']),
        'qtd_programada': ordemTarefaServer['qtd_programada'],
        'qtd_realizada': ordemTarefaServer['qtd_realizada'],
        'unidade': ordemTarefaServer['unidade'],
        'data_execucao_inicio': ordemTarefaServer['data_execucao_inicio'],
        'data_execucao_fim': ordemTarefaServer['data_execucao_fim'],
        'created_by': _createdByLocal(ordemTarefaServer),
        'status': ordemTarefaServer['status'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': ordemTarefaServer['created_at'],
        'updated_at': ordemTarefaServer['updated_at'],
      },
    );
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

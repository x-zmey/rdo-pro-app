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

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

// ===== FUNÇÕES UTILITÁRIAS =====

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
  } catch (e) {
    if (!e.toString().contains('UNIQUE constraint')) {
      print('❌ Erro ao salvar mapeamento: $e');
    }
  }
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

String _converterJsonParaString(dynamic jsonConfig) {
  if (jsonConfig == null) return '';
  if (jsonConfig is String) return jsonConfig;
  return json.encode(jsonConfig);
}

// ===== FUNÇÃO PRINCIPAL - CHECKLISTS_PREENCHIDOS =====

Future syncChecklistsPreenchidos() async {
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
      final checklistsNaoSincronizados = await db.query(
        'checklists_preenchidos',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (checklistsNaoSincronizados.isNotEmpty) {
        // GERAR UUIDs PARA CHECKLISTS SEM UUID
        for (var checklist in checklistsNaoSincronizados) {
          if (checklist['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'checklists_preenchidos',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [checklist['id']],
            );
            print('✅ Gerado UUID para checklist: $newUuid');
          }
        }

        // BUSCAR CHECKLISTS ATUALIZADOS
        final checklistsComUuid = await db.query(
          'checklists_preenchidos',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final checklistsParaEnviar = checklistsComUuid.map((checklist) {
          // TRATAR JSON_RESPOSTAS - garantir que é um Map válido
          dynamic jsonRespostas = checklist['json_respostas'];
          if (jsonRespostas is String) {
            try {
              jsonRespostas = json.decode(jsonRespostas);
            } catch (e) {
              jsonRespostas = {};
            }
          } else if (jsonRespostas == null) {
            jsonRespostas = {};
          }

          return {
            'uuid': checklist['uuid'],
            'checklist_template_id': checklist['checklist_template_id'],
            'obra_id': checklist['obra_id'],
            'usuario_id': checklist['usuario_id'], // Enviar o usuario_id do app
            'json_respostas': jsonRespostas,
            'nota_final': checklist['nota_final']
                ?.toString(), // Converter para string se necessário
            'situacao': checklist['situacao'] ?? 'pendente',
            'created_by': checklist['created_by'],
            'created_at': checklist['created_at'],
            'updated_at': checklist['updated_at'],
          };
        }).toList();

        print('📤 Enviando ${checklistsParaEnviar.length} checklists...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              'https://api.rdopro.com.br/api/v1/sync/checklists-preenchidos/upload'),
          headers: headers,
          body: json.encode({'dados': checklistsParaEnviar}),
        );

        print('📡 Status upload: ${uploadResponse.statusCode}');
        print('📡 Body upload: ${uploadResponse.body}');

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          if (uploadResult['status'] == 'ok') {
            // MARCAR CHECKLISTS COMO SINCRONIZADOS
            for (var checklist in uploadResult['sincronizados']) {
              await db.update(
                'checklists_preenchidos',
                {
                  'synced': 1,
                  'last_sync_date': DateTime.now().toIso8601String(),
                  'sync_try_count': 0,
                },
                where: 'uuid = ?',
                whereArgs: [checklist['uuid']],
              );
              uploadedCount++;
            }
            print('✅ Upload concluído: $uploadedCount checklists');
          } else {
            print('❌ Erro no servidor: ${uploadResult['mensagem']}');
          }
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var checklist in checklistsComUuid) {
            final currentCount = checklist['sync_try_count'] as int? ?? 0;
            await db.update(
              'checklists_preenchidos',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [checklist['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
          print('❌ Body do erro: ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhum checklist para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('checklists_preenchidos');
      print('📥 Buscando checklists desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/checklists-preenchidos/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      print('📡 Status download: ${downloadResponse.statusCode}');

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final checklistsDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${checklistsDoServidor.length} checklists');

        for (var checklistServer in checklistsDoServidor) {
          await _processarChecklistPreenchido(
              checklistServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (checklistsDoServidor.isNotEmpty) {
          await db.update(
            'checklists_preenchidos',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount checklists');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
        print('❌ Body do erro: ${downloadResponse.body}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync checklists concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync checklists preenchidos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync checklists: $e');
    _updateSyncStatus(false, 'Erro geral sync checklists: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE CHECKLIST PREENCHIDO =====

Future<void> _processarChecklistPreenchido(
    Map<String, dynamic> checklistServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = checklistServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (checklistServer['id'] != null) {
    await _salvarMapeamento(
        'checklists_preenchidos', checklistServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'checklists_preenchidos',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  // TRATAR JSON_RESPOSTAS
  dynamic jsonRespostas = checklistServer['json_respostas'];
  if (jsonRespostas != null && jsonRespostas is! String) {
    jsonRespostas = json.encode(jsonRespostas);
  }

  // VALORES PADRÃO
  final notaFinal = checklistServer['nota_final']?.toString();
  final situacao = checklistServer['situacao'] ?? 'pendente';

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'checklists_preenchidos',
      {
        'checklist_template_id': checklistServer['checklist_template_id'],
        'obra_id': checklistServer['obra_id'],
        'usuario_id': checklistServer['usuario_id'],
        'json_respostas': jsonRespostas,
        'nota_final': notaFinal,
        'situacao': situacao,
        'created_by': checklistServer['created_by'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': checklistServer['created_at'],
        'updated_at': checklistServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Checklist atualizado: $uuid');
  } else {
    // INSERT
    await db.insert(
      'checklists_preenchidos',
      {
        'uuid': uuid,
        'checklist_template_id': checklistServer['checklist_template_id'],
        'obra_id': checklistServer['obra_id'],
        'usuario_id': checklistServer['usuario_id'],
        'json_respostas': jsonRespostas,
        'nota_final': notaFinal,
        'situacao': situacao,
        'created_by': checklistServer['created_by'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': checklistServer['created_at'],
        'updated_at': checklistServer['updated_at'],
      },
    );
    print('✅ Novo checklist inserido: $uuid');
  }
}

// ===== FUNÇÕES AUXILIARES =====

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

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

// Set your action name, define your arguments and return parameter,
// and then add the boilerplate code using the green button on the right!

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

// ===== FUNÇÃO PRINCIPAL - SOLUCOES_PLANOS_ACOES =====

Future syncSolucoesPlanosAcoes() async {
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
      final solucoesNaoSincronizadas = await db.query(
        'solucoes_planos_acoes',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (solucoesNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA SOLUÇÕES SEM UUID
        for (var solucao in solucoesNaoSincronizadas) {
          if (solucao['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'solucoes_planos_acoes',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [solucao['id']],
            );
            print('✅ Gerado UUID para solução: $newUuid');
          }
        }

        // BUSCAR SOLUÇÕES ATUALIZADAS
        final solucoesComUuid = await db.query(
          'solucoes_planos_acoes',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final solucoesParaEnviar = solucoesComUuid.map((solucao) {
          return {
            'uuid': solucao['uuid'],
            'plano_acao_id': solucao['plano_acao_id'],
            'titulo': solucao['titulo'],
            'descricao': solucao['descricao'],
            'custo': solucao['custo'],
            'quantidade': solucao['quantidade'],
            'status': solucao['status'],
            'created_by': solucao['created_by'],
            'created_at': solucao['created_at'],
            'updated_at': solucao['updated_at'],
          };
        }).toList();

        print('📤 Enviando ${solucoesParaEnviar.length} soluções...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              '$kApiBaseUrl/api/v1/sync/solucoes-planos-acoes/upload'),
          headers: headers,
          body: json.encode({'dados': solucoesParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          // MARCAR SOLUÇÕES COMO SINCRONIZADAS
          for (var solucao in uploadResult['sincronizados']) {
            await db.update(
              'solucoes_planos_acoes',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [solucao['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount soluções');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var solucao in solucoesComUuid) {
            final currentCount = solucao['sync_try_count'] as int? ?? 0;
            await db.update(
              'solucoes_planos_acoes',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [solucao['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhuma solução para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('solucoes_planos_acoes');
      print('📥 Buscando soluções desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/solucoes-planos-acoes/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final solucoesDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${solucoesDoServidor.length} soluções');

        for (var solucaoServer in solucoesDoServidor) {
          await _processarSolucaoPlanoAcao(
              solucaoServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (solucoesDoServidor.isNotEmpty) {
          await db.update(
            'solucoes_planos_acoes',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount soluções');
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
      'Sync soluções concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync soluções planos ação concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync soluções: $e');
    _updateSyncStatus(false, 'Erro geral sync soluções: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE SOLUÇÃO PLANO AÇÃO =====

Future<void> _processarSolucaoPlanoAcao(
    Map<String, dynamic> solucaoServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = solucaoServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (solucaoServer['id'] != null) {
    await _salvarMapeamento(
        'solucoes_planos_acoes', solucaoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'solucoes_planos_acoes',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  // VALORES PADRÃO
  final quantidade = solucaoServer['quantidade'] ?? 1;
  final custo = solucaoServer['custo'] ?? 0.0;
  final status = solucaoServer['status'] ?? 'Pendente';

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'solucoes_planos_acoes',
      {
        'plano_acao_id': solucaoServer['plano_acao_id'],
        'titulo': solucaoServer['titulo'],
        'descricao': solucaoServer['descricao'],
        'custo': custo,
        'quantidade': quantidade,
        'status': status,
        'created_by': solucaoServer['created_by'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': solucaoServer['created_at'],
        'updated_at': solucaoServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Solução atualizada: ${solucaoServer['titulo']}');
  } else {
    // INSERT
    await db.insert(
      'solucoes_planos_acoes',
      {
        'uuid': uuid,
        'plano_acao_id': solucaoServer['plano_acao_id'],
        'titulo': solucaoServer['titulo'],
        'descricao': solucaoServer['descricao'],
        'custo': custo,
        'quantidade': quantidade,
        'status': status,
        'created_by': solucaoServer['created_by'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': solucaoServer['created_at'],
        'updated_at': solucaoServer['updated_at'],
      },
    );
    print('✅ Nova solução inserida: ${solucaoServer['titulo']}');
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

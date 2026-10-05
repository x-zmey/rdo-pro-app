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

// ===== FUNÇÃO PRINCIPAL =====

Future syncOrdensCustos() async {
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
    /*try {
      final ordensCustosNaoSincronizadas = await db.query(
        'ordem_servico_custos',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (ordensCustosNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA ORDENS SEM UUID
        for (var ordemCusto in ordensCustosNaoSincronizadas) {
          if (ordemCusto['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'ordem_servico_custos',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [ordemCusto['id']],
            );
            print(
                '✅ Gerado UUID para ordem custo: ${ordemCusto['id']} -> $newUuid');
          }
        }

        // BUSCAR ORDENS CUSTOS ATUALIZADAS
        final ordensCutosComUuid = await db.query(
          'ordens_servico_custos',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final ordensCustosParaEnviar = ordensCustosComUuid.map((ordemCusto) {
          return {
            'uuid': ordemCusto['uuid'],
            'ordem_servico_id': ordemCusto['ordem_servico_id'],
            'descricao': ordemCusto['descricao'],
            'unidade': ordemCusto['unidade'],
            'qtd_prevista': ordemCusto['qtd_prevista'],
            'valor_unitario': ordemCusto['valor_unitario'],
            'valor_total': ordemCusto['valor_total'],
            'created_by': ordemCusto['created_by'],
            'created_at': ordemCusto['created_at'],
            'updated_at': ordemCusto['updated_at'],
          };
        }).toList();

        print('📤 Enviando ${ordensCustosParaEnviar.length} ordens custos...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              '$kApiBaseUrl/api/v1/sync/ordens/custos-upload'),
          headers: headers,
          body: json.encode({'dados': ordensCustosParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          // MARCAR ORDENS CUSTOS COMO SINCRONIZADAS
          for (var ordemCusto in uploadResult['sincronizados']) {
            await db.update(
              'ordem_servico_custos',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [ordemCusto['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount ordens custos');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var ordemCusto in ordensCustosComUuid) {
            final currentCount = ordemCusto['sync_try_count'] as int? ?? 0;
            await db.update(
              'ordem_servico_custos',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [ordemCusto['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhuma ordem custo para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }*/

    // ===== 2. DOWNLOAD - completo (evita watermark pular custos novos) =====
    try {
      print('📥 Buscando todos os custos de OS (tenant)...');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/ordens-servico/custos/download'),
        headers: headers,
        body: json.encode(<String, dynamic>{
          'ultima_sync': null,
        }),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final ordensCustosDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${ordensCustosDoServidor.length} ordens');

        for (var ordemCustoServer in ordensCustosDoServidor) {
          await _processarOrdemCusto(
              ordemCustoServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (ordensCustosDoServidor.isNotEmpty) {
          await db.update(
            'ordem_servico_custos',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount ordens custos');
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
      'Sync ordens concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync ordens custos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync ordens custos: $e');
    _updateSyncStatus(false, 'Erro geral sync ordens custos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM CUSTOS =====

Future<void> _processarOrdemCusto(
    Map<String, dynamic> ordemCustoServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = ordemCustoServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (ordemCustoServer['id'] != null) {
    await _salvarMapeamento(
        'ordem_servico_custos', ordemCustoServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'ordem_servico_custos',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final row = <String, dynamic>{
    'ordem_servico_id': ordemCustoServer['ordem_servico_id'],
    'ordem_servico_uuid': ordemCustoServer['ordem_servico_uuid'] ?? '',
    'descricao': ordemCustoServer['descricao'],
    'origem': (ordemCustoServer['origem'] ?? 'avulso').toString(),
    'obra_item_id': ordemCustoServer['obra_item_id'],
    'obra_item_uuid': (ordemCustoServer['obra_item_uuid'] ?? '').toString(),
    'fixo': ordemCustoServer['fixo'] == true ||
            ordemCustoServer['fixo'] == 1 ||
            ordemCustoServer['fixo'] == '1'
        ? 1
        : 0,
    'unidade': ordemCustoServer['unidade'],
    'qtd_prevista': ordemCustoServer['qtd_prevista'],
    'valor_unitario': ordemCustoServer['valor_unitario'],
    'valor_total': ordemCustoServer['valor_total'],
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': ordemCustoServer['created_at'],
    'updated_at': ordemCustoServer['updated_at'],
  };
  if (ordemCustoServer['situacao'] != null) {
    row['situacao'] = ordemCustoServer['situacao'];
  }

  if (existe.isNotEmpty) {
    await db.update(
      'ordem_servico_custos',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    await db.insert(
      'ordem_servico_custos',
      {
        'uuid': uuid,
        ...row,
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

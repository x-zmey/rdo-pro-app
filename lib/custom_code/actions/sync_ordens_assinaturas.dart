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

String _nonEmptyStr(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  return s.isEmpty ? '' : s;
}

String _createdByLocal(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().isNotEmpty) return u.toString();
  final legacy = row['created_by'];
  if (legacy == null) return '0';
  final s = legacy.toString();
  return s.isEmpty ? '0' : s;
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncOrdensAssinaturas() async {
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
      final ordensAssinaturasNaoSincronizadas = await db.query(
        'ordem_servico_assinaturas',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (ordensAssinaturasNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA ORDENS SEM UUID
        for (var ordemAssinatura in ordensAssinaturasNaoSincronizadas) {
          if (ordemAssinatura['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'ordem_servico_assinaturas',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [ordemAssinatura['id']],
            );
            print(
                '✅ Gerado UUID para ordem assinatura: ${ordemAssinatura['id']} -> $newUuid');
          }
        }

        // BUSCAR ORDENS CUSTOS ATUALIZADAS
        final ordensCutosComUuid = await db.query(
          'ordens_servico_assinaturas',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final ordensAssinaturasParaEnviar =
            ordensAssinaturasComUuid.map((ordemAssinatura) {
          return {
            'uuid': ordemAssinatura['uuid'],
            'ordem_servico_id': ordemAssinatura['ordem_servico_id'],
            'assinante_id': ordemAssinatura['assinante_id'],
            'nivel': ordemAssinatura['nivel'],
            'created_by': ordemAssinatura['created_by'],
            'created_at': ordemAssinatura['created_at'],
            'updated_at': ordemAssinatura['updated_at'],
          };
        }).toList();

        print(
            '📤 Enviando ${ordensAssinaturasParaEnviar.length} ordens assinaturas...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              '$kApiBaseUrl/api/v1/sync/ordens/assinaturas-upload'),
          headers: headers,
          body: json.encode({'dados': ordensAssinaturasParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          // MARCAR ORDENS CUSTOS COMO SINCRONIZADAS
          for (var ordemAssinatura in uploadResult['sincronizados']) {
            await db.update(
              'ordem_servico_assinaturas',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [ordemAssinatura['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount ordens assinaturas');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var ordemAssinatura in ordensAssinaturasComUuid) {
            final currentCount = ordemAssinatura['sync_try_count'] as int? ?? 0;
            await db.update(
              'ordem_servico_assinaturas',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [ordemAssinatura['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhuma ordem assinatura para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }*/

    // ===== 2. DOWNLOAD - completo (evita watermark pular assinaturas novas) =====
    try {
      print('📥 Buscando todas as assinaturas de OS (tenant)...');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/ordens-servico/assinaturas/download'),
        headers: headers,
        body: json.encode(<String, dynamic>{
          'ultima_sync': null,
        }),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final ordensAssinaturasDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${ordensAssinaturasDoServidor.length} ordens');

        for (var ordemAssinaturaServer in ordensAssinaturasDoServidor) {
          await _processarOrdemAssinatura(
              ordemAssinaturaServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (ordensAssinaturasDoServidor.isNotEmpty) {
          await db.update(
            'ordem_servico_assinaturas',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount ordens assinaturas');
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
    print('🎉 Sync ordens assinaturas concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync ordens assinaturas: $e');
    _updateSyncStatus(false, 'Erro geral sync ordens assinaturas: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM CUSTOS =====

Future<void> _processarOrdemAssinatura(
    Map<String, dynamic> ordemAssinaturaServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = ordemAssinaturaServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (ordemAssinaturaServer['id'] != null) {
    await _salvarMapeamento(
        'ordem_servico_assinaturas', ordemAssinaturaServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'ordem_servico_assinaturas',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'ordem_servico_assinaturas',
      {
        'ordem_servico_id': ordemAssinaturaServer['ordem_servico_id'],
        'ordem_servico_uuid':
            _nonEmptyStr(ordemAssinaturaServer['ordem_servico_uuid']),
        'assinante_id': ordemAssinaturaServer['assinante_id'],
        'assinante_uuid': _nonEmptyStr(ordemAssinaturaServer['assinante_uuid']),
        'nivel': ordemAssinaturaServer['nivel'],
        'created_by': _createdByLocal(ordemAssinaturaServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': ordemAssinaturaServer['created_at'],
        'updated_at': ordemAssinaturaServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert(
      'ordem_servico_assinaturas',
      {
        'uuid': uuid,
        'ordem_servico_id': ordemAssinaturaServer['ordem_servico_id'],
        'ordem_servico_uuid':
            _nonEmptyStr(ordemAssinaturaServer['ordem_servico_uuid']),
        'assinante_id': ordemAssinaturaServer['assinante_id'],
        'assinante_uuid': _nonEmptyStr(ordemAssinaturaServer['assinante_uuid']),
        'nivel': ordemAssinaturaServer['nivel'],
        'created_by': _createdByLocal(ordemAssinaturaServer),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': ordemAssinaturaServer['created_at'],
        'updated_at': ordemAssinaturaServer['updated_at'],
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

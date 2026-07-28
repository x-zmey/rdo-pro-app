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
      print('❌ Erro ao salvar mapeamento obra_itens: $e');
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

String? _nullableStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  if (s.isEmpty) return null;
  return s;
}

num _asNum(dynamic v, [num defaultVal = 0]) {
  if (v == null) return defaultVal;
  if (v is num) return v;
  return num.tryParse(v.toString()) ?? defaultVal;
}

String _createdByLocal(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().isNotEmpty) return u.toString();
  final legacy = row['created_by'];
  if (legacy == null) return '0';
  final s = legacy.toString();
  return s.isEmpty ? '0' : s;
}

int? _serverId(Map<String, dynamic> row) {
  final v = row['id'];
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncObrasItens() async {
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

    int downloadedCount = 0;

    // ===== DOWNLOAD - Buscar atualizações do servidor =====
    try {
      final lastSync = await _getUltimaSync('obra_itens');
      print('📥 Buscando itens desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse('https://api.rdopro.com.br/api/v1/sync/obra-itens/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final itensDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${itensDoServidor.length} itens');

        for (var itemServer in itensDoServidor) {
          await _processarItem(itemServer, downloadResult['server_time']);
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (itensDoServidor.isNotEmpty) {
          await db.update(
            'obra_itens',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount itens');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(false, 'Token expirado. Faça login novamente.', 0, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
        print('❌ Body do erro: ${downloadResponse.body}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
      _updateSyncStatus(false, 'Erro no download: $e', 0, 0);
      return;
    }

    // ===== SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync itens concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync itens concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync itens: $e');
    _updateSyncStatus(false, 'Erro geral sync itens: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ITEM =====

Future<void> _processarItem(
    Map<String, dynamic> itemServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = itemServer['uuid'] ?? _generateUuid();

  final sid = _serverId(itemServer);
  if (sid != null) {
    await _salvarMapeamento('obra_itens', sid, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'obra_itens',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final qtd = _asNum(itemServer['qtd']).round();
  final qtdRealizada = _asNum(itemServer['qtd_realizada']).round();
  final porcentagem = _asNum(itemServer['porcentagem']);
  final valorUnitario = _asNum(itemServer['valor_unitario']).toDouble();

  final rowComum = <String, dynamic>{
    'obra_id': itemServer['obra_id'],
    'obra_uuid': _nullableStr(itemServer['obra_uuid']),
    'tipo': itemServer['tipo'],
    'cargo_funcao': _nullableStr(itemServer['cargo_funcao']),
    'id_orcamento_item': itemServer['id_orcamento_item'],
    'orcamento_item_uuid': _nullableStr(itemServer['orcamento_item_uuid']),
    'id_orcamento_item_pai': itemServer['id_orcamento_item_pai'],
    'orcamento_item_pai_uuid':
        _nullableStr(itemServer['orcamento_item_pai_uuid']),
    'descricao': itemServer['descricao'],
    'qtd': qtd,
    'unidade': itemServer['unidade'],
    'valor_unitario': valorUnitario,
    'qtd_realizada': qtdRealizada,
    'porcentagem': porcentagem,
    'situacao': itemServer['situacao'],
    'created_by': _createdByLocal(itemServer),
    'synced': 1,
    'last_sync_date': serverTime,
    'created_at': itemServer['created_at'],
    'updated_at': itemServer['updated_at'],
  };

  if (existe.isNotEmpty) {
    await db.update(
      'obra_itens',
      rowComum,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Item atualizado: ${itemServer['descricao']}');
  } else {
    await db.insert(
      'obra_itens',
      {
        'uuid': uuid,
        ...rowComum,
      },
    );
    print('✅ Novo item inserido: ${itemServer['descricao']}');
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

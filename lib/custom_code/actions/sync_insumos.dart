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
      print('❌ Erro ao salvar mapeamento insumos: $e');
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

String _nonEmptyStr(dynamic v) {
  if (v == null) return '';
  final s = v.toString();
  return s.isEmpty ? '' : s;
}

String? _nullableStr(dynamic v) {
  if (v == null) return null;
  final t = v.toString().trim();
  return t.isEmpty ? null : t;
}

dynamic _optDecimal(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

int? _optInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

String _createdByInsumo(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().trim().isNotEmpty) {
    return u.toString().trim();
  }
  final creator = FFAppState().creatorUuid.trim();
  if (creator.isNotEmpty) {
    return creator;
  }
  final legacy = row['created_by'];
  if (legacy == null) return '';
  return legacy.toString();
}

String _situacaoInsumo(dynamic v) {
  if (v == null) return 'ativo';
  if (v is int) {
    return v == 0 ? 'inativo' : 'ativo';
  }
  final s = v.toString().trim();
  if (s == 'ativo' || s == 'inativo') return s;
  return 'ativo';
}

Map<String, dynamic> _insumoRowFromServer(
    Map<String, dynamic> s, String serverTime) {
  final nome =
      _nonEmptyStr(s['nome']).isEmpty ? 'Insumo' : _nonEmptyStr(s['nome']);
  final um = _nonEmptyStr(s['unidade_medida']).isEmpty
      ? 'UN'
      : _nonEmptyStr(s['unidade_medida']);
  return {
    'codigo': _nullableStr(s['codigo']),
    'nome': nome,
    'descricao': _nullableStr(s['descricao']),
    'categoria': _nullableStr(s['categoria']),
    'unidade_medida': um,
    'preco_unitario': _optDecimal(s['preco_unitario']),
    'estoque_atual': _optDecimal(s['estoque_atual']) ?? 0,
    'estoque_minimo': _optDecimal(s['estoque_minimo']) ?? 0,
    'localizacao': _nullableStr(s['localizacao']),
    'fornecedor_id': _optInt(s['fornecedor_id']),
    'fornecedor_uuid': _nullableStr(s['fornecedor_uuid']),
    'observacoes': _nullableStr(s['observacoes']),
    'situacao': _situacaoInsumo(s['situacao']),
    'created_by': _createdByInsumo(s),
    'created_at': _nullableStr(s['created_at']),
    'updated_at': _nullableStr(s['updated_at']),
    'deleted_at': _nullableStr(s['deleted_at']),
    'synced': 1,
    'sync_try_count': 0,
    'last_sync_date': serverTime,
  };
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncInsumos() async {
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
      final lastSync = await _getUltimaSync('insumos');
      print('📥 Buscando insumos desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse('$kApiBaseUrl/api/v1/sync/insumos/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult =
            json.decode(downloadResponse.body) as Map<String, dynamic>;
        final rawDados = downloadResult['dados'];
        final insumosDoServidor = rawDados is List ? rawDados : <dynamic>[];
        final serverTime = downloadResult['server_time']?.toString() ??
            DateTime.now().toIso8601String();

        print('📥 Recebidas ${insumosDoServidor.length} insumos');

        for (var insumoServer in insumosDoServidor) {
          if (insumoServer is Map<String, dynamic>) {
            await _processarInsumo(insumoServer, serverTime);
            downloadedCount++;
          }
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (insumosDoServidor.isNotEmpty) {
          await db.update(
            'insumos',
            {'last_sync_date': serverTime},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount insumos');
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
      'Sync insumos concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync insumos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync insumos: $e');
    _updateSyncStatus(false, 'Erro geral sync insumos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE LOCAL =====

Future<void> _processarInsumo(
    Map<String, dynamic> insumoServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuidRaw = insumoServer['uuid'];
  final uuid = (uuidRaw != null && uuidRaw.toString().trim().isNotEmpty)
      ? uuidRaw.toString().trim()
      : _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (insumoServer['id'] != null) {
    final idInt = insumoServer['id'] is int
        ? insumoServer['id'] as int
        : int.tryParse(insumoServer['id'].toString());
    if (idInt != null) {
      await _salvarMapeamento('insumos', idInt, uuid);
    }
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'insumos',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final row = _insumoRowFromServer(insumoServer, serverTime);

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'insumos',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Insumo atualizado: ${row['nome']}');
  } else {
    // INSERT
    await db.insert(
      'insumos',
      {
        'uuid': uuid,
        ...row,
      },
    );
    print('✅ Novo insumo inserido: ${row['nome']}');
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
    return FFAppState().UserToken;
  } catch (e) {
    return '';
  }
}

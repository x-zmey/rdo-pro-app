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

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import '/backend/sqlite/situacao_soft_delete.dart';

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
      print('❌ Erro ao salvar mapeamento locais: $e');
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

String _createdByLocal(Map<String, dynamic> row) {
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

int _parseSituacao(dynamic v) {
  if (v == null) return kSituacaoAtivo;
  if (v is int) return v;
  return int.tryParse(v.toString()) ?? kSituacaoAtivo;
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncLocais() async {
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
      final lastSync = await _getUltimaSync('locais');
      print('📥 Buscando locais desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse('https://api.rdopro.com.br/api/v1/sync/locais/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult =
            json.decode(downloadResponse.body) as Map<String, dynamic>;
        final rawDados = downloadResult['dados'];
        final locaisDoServidor = rawDados is List ? rawDados : <dynamic>[];

        print('📥 Recebidas ${locaisDoServidor.length} locais');

        final serverTime = downloadResult['server_time']?.toString() ??
            DateTime.now().toIso8601String();

        for (var localServer in locaisDoServidor) {
          if (localServer is Map<String, dynamic>) {
            await _processarLocal(localServer, serverTime);
            downloadedCount++;
          }
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (locaisDoServidor.isNotEmpty) {
          await db.update(
            'locais',
            {'last_sync_date': serverTime},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount locais');
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
      'Sync locais concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync locais concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync locais: $e');
    _updateSyncStatus(false, 'Erro geral sync locais: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE LOCAL =====

Future<void> _processarLocal(
    Map<String, dynamic> localServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuidRaw = localServer['uuid'];
  String uuid = (uuidRaw != null && uuidRaw.toString().trim().isNotEmpty)
      ? uuidRaw.toString().trim()
      : _generateUuid();

  final nome = _nonEmptyStr(localServer['nome']).isEmpty
      ? 'Local'
      : _nonEmptyStr(localServer['nome']);

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  final idServidor = localServer['id'];
  if (idServidor != null) {
    final idInt =
        idServidor is int ? idServidor : int.tryParse(idServidor.toString());
    if (idInt != null) {
      await _salvarMapeamento('locais', idInt, uuid);
    }
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'locais',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final row = <String, dynamic>{
    'nome': nome,
    'created_by': _createdByLocal(localServer),
    'situacao': _parseSituacao(localServer['situacao']),
    'synced': 1,
    'sync_try_count': 0,
    'last_sync_date': serverTime,
    'created_at': localServer['created_at'],
    'updated_at': localServer['updated_at'],
  };

  if (existe.isNotEmpty) {
    await db.update(
      'locais',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Local atualizado: $nome');
  } else {
    await db.insert(
      'locais',
      {
        'uuid': uuid,
        ...row,
      },
    );
    print('✅ Novo local inserido: $nome');
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

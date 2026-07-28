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
import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import 'sync_tenant_headers.dart';

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
      print('❌ Erro ao salvar mapeamento users: $e');
    }
  }
}

Future<String> _getUltimaSync(String tabela) async {
  return lastSyncDateForUsersTable();
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

int? _optInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  return int.tryParse(v.toString());
}

String _createdByUser(Map<String, dynamic> row) {
  final u = row['created_by_uuid'];
  if (u != null && u.toString().trim().isNotEmpty) {
    return u.toString().trim();
  }
  final creator = FFAppState().creatorUuid.trim();
  if (creator.isNotEmpty) return creator;
  final legacy = row['created_by'];
  if (legacy == null) return '';
  return legacy.toString();
}

/// SQLite exige NOT NULL em email e type.
Map<String, dynamic> _userRowFromServer(
    Map<String, dynamic> s, String serverTime) {
  final nome =
      _nonEmptyStr(s['nome']).isEmpty ? 'Usuário' : _nonEmptyStr(s['nome']);
  final emailRaw = _nonEmptyStr(s['email']);
  final uuidKey = _nonEmptyStr(s['uuid']).replaceAll('-', '');
  final email = emailRaw.isEmpty
      ? 'sem-email-${uuidKey.isEmpty ? DateTime.now().millisecondsSinceEpoch.toString() : uuidKey}@sync.local'
      : emailRaw;
  final membershipType = _nonEmptyStr(s['membership_type']);
  final type = membershipType.isNotEmpty
      ? membershipType
      : (_nonEmptyStr(s['type']).isEmpty ? 'user' : _nonEmptyStr(s['type']));

  return {
    'nome': nome,
    'sobrenome': _nullableStr(s['sobrenome']),
    'juridica': _optInt(s['juridica']),
    'documento': _nullableStr(s['documento']),
    'razao_social': _nullableStr(s['razao_social']),
    'telefone': _nullableStr(s['telefone']),
    'whatsapp': _nullableStr(s['whatsapp']),
    'email': email,
    'created_by': _createdByUser(s),
    'type': type,
    'cargo': _nullableStr(s['cargo']),
    'registro_profissional': _nullableStr(s['registro_profissional']),
    'obra_travada': _optInt(s['obra_travada']) ?? 0,
    'situacao': _optInt(s['situacao']) ?? kSituacaoAtivo,
    'created_at': _nullableStr(s['created_at']),
    'updated_at': _nullableStr(s['updated_at']),
    'synced': 1,
    'sync_try_count': 0,
    'last_sync_date': serverTime,
  };
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncUsers() async {
  try {
    final db = await SQLiteManager.instance.database;
    final token = await _getAuthToken();

    if (token.isEmpty) {
      _updateSyncStatus(false, 'Usuário não autenticado', 0, 0);
      return;
    }

    final headers = syncAuthHeaders();

    int downloadedCount = 0;
    final tenantId = FFAppState().activeTenantUserId;
    if (tenantId > 0) {
      try {
        await db.delete(
          'empresa_users',
          where: 'tenant_user_id != ?',
          whereArgs: [tenantId],
        );
      } catch (e) {
        print('⚠️ Limpeza cache multi-tenant: $e');
      }
    }

    try {
      final lastSync = await _getUltimaSync('users');
      print('📥 Buscando users desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse('https://api.rdopro.com.br/api/v1/sync/users/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult =
            json.decode(downloadResponse.body) as Map<String, dynamic>;
        final rawDados = downloadResult['dados'];
        final usersDoServidor = rawDados is List ? rawDados : <dynamic>[];
        final serverTime = downloadResult['server_time']?.toString() ??
            DateTime.now().toIso8601String();

        print('📥 Recebidas ${usersDoServidor.length} users');

        for (var userServer in usersDoServidor) {
          if (userServer is Map<String, dynamic>) {
            await _processarUser(userServer, serverTime);
            downloadedCount++;
          }
        }

        if (usersDoServidor.isNotEmpty) {
          await db.update(
            'users',
            {'last_sync_date': serverTime},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount users');
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

    _updateSyncStatus(
      true,
      'Sync users concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync users concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync users: $e');
    _updateSyncStatus(false, 'Erro geral sync users: $e', 0, 0);
  }
}

Future<void> _processarUser(
    Map<String, dynamic> userServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuidRaw = userServer['uuid'];
  final uuid = (uuidRaw != null && uuidRaw.toString().trim().isNotEmpty)
      ? uuidRaw.toString().trim()
      : _generateUuid();

  if (userServer['id'] != null) {
    final idInt = userServer['id'] is int
        ? userServer['id'] as int
        : int.tryParse(userServer['id'].toString());
    if (idInt != null) {
      await _salvarMapeamento('users', idInt, uuid);
    }
  }

  final row = _userRowFromServer(userServer, serverTime);
  final idServer = userServer['id'];
  final idServerInt =
      idServer is int ? idServer : int.tryParse(idServer?.toString() ?? '');

  final existe = await db.query(
    'users',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    await db.update(
      'users',
      {
        ...row,
        if (idServerInt != null) 'id_server': idServerInt,
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 User atualizado: ${row['nome']}');
  } else {
    await db.insert(
      'users',
      {
        'uuid': uuid,
        ...row,
        if (idServerInt != null) 'id_server': idServerInt,
      },
    );
    print('✅ Novo user inserido: ${row['nome']}');
  }

  if (userServer['empresa_user_id'] != null ||
      userServer['tenant_user_id'] != null) {
    await upsertEmpresaUserFromServer(db, userServer, serverTime);
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

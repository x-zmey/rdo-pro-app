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
      print('❌ Erro ao salvar mapeamento clientes: $e');
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
  if (u != null && u.toString().trim().isNotEmpty) return u.toString().trim();
  final creator = FFAppState().creatorUuid.trim();
  if (creator.isNotEmpty) return creator;
  final legacy = row['created_by'];
  if (legacy == null) return '';
  final s = legacy.toString();
  return s;
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncClientes() async {
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
      final lastSync = await _getUltimaSync('clientes');
      print('📥 Buscando clientes desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/obras/clientes/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult =
            json.decode(downloadResponse.body) as Map<String, dynamic>;
        final rawDados = downloadResult['dados'];
        final clientesDoServidor = rawDados is List ? rawDados : <dynamic>[];
        final serverTime = downloadResult['server_time']?.toString() ??
            DateTime.now().toIso8601String();

        print('📥 Recebidas ${clientesDoServidor.length} clientes');

        for (var clienteServer in clientesDoServidor) {
          if (clienteServer is Map<String, dynamic>) {
            await _processarCliente(clienteServer, serverTime);
            downloadedCount++;
          }
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (clientesDoServidor.isNotEmpty) {
          await db.update(
            'clientes',
            {'last_sync_date': serverTime},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount clientes');
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
      'Sync clientes concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync clientes concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync clientes: $e');
    _updateSyncStatus(false, 'Erro geral sync clientes: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE CLIENTE =====

Future<void> _processarCliente(
    Map<String, dynamic> clienteServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = clienteServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (clienteServer['id'] != null) {
    final idInt = clienteServer['id'] is int
        ? clienteServer['id'] as int
        : int.tryParse(clienteServer['id'].toString());
    if (idInt != null) {
      await _salvarMapeamento('clientes', idInt, uuid);
    }
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'clientes',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'clientes',
      {
        'user_id': clienteServer['user_id'],
        'user_uuid': _nonEmptyStr(clienteServer['user_uuid']),
        'juridica': clienteServer['juridica'],
        'documento': clienteServer['documento'],
        'nome': clienteServer['nome'],
        'sexo': clienteServer['sexo'],
        'telefone': clienteServer['telefone'],
        'email': clienteServer['email'],
        'rua': clienteServer['rua'],
        'numero': clienteServer['numero'],
        'complemento': clienteServer['complemento'],
        'bairro': clienteServer['bairro'],
        'cidade': clienteServer['cidade'],
        'estado': clienteServer['estado'],
        'observacoes': clienteServer['observacoes'],
        'created_by': _createdByLocal(clienteServer),
        'situacao': clienteServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': clienteServer['created_at'],
        'updated_at': clienteServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Cliente atualizado: ${clienteServer['nome']}');
  } else {
    // INSERT
    await db.insert(
      'clientes',
      {
        'uuid': uuid,
        'user_id': clienteServer['user_id'],
        'user_uuid': _nonEmptyStr(clienteServer['user_uuid']),
        'juridica': clienteServer['juridica'],
        'documento': clienteServer['documento'],
        'nome': clienteServer['nome'],
        'sexo': clienteServer['sexo'],
        'telefone': clienteServer['telefone'],
        'email': clienteServer['email'],
        'rua': clienteServer['rua'],
        'numero': clienteServer['numero'],
        'complemento': clienteServer['complemento'],
        'bairro': clienteServer['bairro'],
        'cidade': clienteServer['cidade'],
        'estado': clienteServer['estado'],
        'observacoes': clienteServer['observacoes'],
        'created_by': _createdByLocal(clienteServer),
        'situacao': clienteServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': clienteServer['created_at'],
        'updated_at': clienteServer['updated_at'],
      },
    );
    print('✅ Novo cliente inserido: ${clienteServer['nome']}');
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

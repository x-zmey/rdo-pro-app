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
      print('❌ Erro ao salvar mapeamento maoObras: $e');
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

String _createdByMaoObra(Map<String, dynamic> row) {
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

String _situacaoMaoObra(dynamic v) {
  if (v == null) return 'ativo';
  final s = v.toString().trim();
  const ok = {'ativo', 'inativo', 'ferias', 'afastado'};
  if (ok.contains(s)) return s;
  if (v is int) return v == 0 ? 'inativo' : 'ativo';
  return 'ativo';
}

Map<String, dynamic> _maoObraRowFromServer(
    Map<String, dynamic> s, String serverTime) {
  final nome = _nonEmptyStr(s['nome_completo']).isEmpty
      ? (_nonEmptyStr(s['nome']).isEmpty
          ? 'Profissional'
          : _nonEmptyStr(s['nome']))
      : _nonEmptyStr(s['nome_completo']);
  final cargo = _nonEmptyStr(s['cargo_funcao']).isEmpty
      ? 'Profissional'
      : _nonEmptyStr(s['cargo_funcao']);

  return {
    'nome_completo': nome,
    'cpf': _nullableStr(s['cpf']),
    'rg': _nullableStr(s['rg']),
    'telefone': _nullableStr(s['telefone']),
    'email': _nullableStr(s['email']),
    'cargo_funcao': cargo,
    'valor_hora': _optDecimal(s['valor_hora']),
    'valor_diaria': _optDecimal(s['valor_diaria']),
    'data_admissao': _nullableStr(s['data_admissao']),
    'situacao': _situacaoMaoObra(s['situacao']),
    'observacoes': _nullableStr(s['observacoes']),
    'created_by': _createdByMaoObra(s),
    'created_at': _nullableStr(s['created_at']),
    'updated_at': _nullableStr(s['updated_at']),
    'deleted_at': _nullableStr(s['deleted_at']),
    'synced': 1,
    'sync_try_count': 0,
    'last_sync_date': serverTime,
  };
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncMaoObra() async {
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
      final lastSync = await _getUltimaSync('mao_obra_profissionais');
      print('📥 Buscando mão de obra desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse('https://api.rdopro.com.br/api/v1/sync/mao-obras/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult =
            json.decode(downloadResponse.body) as Map<String, dynamic>;
        final rawDados = downloadResult['dados'];
        final maoObrasDoServidor = rawDados is List ? rawDados : <dynamic>[];
        final serverTime = downloadResult['server_time']?.toString() ??
            DateTime.now().toIso8601String();

        print('📥 Recebidas ${maoObrasDoServidor.length} profissionais');

        for (var maoObraServer in maoObrasDoServidor) {
          if (maoObraServer is Map<String, dynamic>) {
            await _processarMaoObra(maoObraServer, serverTime);
            downloadedCount++;
          }
        }

        // ATUALIZAR LAST_SYNC_DATE APENAS PARA REGISTROS SINCRONIZADOS
        if (maoObrasDoServidor.isNotEmpty) {
          await db.update(
            'mao_obra_profissionais',
            {'last_sync_date': serverTime},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount profissionais');
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
      'Sync mão de obra concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync mão de obra concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync mão de obra: $e');
    _updateSyncStatus(false, 'Erro geral sync mão de obra: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE LOCAL =====

Future<void> _processarMaoObra(
    Map<String, dynamic> maoObraServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  final uuidRaw = maoObraServer['uuid'];
  final uuid = (uuidRaw != null && uuidRaw.toString().trim().isNotEmpty)
      ? uuidRaw.toString().trim()
      : _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (maoObraServer['id'] != null) {
    final idInt = maoObraServer['id'] is int
        ? maoObraServer['id'] as int
        : int.tryParse(maoObraServer['id'].toString());
    if (idInt != null) {
      await _salvarMapeamento('mao_obra_profissionais', idInt, uuid);
    }
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'mao_obra_profissionais',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final row = _maoObraRowFromServer(maoObraServer, serverTime);

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'mao_obra_profissionais',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Profissional atualizado: ${row['nome_completo']}');
  } else {
    // INSERT
    await db.insert(
      'mao_obra_profissionais',
      {
        'uuid': uuid,
        ...row,
      },
    );
    print('✅ Novo profissional inserido: ${row['nome_completo']}');
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

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
      print('❌ Erro ao salvar mapeamento equipamentos: $e');
    }
  }
}

/// Incremental sync: SQLite não tem last_sync_date nesta tabela — usa updated_at.
Future<String> _getUltimaSyncEquipamentos() async {
  return updatedAtWatermarkForCurrentCreator('equipamentos');
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

dynamic _optDecimal(dynamic v) {
  if (v == null) return null;
  if (v is num) return v;
  return num.tryParse(v.toString());
}

String _createdByEquipamento(Map<String, dynamic> row) {
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

/// CHECK no SQLite: disponivel | em_uso | manutencao | inativo
String _situacaoEquipamento(dynamic v) {
  if (v == null) return 'disponivel';
  if (v is int) {
    switch (v) {
      case 0:
        return 'inativo';
      case 1:
        return 'disponivel';
      case 2:
        return 'em_uso';
      case 3:
        return 'manutencao';
      default:
        return 'disponivel';
    }
  }
  final s = v.toString().trim();
  const ok = {'disponivel', 'em_uso', 'manutencao', 'inativo'};
  if (ok.contains(s)) return s;
  return 'disponivel';
}

Map<String, dynamic> _equipamentoRowFromServer(Map<String, dynamic> s) {
  final nome =
      _nonEmptyStr(s['nome']).isEmpty ? 'Equipamento' : _nonEmptyStr(s['nome']);
  final um = _nonEmptyStr(s['unidade_medida']).isEmpty
      ? 'UN'
      : _nonEmptyStr(s['unidade_medida']);

  return {
    'codigo': _nullableStr(s['codigo']),
    'nome': nome,
    'descricao': _nullableStr(s['descricao']),
    'categoria': _nullableStr(s['categoria']),
    'unidade_medida': um,
    'valor_hora': _optDecimal(s['valor_hora']),
    'valor_diaria': _optDecimal(s['valor_diaria']),
    'valor_mensal': _optDecimal(s['valor_mensal']),
    'placa_identificacao': _nullableStr(s['placa_identificacao']),
    'numero_serie': _nullableStr(s['numero_serie']),
    'marca': _nullableStr(s['marca']),
    'modelo': _nullableStr(s['modelo']),
    'ano_fabricacao': _optInt(s['ano_fabricacao']),
    'data_aquisicao': _nullableStr(s['data_aquisicao']),
    'vida_util': _optInt(s['vida_util']),
    'localizacao': _nullableStr(s['localizacao']),
    'situacao': _situacaoEquipamento(s['situacao']),
    'observacoes': _nullableStr(s['observacoes']),
    'created_by': _createdByEquipamento(s),
    'created_at': _nullableStr(s['created_at']),
    'updated_at': _nullableStr(s['updated_at']),
    'deleted_at': _nullableStr(s['deleted_at']),
  };
}

// ===== FUNÇÃO PRINCIPAL - APENAS DOWNLOAD =====

Future syncEquipamentos() async {
  try {
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

    try {
      final lastSync = await _getUltimaSyncEquipamentos();
      print('📥 Buscando equipamentos desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/equipamentos/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult =
            json.decode(downloadResponse.body) as Map<String, dynamic>;
        final rawDados = downloadResult['dados'];
        final equipamentosDoServidor =
            rawDados is List ? rawDados : <dynamic>[];

        print('📥 Recebidas ${equipamentosDoServidor.length} equipamentos');

        for (var equipamentoServer in equipamentosDoServidor) {
          if (equipamentoServer is Map<String, dynamic>) {
            await _processarEquipamento(equipamentoServer);
            downloadedCount++;
          }
        }

        print('✅ Download concluído: $downloadedCount equipamentos');
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
      'Sync equipamentos concluída: ↓$downloadedCount',
      0,
      downloadedCount,
    );
    print('🎉 Sync equipamentos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync equipamentos: $e');
    _updateSyncStatus(false, 'Erro geral sync equipamentos: $e', 0, 0);
  }
}

Future<void> _processarEquipamento(
    Map<String, dynamic> equipamentoServer) async {
  final db = await SQLiteManager.instance.database;

  final uuidRaw = equipamentoServer['uuid'];
  final uuid = (uuidRaw != null && uuidRaw.toString().trim().isNotEmpty)
      ? uuidRaw.toString().trim()
      : _generateUuid();

  final idServidor = equipamentoServer['id'];
  if (idServidor != null) {
    final idInt =
        idServidor is int ? idServidor : int.tryParse(idServidor.toString());
    if (idInt != null) {
      await _salvarMapeamento('equipamentos', idInt, uuid);
    }
  }

  final row = _equipamentoRowFromServer(equipamentoServer);

  final existe = await db.query(
    'equipamentos',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    await db.update(
      'equipamentos',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Equipamento atualizado: ${row['nome']}');
  } else {
    await db.insert(
      'equipamentos',
      {
        'uuid': uuid,
        ...row,
      },
    );
    print('✅ Novo equipamento inserido: ${row['nome']}');
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

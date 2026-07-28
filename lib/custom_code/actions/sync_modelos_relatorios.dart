// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'sync_last_sync_for_creator.dart';

// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

// ===== FUNÇÕES UTILITÁRIAS =====

Future<bool> _tabelaTemColuna(Database db, String tabela, String coluna) async {
  final rows = await db.rawQuery('PRAGMA table_info($tabela)');
  for (final r in rows) {
    if (r['name'] == coluna) {
      return true;
    }
  }
  return false;
}

String? _strOuNullVazio(dynamic v) {
  if (v == null) {
    return null;
  }
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

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
      print('❌ Erro ao salvar mapeamento modelo_relatorios: $e');
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

// ===== FUNÇÃO PRINCIPAL - UPLOAD + DOWNLOAD =====

Future syncModelosRelatorios() async {
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
      final modelosNaoSincronizados = await db.query(
        'modelo_relatorios',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (modelosNaoSincronizados.isNotEmpty) {
        // GERAR UUIDs PARA MODELOS SEM UUID
        for (var modelo in modelosNaoSincronizados) {
          if (modelo['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'modelo_relatorios',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [modelo['id']],
            );
            print('✅ Gerado UUID para modelo: ${modelo['nome']} -> $newUuid');
          }
        }

        // BUSCAR MODELOS ATUALIZADOS
        final modelosComUuid = await db.query(
          'modelo_relatorios',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final modelosParaEnviar = modelosComUuid.map((modelo) {
          return {
            'uuid': modelo['uuid'],
            'user_id': modelo['user_id'],
            'obra_id': modelo['obra_id'],
            'nome': modelo['nome'],
            'tipo_data': modelo['tipo_data'],
            'horario_trabalho': modelo['horario_trabalho'],
            'condicao_climatica': modelo['condicao_climatica'],
            'mao_obra': modelo['mao_obra'],
            'equipamentos': modelo['equipamentos'],
            'atividades': modelo['atividades'],
            'ocorrencias': modelo['ocorrencias'],
            'controle_materiais': modelo['controle_materiais'],
            'comentario': modelo['comentario'],
            'foto': modelo['foto'],
            'video': modelo['video'],
            'anexo': modelo['anexo'],
            'assinatura': modelo['assinatura'],
            'assinatura_todas_paginas': modelo['assinatura_todas_paginas'],
            'created_by': modelo['created_by'],
            'situacao': modelo['situacao'],
            'created_at': modelo['created_at'],
            'updated_at': modelo['updated_at'],
          };
        }).toList();

        print('📤 Enviando ${modelosParaEnviar.length} modelos...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse(
              'https://api.rdopro.com.br/api/v1/sync/modelos-relatorios/upload'),
          headers: headers,
          body: json.encode({'dados': modelosParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          // MARCAR MODELOS COMO SINCRONIZADOS
          for (var modelo in uploadResult['sincronizados']) {
            await db.update(
              'modelo_relatorios',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [modelo['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount modelos');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var modelo in modelosComUuid) {
            final currentCount = modelo['sync_try_count'] as int? ?? 0;
            await db.update(
              'modelo_relatorios',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [modelo['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhum modelo para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }*/

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('modelo_relatorios');
      print('📥 Buscando modelos desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/modelos-relatorios/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      print('last sinc ${lastSync}');

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final modelosDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${modelosDoServidor.length} modelos');

        final hasLogomarcaFotos = await _tabelaTemColuna(
          db,
          'modelo_relatorios',
          'logomarca_fotos',
        );
        for (var modeloServer in modelosDoServidor) {
          await _processarModeloRelatorio(
            modeloServer,
            downloadResult['server_time'],
            hasLogomarcaFotos: hasLogomarcaFotos,
          );
          downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE
        if (modelosDoServidor.isNotEmpty) {
          await db.update(
            'modelo_relatorios',
            {'last_sync_date': downloadResult['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download concluído: $downloadedCount modelos');
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
      'Sync modelos concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync modelos concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync modelos: $e');
    _updateSyncStatus(false, 'Erro geral sync modelos: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE MODELO RELATÓRIO =====

Future<void> _processarModeloRelatorio(
  Map<String, dynamic> modeloServer,
  String serverTime, {
  bool hasLogomarcaFotos = false,
}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = modeloServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (modeloServer['id'] != null) {
    await _salvarMapeamento(
        'modelo_relatorios', modeloServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'modelo_relatorios',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final logomarcaFotos =
      hasLogomarcaFotos ? _strOuNullVazio(modeloServer['logomarca_fotos']) : null;

  if (existe.isNotEmpty) {
    // UPDATE
    final row = <String, Object?>{
      'uuid_pai': modeloServer['uuid_pai'],
      'user_id': modeloServer['user_id'],
      'user_uuid': _nonEmptyStr(modeloServer['user_uuid']),
      'obra_id': modeloServer['obra_id'],
      'obra_uuid': _nonEmptyStr(modeloServer['obra_uuid']),
      'nome': modeloServer['nome'],
      'tipo_data': modeloServer['tipo_data'],
      'horario_trabalho': modeloServer['horario_trabalho'],
      'condicao_climatica': modeloServer['condicao_climatica'],
      'mao_obra': modeloServer['mao_obra'],
      'equipamentos': modeloServer['equipamentos'],
      'atividades': modeloServer['atividades'],
      'ocorrencias': modeloServer['ocorrencias'],
      'controle_materiais': modeloServer['controle_materiais'],
      'comentario': modeloServer['comentario'],
      'foto': modeloServer['foto'],
      'video': modeloServer['video'],
      'anexo': modeloServer['anexo'],
      'assinatura': modeloServer['assinatura'],
      'assinatura_todas_paginas': modeloServer['assinatura_todas_paginas'],
      'created_by': _createdByLocal(modeloServer),
      'situacao': modeloServer['situacao'],
      'synced': 1,
      'last_sync_date': serverTime,
      'created_at': modeloServer['created_at'],
      'updated_at': modeloServer['updated_at'],
    };
    if (hasLogomarcaFotos) {
      row['logomarca_fotos'] = logomarcaFotos;
    }
    await db.update(
      'modelo_relatorios',
      row,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    print('🔄 Modelo atualizado: ${modeloServer['nome']}');
  } else {
    // INSERT
    final ins = <String, Object?>{
      'uuid_pai': modeloServer['uuid_pai'],
      'uuid': uuid,
      'user_id': modeloServer['user_id'],
      'user_uuid': _nonEmptyStr(modeloServer['user_uuid']),
      'obra_id': modeloServer['obra_id'],
      'obra_uuid': _nonEmptyStr(modeloServer['obra_uuid']),
      'nome': modeloServer['nome'],
      'tipo_data': modeloServer['tipo_data'],
      'horario_trabalho': modeloServer['horario_trabalho'],
      'condicao_climatica': modeloServer['condicao_climatica'],
      'mao_obra': modeloServer['mao_obra'],
      'equipamentos': modeloServer['equipamentos'],
      'atividades': modeloServer['atividades'],
      'ocorrencias': modeloServer['ocorrencias'],
      'controle_materiais': modeloServer['controle_materiais'],
      'comentario': modeloServer['comentario'],
      'foto': modeloServer['foto'],
      'video': modeloServer['video'],
      'anexo': modeloServer['anexo'],
      'assinatura': modeloServer['assinatura'],
      'assinatura_todas_paginas': modeloServer['assinatura_todas_paginas'],
      'created_by': _createdByLocal(modeloServer),
      'situacao': modeloServer['situacao'],
      'synced': 1,
      'last_sync_date': serverTime,
      'created_at': modeloServer['created_at'],
      'updated_at': modeloServer['updated_at'],
    };
    if (hasLogomarcaFotos) {
      ins['logomarca_fotos'] = logomarcaFotos;
    }
    await db.insert('modelo_relatorios', ins);
    print('✅ Novo modelo inserido: ${modeloServer['nome']}');
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

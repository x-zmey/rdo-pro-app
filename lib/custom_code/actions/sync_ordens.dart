// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';

// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/backend/api_requests/api_config.dart';

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
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

/// Preenche `obra_uuid` quando o sync antigo gravou só `obra_id` (server).
Future<int> _backfillObraUuidLocal(Database db) async {
  var total = 0;
  try {
    total += await db.rawUpdate('''
UPDATE ordens_servico
SET obra_uuid = (
  SELECT m.uuid FROM sync_id_mapping AS m
  WHERE m.tabela = 'obras' AND m.id_servidor = ordens_servico.obra_id
  LIMIT 1
)
WHERE (obra_uuid IS NULL OR TRIM(obra_uuid) = '')
  AND obra_id IS NOT NULL
''');
  } catch (_) {}
  try {
    total += await db.rawUpdate('''
UPDATE ordens_servico
SET obra_uuid = (
  SELECT o.uuid FROM obras AS o
  WHERE o.id = ordens_servico.obra_id
  LIMIT 1
)
WHERE (obra_uuid IS NULL OR TRIM(obra_uuid) = '')
  AND obra_id IS NOT NULL
''');
  } catch (_) {}
  if (total > 0) {
    print('🔧 Backfill obra_uuid em $total ordens_servico');
  }
  return total;
}

Future<int?> _serverIdObraPorUuid(String obraUuid) async {
  final db = await SQLiteManager.instance.database;
  final maps = await db.query(
    'sync_id_mapping',
    columns: ['id_servidor'],
    where: 'tabela = ? AND uuid = ?',
    whereArgs: ['obras', obraUuid],
    limit: 1,
  );
  if (maps.isEmpty) return null;
  final v = maps.first['id_servidor'];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '');
}

List<Map<String, dynamic>> _extractOrdensList(dynamic body) {
  if (body is List) {
    return body
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (body is Map) {
    final ordens = body['ordens'];
    if (ordens is Map && ordens['data'] is List) {
      return (ordens['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (ordens is List) {
      return ordens
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    for (final key in ['dados', 'data', 'value']) {
      final c = body[key];
      if (c is List) {
        return c
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    }
  }
  return <Map<String, dynamic>>[];
}

int _totalPagesOrdens(dynamic body) {
  if (body is! Map) return 1;
  final tp = body['totalPages'];
  if (tp is int) return tp < 1 ? 1 : tp;
  if (tp is num) return tp.toInt().clamp(1, 9999);
  final ordens = body['ordens'];
  if (ordens is Map) {
    final lp = ordens['last_page'];
    if (lp is int) return lp < 1 ? 1 : lp;
    if (lp is num) return lp.toInt().clamp(1, 9999);
  }
  return 1;
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

String _generateUuid() {
  final random = Random();
  final hexDigits = '0123456789abcdef';
  String generatePart(int length) {
    return List.generate(length, (index) => hexDigits[random.nextInt(16)])
        .join();
  }

  return '${generatePart(8)}-${generatePart(4)}-4${generatePart(3)}-${generatePart(4)}-${generatePart(12)}';
}

String? _nonEmptyStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

String _createdByLocal(Map<String, dynamic> row) {
  // Em `nova.sql`, `created_by` é TEXT (uuid).
  return _nonEmptyStr(row['created_by_uuid']) ??
      _nonEmptyStr(row['created_by']) ??
      '';
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncOrdens() async {
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
    bool hadError = false;

    // ===== 1. UPLOAD - Enviar dados locais =====
    /*try {
      final ordensNaoSincronizadas = await db.query(
        'ordens_servico',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (ordensNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA ORDENS SEM UUID
        for (var ordem in ordensNaoSincronizadas) {
          if (ordem['uuid'] == null) {
            final newUuid = _generateUuid();
            await db.update(
              'ordens_servico',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [ordem['id']],
            );
            print('✅ Gerado UUID para ordem: ${ordem['nome']} -> $newUuid');
          }
        }

        // BUSCAR ORDENS ATUALIZADAS
        final ordensComUuid = await db.query(
          'ordens_servico',
          where: 'synced = ?',
          whereArgs: [0],
        );

        // PREPARAR DADOS PARA ENVIO
        final ordensParaEnviar = ordensComUuid.map((ordem) {
          return {
            'uuid': ordem['uuid'],
            'obra_id': ordem['obra_id'],
            'user_id': ordem['user_id'],
            'codigo': ordem['codigo'],
            'nome': ordem['nome'],
            'data_emissao': ordem['data_emissao'],
            'data_inicio': ordem['data_inicio'],
            'data_final': ordem['data_final'],
            'situacao': ordem['situacao'],
            'observacoes': ordem['observacoes'],
            'created_by': ordem['created_by'],
            'created_at': ordem['created_at'],
            'updated_at': ordem['updated_at'],
          };
        }).toList();

        print('📤 Enviando ${ordensParaEnviar.length} ordens...');

        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse('$kApiBaseUrl/api/v1/sync/ordens/upload'),
          headers: headers,
          body: json.encode({'dados': ordensParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadResult = json.decode(uploadResponse.body);

          // MARCAR ORDENS COMO SINCRONIZADAS
          for (var ordem in uploadResult['sincronizados']) {
            await db.update(
              'ordens_servico',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [ordem['uuid']],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount ordens');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var ordem in ordensComUuid) {
            final currentCount = ordem['sync_try_count'] as int? ?? 0;
            await db.update(
              'ordens_servico',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [ordem['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        print('ℹ️ Nenhuma ordem para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }*/

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    //
    // Download **completo** (sem `ultima_sync`): o incremental por `updated_at` no
    // servidor deixava `status_id` no SQLite diferente do endpoint `/show` quando o
    // watermark local ficava “à frente”, havia skew de relógio ou o status mudou
    // sem refletir na janela incremental.
    try {
      await _backfillObraUuidLocal(db);
      print('📥 Buscando todas as ordens de serviço (tenant)...');

      final downloadResponse = await http.post(
        Uri.parse(
            '$kApiBaseUrl/api/v1/sync/ordens-servico/download'),
        headers: headers,
        body: json.encode(<String, dynamic>{
          'ultima_sync': null,
        }),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final ordensDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${ordensDoServidor.length} ordens');

        for (var ordemServer in ordensDoServidor) {
          await _processarOrdem(
            Map<String, dynamic>.from(ordemServer as Map),
            downloadResult['server_time']?.toString() ??
                DateTime.now().toUtc().toIso8601String(),
          );
          downloadedCount++;
        }

        await _backfillObraUuidLocal(db);

        // ATUALIZAR LAST_SYNC_DATE (resposta OK: mesmo lista vazia confirma estado no servidor)
        await db.update(
          'ordens_servico',
          {'last_sync_date': downloadResult['server_time']},
          where: 'synced = ?',
          whereArgs: [1],
        );
        print('✅ Download concluído: $downloadedCount ordens');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print('❌ Erro no download: ${downloadResponse.statusCode}');
      }
    } catch (e) {
      hadError = true;
      print('❌ Erro no download: $e');
    }

    if (hadError) {
      throw Exception('Falha parcial no sync de ordens_servico');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync ordenss concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync ordens concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync ordens: $e');
    _updateSyncStatus(false, 'Erro geral sync ordens: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM =====

Future<void> _processarOrdem(
  Map<String, dynamic> ordemServer,
  String serverTime, {
  String? forceObraUuid,
  bool touchLastSync = true,
}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = ordemServer['uuid']?.toString() ?? _generateUuid();
  if (uuid.trim().isEmpty || uuid.toLowerCase() == 'null') {
    uuid = _generateUuid();
  }

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  final sid = ordemServer['id'];
  final sidInt = sid is int
      ? sid
      : (sid is num ? sid.toInt() : int.tryParse(sid?.toString() ?? ''));
  if (sidInt != null) {
    await _salvarMapeamento('ordens_servico', sidInt, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'ordens_servico',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  final obraUuid = _nonEmptyStr(forceObraUuid) ??
      _nonEmptyStr(ordemServer['obra_uuid']) ??
      (ordemServer['obra'] is Map
          ? _nonEmptyStr((ordemServer['obra'] as Map)['uuid'])
          : null);

  final rowComum = <String, dynamic>{
    'obra_uuid': obraUuid,
    'user_uuid': _nonEmptyStr(ordemServer['user_uuid']),
    'obra_id': ordemServer['obra_id'],
    'user_id': ordemServer['user_id'],
    'codigo': ordemServer['codigo'],
    'nome': ordemServer['nome'],
    'data_emissao': ordemServer['data_emissao'],
    'data_inicio': ordemServer['data_inicio'],
    // No SQLite (`nova.sql`) o campo é `data_fim`.
    // Mantemos fallback para `data_final` caso o payload venha legado.
    'data_fim': (ordemServer['data_fim'] ?? ordemServer['data_final']),
    'situacao': ordemServer['situacao'],
    'status_id': int.tryParse('${ordemServer['status_id'] ?? 1}') ?? 1,
    'observacoes': ordemServer['observacoes'],
    'created_by': _createdByLocal(ordemServer),
    'synced': 1,
    'created_at': ordemServer['created_at'],
    'updated_at': ordemServer['updated_at'],
  };
  if (touchLastSync) {
    rowComum['last_sync_date'] = serverTime;
  }

  if (existe.isNotEmpty) {
    await db.update(
      'ordens_servico',
      rowComum,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    await db.insert(
      'ordens_servico',
      {
        'uuid': uuid,
        ...rowComum,
        if (!touchLastSync) 'last_sync_date': serverTime,
      },
    );
  }
}

/// Baixa `/obras/{uuid}/list-ordens` e grava no SQLite (mesma fonte da lista web).
/// Usado ao abrir pickers de OS no RDO / tela da obra.
Future<void> refreshOrdensPorObra({required String obraUuid}) async {
  final uuid = obraUuid.trim();
  if (uuid.isEmpty) return;

  final token = await _getAuthToken();
  if (token.isEmpty) return;

  final online = await checkInternetConnection();
  if (!online) return;

  try {
    final db = await SQLiteManager.instance.database;
    await _backfillObraUuidLocal(db);

    // Preferimos UUID (backend resolve); se falhar, tenta id servidor local.
    final identificadores = <String>[uuid];
    final sid = await _serverIdObraPorUuid(uuid);
    if (sid != null && sid > 0) {
      identificadores.add('$sid');
    }

    var total = 0;
    var ok = false;
    for (final ident in identificadores) {
      var page = 1;
      var lastPage = 1;
      var gotAny = false;
      while (page <= lastPage && page <= 50) {
        final response = await http.get(
          Uri.parse(
            '$kApiBaseUrl/api/obras/$ident/list-ordens?itemsPerPage=200&page=$page',
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          if (page == 1) break;
          print(
              '⚠️ refreshOrdensPorObra HTTP ${response.statusCode}: ${response.body}');
          break;
        }
        ok = true;
        final dynamic body =
            response.body.isNotEmpty ? json.decode(response.body) : null;
        lastPage = _totalPagesOrdens(body);
        final ordens = _extractOrdensList(body);
        if (ordens.isEmpty && page == 1) {
          gotAny = true; // lista vazia válida
          break;
        }
        gotAny = true;
        final now = DateTime.now().toUtc().toIso8601String();
        for (final raw in ordens) {
          final ordem = Map<String, dynamic>.from(raw);
          ordem['obra_uuid'] = uuid;
          await _processarOrdem(
            ordem,
            now,
            forceObraUuid: uuid,
            touchLastSync: false,
          );
          total++;
        }
        page++;
      }
      if (ok && gotAny) break;
    }

    if (!ok) {
      // Fallback: sync completo do tenant (não depende de list-ordens).
      await syncOrdens();
      await _backfillObraUuidLocal(db);
      print('⚠️ refreshOrdensPorObra: fallback syncOrdens()');
      return;
    }

    await _backfillObraUuidLocal(db);
    print('✅ refreshOrdensPorObra: $total ordens da obra $uuid');
  } catch (e) {
    print('⚠️ refreshOrdensPorObra: $e');
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

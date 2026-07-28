// Automatic FlutterFlow imports
import '/backend/schema/structs/index.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
import 'sync_last_sync_for_creator.dart';
import 'sync_relatorio_download_merge_guard.dart';

// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

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

String? _nonEmptyStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

/// UUID enviado em `criador` (TEXT no SQLite) — também enviamos `criador_uuid` explícito no sync.
String? _criadorUuidForUpload(dynamic criador) {
  final s = _nonEmptyStr(criador);
  if (s == null) return null;
  if (s.contains('-')) return s;
  return null;
}

String _createdByLocal(Map<String, dynamic> row) {
  // SQLite (`nova.sql`): `created_by` é TEXT com UUID.
  // Preferimos `created_by_uuid` do payload; fallback para `created_by`.
  return _nonEmptyStr(row['created_by_uuid']) ??
      (_nonEmptyStr(row['created_by'])?.contains('-') == true
          ? row['created_by'] as String
          : '');
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

/// Parse de data/hora para comparação LWW (ISO, texto SQLite, etc.).
DateTime? _parseFlexibleDateTime(dynamic v) {
  if (v == null) return null;
  if (v is DateTime) return v.toUtc();
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {
    return null;
  }
}

/// Versão do registro local para decidir se o download do servidor sobrescreve.
DateTime? _localRowVersionForMerge(Map<String, dynamic> localRow) {
  return _parseFlexibleDateTime(localRow['updated_at']) ??
      _parseFlexibleDateTime(localRow['created_at']) ??
      _parseFlexibleDateTime(localRow['last_sync_date']);
}

/// Versão do payload do servidor (fallback: hora do envelope do sync).
DateTime? _serverRowVersionForMerge(
  Map<String, dynamic> serverPayload,
  String envelopeServerTime,
) {
  return _parseFlexibleDateTime(serverPayload['updated_at']) ??
      _parseFlexibleDateTime(envelopeServerTime);
}

/// Aplica download só se o servidor tiver versão **estritamente** mais recente (LWW).
bool _shouldApplyServerRelatorio({
  required Map<String, dynamic>? localRow,
  required Map<String, dynamic> serverPayload,
  required String envelopeServerTime,
  bool prioridadeServidor = false,
}) {
  if (prioridadeServidor) return true;
  if (localRow == null) return true;

  final localV = _localRowVersionForMerge(localRow);
  final serverV = _serverRowVersionForMerge(serverPayload, envelopeServerTime);

  if (serverV == null) {
    if (localV == null) {
      // Sem âncora em nenhum lado: aplica payload do servidor (comportamento legado).
      return true;
    }
    print(
        '⚠️ relatorios sync: sem timestamp servidor; mantém local uuid=${serverPayload['uuid']}');
    return false;
  }
  if (localV == null) return true;

  if (serverV.isAfter(localV)) return true;

  print(
      'ℹ️ relatorios sync: skip download (local mais recente ou igual) uuid=${serverPayload['uuid']} local=$localV server=$serverV');
  return false;
}

/// Download: datas sempre em `dd/MM/yyyy` (TEXT), como no app.
String? _normalizeDateBr(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;

  final br = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$');
  final mBr = br.firstMatch(s);
  if (mBr != null) {
    final d = int.parse(mBr.group(1)!);
    final mo = int.parse(mBr.group(2)!);
    final y = int.parse(mBr.group(3)!);
    return '${d.toString().padLeft(2, '0')}/${mo.toString().padLeft(2, '0')}/$y';
  }

  try {
    final dt = DateTime.parse(s);
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  } catch (_) {
    return null;
  }
}

String _normalizeDateBrRequired(String fallbackIsoOrBr) {
  return _normalizeDateBr(fallbackIsoOrBr) ??
      DateFormat('dd/MM/yyyy').format(DateTime.now());
}

/// Download: `horas_trabalhadas` como decimal com 2 casas.
double? _normalizeHorasTrabalhadas(dynamic v) {
  if (v == null) return null;
  if (v is num) {
    return double.parse(v.toDouble().toStringAsFixed(2));
  }
  final s = v.toString().trim().replaceAll(',', '.');
  if (s.isEmpty) return null;
  final n = double.tryParse(s);
  if (n == null) return null;
  return double.parse(n.toStringAsFixed(2));
}

/// Download: horários apenas `HH:mm` (sem data).
String? _normalizeTimeHm(dynamic v) {
  if (v == null) return null;
  if (v is int) {
    if (v >= 0 && v < 24 * 60) {
      final h = v ~/ 60;
      final mi = v % 60;
      return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    }
    if (v >= 0 && v <= 2359 && v % 100 < 60 && v ~/ 100 < 24) {
      final h = v ~/ 100;
      final mi = v % 100;
      return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    }
    return null;
  }

  final s = v.toString().trim();
  if (s.isEmpty) return null;

  final hmOnly = RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$');
  final m = hmOnly.firstMatch(s);
  if (m != null) {
    final h = int.tryParse(m.group(1)!);
    final mi = int.tryParse(m.group(2)!);
    if (h != null && mi != null && h < 24 && mi < 60) {
      return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    }
  }

  try {
    final dt = DateTime.parse(s);
    return DateFormat('HH:mm').format(dt.toLocal());
  } catch (_) {
    return null;
  }
}

/// `relatorios.user_id` / `user_uuid` referem-se ao tenant (creator), não ao colaborador logado.
Future<Map<String, dynamic>?> _resolveTenantUserForRelatorioSync() async {
  final ff = FFAppState();
  final creatorUuid = ff.creatorUuid.trim();
  final creatorId = ff.creatorId;
  if (creatorUuid.isEmpty && creatorId <= 0) return null;

  final db = await SQLiteManager.instance.database;

  if (creatorUuid.isNotEmpty) {
    final rows = await db.query(
      'users',
      columns: ['id', 'uuid'],
      where: 'uuid = ?',
      whereArgs: [creatorUuid],
      limit: 1,
    );
    if (rows.isNotEmpty) {
      final id = rows.first['id'] as int?;
      final u = rows.first['uuid'] as String?;
      return {
        'user_id': id ?? creatorId,
        'user_uuid': (u != null && u.isNotEmpty) ? u : creatorUuid,
      };
    }
  }

  if (creatorId > 0) {
    final rows = await db.query(
      'users',
      columns: ['uuid'],
      where: 'id = ?',
      whereArgs: [creatorId],
      limit: 1,
    );
    if (rows.isNotEmpty && rows.first['uuid'] != null) {
      return {
        'user_id': creatorId,
        'user_uuid': rows.first['uuid'] as String,
      };
    }
  }

  if (creatorId > 0 || creatorUuid.isNotEmpty) {
    return {
      if (creatorId > 0) 'user_id': creatorId,
      if (creatorUuid.isNotEmpty) 'user_uuid': creatorUuid,
    };
  }
  return null;
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncRelatorios() async {
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
    try {
      final relatoriosNaoSincronizadas =
          await pendingRelatoriosForCurrentCreator(db);

      if (relatoriosNaoSincronizadas.isNotEmpty) {
        // GERAR UUIDs PARA ORDENS SEM UUID
        for (var relatorio in relatoriosNaoSincronizadas) {
          final rawUuid = relatorio['uuid']?.toString();
          final precisaUuid = rawUuid == null ||
              rawUuid.trim().isEmpty ||
              rawUuid.trim().toLowerCase() == 'null';
          if (precisaUuid) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorios',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [relatorio['id']],
            );
            print(
                '✅ Gerado UUID para relatorio: ${relatorio['id']} -> $newUuid');
          }
        }

        // BUSCAR ORDENS ATUALIZADAS (ainda só deste tenant)
        final relatoriosComUuid = await pendingRelatoriosForCurrentCreator(db);

        final tenantUser = await _resolveTenantUserForRelatorioSync();

        // PREPARAR DADOS PARA ENVIO
        final relatoriosParaEnviar = relatoriosComUuid.map((relatorio) {
          final tid = _asInt(tenantUser?['user_id']);
          final tuuid = _nonEmptyStr(tenantUser?['user_uuid']);
          return {
            'uuid': relatorio['uuid'],
            'user_id': tid ?? relatorio['user_id'],
            'user_uuid': tuuid ?? relatorio['user_uuid'],
            'obra_id': relatorio['obra_id'],
            'obra_uuid': relatorio['obra_uuid'],
            'modelo_id': relatorio['modelo_id'],
            'modelo_uuid': relatorio['modelo_uuid'],
            'data_executado': relatorio['data_executado'],
            'data_inicio': relatorio['data_inicio'],
            'data_final': relatorio['data_final'],
            'horas_trabalhadas': relatorio['horas_trabalhadas'],
            'manha_clima': relatorio['manha_clima'],
            'manha_condicao': relatorio['manha_condicao'],
            'tarde_clima': relatorio['tarde_clima'],
            'tarde_condicao': relatorio['tarde_condicao'],
            'noite_clima': relatorio['noite_clima'],
            'noite_condicao': relatorio['noite_condicao'],
            'status_id': relatorio['status_id'],
            'created_by_uuid': relatorio['created_by'],
            'situacao': relatorio['situacao'],
            'created_at': relatorio['created_at'],
            'updated_at': relatorio['updated_at'],
            'entrada_manha': relatorio['entrada_manha'],
            'saida_manha': relatorio['saida_manha'],
            'inicio_intervalo': relatorio['inicio_intervalo'],
            'fim_intervalo': relatorio['fim_intervalo'],
            'entrada_tarde': relatorio['entrada_tarde'],
            'saida_tarde': relatorio['saida_tarde'],
            'criador': relatorio['criador'],
            'criador_uuid': _criadorUuidForUpload(relatorio['criador']),
            'ultimo_motivo_reprovacao': relatorio['ultimo_motivo_reprovacao'],
            'ultima_data_reprovacao': relatorio['ultima_data_reprovacao'],
            'ultimo_motivo_reenvio': relatorio['ultimo_motivo_reenvio'],
            'ultima_data_reenvio': relatorio['ultima_data_reenvio'],
            'numero': relatorio['numero']
          };
        }).toList();

        print('📤 Enviando ${relatoriosParaEnviar.length} relatorios...');
        print(relatoriosParaEnviar);
        // FAZER UPLOAD
        final uploadResponse = await http.post(
          Uri.parse('https://api.rdopro.com.br/api/v1/sync/relatorios/upload'),
          headers: headers,
          body: json.encode({'dados': relatoriosParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadBody =
              mapaRespostaSyncJson(json.decode(uploadResponse.body));
          final tenantReconcilia =
              await _resolveTenantUserForRelatorioSync();
          final stUpload =
              serverTimeDoJsonResposta(uploadBody);

          for (final rowSrv in servidorVenceuLwwDoJson(uploadBody)) {
            await _processarOrdem(
              rowSrv,
              stUpload,
              tenantUserOverride: tenantReconcilia,
              prioridadeServidor: true,
            );
          }

          // MARCAR ORDENS COMO SINCRONIZADAS
          final sinc = uploadBody['sincronizados'];
          if (sinc is! List) {
            print('⚠️ relatorios upload: sincronizados ausente ou inválido');
          }
          for (var relatorio in (sinc is List ? sinc : const [])) {
            if (relatorio is! Map) continue;
            final u = relatorio['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorios',
              {
                'synced': 1,
                'last_sync_date': DateTime.now().toIso8601String(),
                'sync_try_count': 0,
              },
              where: 'uuid = ?',
              whereArgs: [u],
            );
            uploadedCount++;
          }
          print('✅ Upload concluído: $uploadedCount relatorios');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorio in relatoriosComUuid) {
            final currentCount = relatorio['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorios',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorio['uuid']],
            );
          }
          print('❌ Erro no upload: ${uploadResponse.statusCode}');
        }
      } else {
        if (currentCreatorUuidForSync().isEmpty) {
          print(
              '⚠️ Nenhuma relatorio para enviar: creatorUuid vazio (filtra tenant)');
        } else {
          print('ℹ️ Nenhuma relatorio para enviar');
        }
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorios');
      print('📥 Buscando relatorios desde: $lastSync');

      final downloadResponse = await http.post(
        Uri.parse('https://api.rdopro.com.br/api/v1/sync/relatorios/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosDoServidor = downloadResult['dados'] as List;

        print('📥 Recebidas ${relatoriosDoServidor.length} relatorios');

        final serverTimeStr = downloadResult['server_time']?.toString() ??
            DateTime.now().toIso8601String();

        final tenantUserDownload = await _resolveTenantUserForRelatorioSync();

        for (var relatorioServer in relatoriosDoServidor) {
          if (relatorioServer is! Map) continue;
          final aplicou = await _processarOrdem(
            Map<String, dynamic>.from(relatorioServer),
            serverTimeStr,
            tenantUserOverride: tenantUserDownload,
          );
          if (aplicou) downloadedCount++;
        }

        // ATUALIZAR LAST_SYNC_DATE (só linhas deste tenant)
        if (relatoriosDoServidor.isNotEmpty) {
          await updateRelatoriosLastSyncForCurrentTenant(db, serverTimeStr);
        }
        print('✅ Download concluído: $downloadedCount relatorios');
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
      'Sync relatorioss concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios: $e');
    _updateSyncStatus(false, 'Erro geral sync relatorios: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM =====

/// Retorna `true` se inseriu/atualizou SQLite; `false` se ignorou (LWW) ou erro de validação.
Future<bool> _processarOrdem(
  Map<String, dynamic> relatorioServer,
  String serverTime, {
  Map<String, dynamic>? tenantUserOverride,
  bool prioridadeServidor = false,
}) async {
  final db = await SQLiteManager.instance.database;

  String uuid = relatorioServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioServer['id'] != null) {
    await _salvarMapeamento('relatorios', relatorioServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorios',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );
  final Map<String, dynamic>? existente =
      existe.isNotEmpty ? Map<String, dynamic>.from(existe.first) : null;

  // --- Resolver FKs / campos NOT NULL (payload pode vir sem user_id / data_executado) ---
  int? userId =
      _asInt(relatorioServer['user_id']) ?? _asInt(existente?['user_id']);
  String? userUuid = _nonEmptyStr(relatorioServer['user_uuid']) ??
      _nonEmptyStr(existente?['user_uuid']);

  if (userId == null && userUuid != null) {
    final rows = await db.query('users',
        columns: ['id'], where: 'uuid = ?', whereArgs: [userUuid], limit: 1);
    if (rows.isNotEmpty) userId = rows.first['id'] as int?;
  }
  if ((userUuid == null || userUuid.isEmpty) && userId != null) {
    final rows = await db.query('users',
        columns: ['uuid'], where: 'id = ?', whereArgs: [userId], limit: 1);
    if (rows.isNotEmpty && rows.first['uuid'] != null) {
      userUuid = rows.first['uuid'] as String?;
    }
  }

  int? obraId =
      _asInt(relatorioServer['obra_id']) ?? _asInt(existente?['obra_id']);
  String? obraUuid = _nonEmptyStr(relatorioServer['obra_uuid']) ??
      _nonEmptyStr(existente?['obra_uuid']);
  if ((obraUuid == null || obraUuid.isEmpty) && obraId != null) {
    final rows = await db
        .rawQuery('SELECT uuid FROM obras WHERE id = ? LIMIT 1', [obraId]);
    if (rows.isNotEmpty && rows.first['uuid'] != null) {
      obraUuid = rows.first['uuid'] as String?;
    }
  }

  int? modeloId =
      _asInt(relatorioServer['modelo_id']) ?? _asInt(existente?['modelo_id']);
  String? modeloUuid = _nonEmptyStr(relatorioServer['modelo_uuid']) ??
      _nonEmptyStr(existente?['modelo_uuid']);
  if ((modeloUuid == null || modeloUuid.isEmpty) && modeloId != null) {
    final rows = await db.rawQuery(
        'SELECT uuid FROM modelo_relatorios WHERE id = ? LIMIT 1', [modeloId]);
    if (rows.isNotEmpty && rows.first['uuid'] != null) {
      modeloUuid = rows.first['uuid'] as String?;
    }
  }

  final dataExecutadoRaw = _nonEmptyStr(relatorioServer['data_executado']) ??
      _nonEmptyStr(relatorioServer['data']) ??
      _nonEmptyStr(relatorioServer['created_at']) ??
      serverTime;
  final dataExecutado = _normalizeDateBr(dataExecutadoRaw) ??
      _normalizeDateBrRequired(serverTime);

  String createdBy = _createdByLocal(relatorioServer);
  if (createdBy.isEmpty) {
    final cbId = _asInt(relatorioServer['created_by']);
    if (cbId != null) {
      final rows = await db.query('users',
          columns: ['uuid'], where: 'id = ?', whereArgs: [cbId], limit: 1);
      if (rows.isNotEmpty && rows.first['uuid'] != null) {
        createdBy = rows.first['uuid'] as String;
      }
    }
  }
  if (createdBy.isEmpty) {
    final prev = existente?['created_by'];
    if (prev is String && prev.contains('-')) createdBy = prev;
  }
  if (createdBy.isEmpty && userUuid != null && userUuid.isNotEmpty) {
    createdBy = userUuid;
  }

  if (createdBy.isEmpty) {
    print('❌ relatorios sync: created_by ausente uuid=$uuid');
    return false;
  }

  String criadorLocal = _nonEmptyStr(relatorioServer['criador_uuid']) ?? '';
  if (criadorLocal.isEmpty) {
    final cr = relatorioServer['criador'];
    if (cr != null && cr.toString().contains('-')) {
      criadorLocal = cr.toString().trim();
    } else {
      final crId = _asInt(cr);
      if (crId != null) {
        final rows = await db.query('users',
            columns: ['uuid'], where: 'id = ?', whereArgs: [crId], limit: 1);
        if (rows.isNotEmpty && rows.first['uuid'] != null) {
          criadorLocal = rows.first['uuid'] as String;
        }
      }
    }
  }
  if (criadorLocal.isEmpty) {
    final prevC = existente?['criador'];
    if (prevC is String && prevC.contains('-')) criadorLocal = prevC;
  }
  if (criadorLocal.isEmpty) {
    criadorLocal = createdBy;
  }

  if (tenantUserOverride != null) {
    final tid = _asInt(tenantUserOverride['user_id']);
    final tuuid = _nonEmptyStr(tenantUserOverride['user_uuid']);
    if (tid != null) userId = tid;
    if (tuuid != null && tuuid.isNotEmpty) userUuid = tuuid;
  }

  if (userId == null || obraId == null || modeloId == null) {
    print(
        '❌ relatorios sync: FK ausente (user_id=$userId obra_id=$obraId modelo_id=$modeloId) uuid=$uuid');
    return false;
  }

  // Last-write-wins: só sobrescreve SQLite se o servidor tiver versão mais nova.
  if (existente != null) {
    if (!_shouldApplyServerRelatorio(
      localRow: existente,
      serverPayload: relatorioServer,
      envelopeServerTime: serverTime,
      prioridadeServidor: prioridadeServidor,
    )) {
      return false;
    }
  }

  final rowCommon = <String, dynamic>{
    'user_id': userId,
    'user_uuid': userUuid ?? '',
    'obra_id': obraId,
    'obra_uuid': obraUuid ?? '',
    'modelo_id': modeloId,
    'modelo_uuid': modeloUuid ?? '',
    'data_executado': dataExecutado,
    'data_inicio': _normalizeDateBr(relatorioServer['data_inicio']),
    'data_final': _normalizeDateBr(relatorioServer['data_final']),
    'horas_trabalhadas':
        _normalizeHorasTrabalhadas(relatorioServer['horas_trabalhadas']),
    'manha_clima': relatorioServer['manha_clima'],
    'manha_condicao': relatorioServer['manha_condicao'],
    'tarde_clima': relatorioServer['tarde_clima'],
    'tarde_condicao': relatorioServer['tarde_condicao'],
    'noite_clima': relatorioServer['noite_clima'],
    'noite_condicao': relatorioServer['noite_condicao'],
    'status_id': relatorioServer['status_id'],
    'created_by': createdBy,
    'situacao': relatorioServer['situacao'],
    'created_at': relatorioServer['created_at'],
    'updated_at': relatorioServer['updated_at'],
    'entrada_manha': _normalizeTimeHm(relatorioServer['entrada_manha']),
    'saida_manha': _normalizeTimeHm(relatorioServer['saida_manha']),
    'inicio_intervalo': _normalizeTimeHm(relatorioServer['inicio_intervalo']),
    'fim_intervalo': _normalizeTimeHm(relatorioServer['fim_intervalo']),
    'entrada_tarde': _normalizeTimeHm(relatorioServer['entrada_tarde']),
    'saida_tarde': _normalizeTimeHm(relatorioServer['saida_tarde']),
    'criador': criadorLocal,
    'ultimo_motivo_reprovacao': relatorioServer['ultimo_motivo_reprovacao'],
    'ultima_data_reprovacao': relatorioServer['ultima_data_reprovacao'],
    'ultimo_motivo_reenvio': relatorioServer['ultimo_motivo_reenvio'],
    'ultima_data_reenvio': relatorioServer['ultima_data_reenvio'],
    'numero': relatorioServer['numero'],
    'synced': 1,
    'last_sync_date': serverTime,
  };

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'relatorios',
      rowCommon,
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert(
      'relatorios',
      {'uuid': uuid, ...rowCommon},
    );
  }
  return true;
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
    return FFAppState().UserToken;
  } catch (e) {
    return '';
  }
}

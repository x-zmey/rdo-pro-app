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

import 'index.dart'; // Imports other custom actions

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

import 'sync_relatorio_download_merge_guard.dart';
import '/backend/sqlite/situacao_soft_delete.dart';

const String _kUrlUploadMaoObraPresenca =
    '$kApiBaseUrl/api/v1/sync/relatorios/mao-obra-presencas/upload';
const String _kUrlDownloadMaoObraPresenca =
    '$kApiBaseUrl/api/v1/sync/relatorios/mao-obra-presencas/download';

Uri _uriMaoObraPresencaUpload() => Uri.parse(_kUrlUploadMaoObraPresenca.trim());

Uri _uriMaoObraPresencaDownload() =>
    Uri.parse(_kUrlDownloadMaoObraPresenca.trim());

// ===== FUNÇÕES UTILITÁRIAS (já existentes - copie da action anterior) =====

int _situacaoPresencaFromApi(dynamic v) {
  if (v == null) return kSituacaoAtivo;
  if (v is int) return v;
  final p = int.tryParse(v.toString());
  return p ?? kSituacaoAtivo;
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

/// `dd/MM/yyyy` ou `dd-MM-yyyy` → `yyyy-MM-dd` (Laravel cast `date` em [data_referencia]).
String? _normalizeDateReferenciaApi(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final br = RegExp(r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})$').firstMatch(s);
  if (br != null) {
    final d = int.tryParse(br.group(1)!);
    final m = int.tryParse(br.group(2)!);
    final y = int.tryParse(br.group(3)!);
    if (d != null && m != null && y != null) {
      return '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    }
  }
  if (s.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
    return s.substring(0, 10);
  }
  return s;
}

/// Data/hora BR ou ISO para o cast `datetime` de [confirmado_em].
String? _normalizeDateTimeApi(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  final br = RegExp(
    r'^(\d{1,2})[\/\-](\d{1,2})[\/\-](\d{4})(?:\s+(\d{1,2}):(\d{2})(?::(\d{2}))?)?$',
  ).firstMatch(s);
  if (br != null) {
    final d = int.tryParse(br.group(1)!);
    final mo = int.tryParse(br.group(2)!);
    final y = int.tryParse(br.group(3)!);
    final h = int.tryParse(br.group(4) ?? '') ?? 0;
    final mi = int.tryParse(br.group(5) ?? '') ?? 0;
    final se = int.tryParse(br.group(6) ?? '') ?? 0;
    if (d != null && mo != null && y != null) {
      return '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')} '
          '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}:${se.toString().padLeft(2, '0')}';
    }
  }
  return s;
}

String _createdByLocal(Map<String, dynamic> row) {
  // No SQLite (`nova.sql`), `created_by` é UUID (TEXT).
  return _nonEmptyStr(row['created_by_uuid']) ??
      _nonEmptyStr(row['created_by']) ??
      '';
}

/// Download: datas em `dd/MM/yyyy` (TEXT), alinhado a `sync_relatorios`.
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

  // ISO/datetime da API (ex.: 2026-04-28T07:05:00.000000Z): usar HH:mm literal do texto,
  // não conversão para fuso — horário é "relógio" da jornada, não um instante.
  final isoWall = RegExp(
    r'^\d{4}-\d{2}-\d{2}[T ]\s*(\d{1,2}):(\d{2})(?::\d{2})?(?:\.\d+)?',
  ).firstMatch(s);
  if (isoWall != null) {
    final h = int.tryParse(isoWall.group(1)!);
    final mi = int.tryParse(isoWall.group(2)!);
    if (h != null && mi != null && h < 24 && mi < 60) {
      return '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}';
    }
  }

  try {
    final dt = DateTime.parse(s);
    // Sem toLocal(): para instantes UTC, format já usa componente UTC da data;
    // evita mudar HH:mm apenas por estar o dispositivo em outro fuso.
    return DateFormat('HH:mm').format(dt);
  } catch (_) {
    return null;
  }
}

// ===== FUNÇÃO PRINCIPAL =====

Future synRelatoriosMaoObraPresenca() async {
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

    // ===== 1. UPLOAD — só [relatorio_mao_obra_presenca]: created_by = tenant, sem JOIN =====
    try {
      await stampPendingRelatorioMaoObraPresencaCreatedByTenantFallback(db);

      var relatoriosMaoObraPresencasNaoSincronizadas =
          await pendingRelatorioMaoObraPresencaForTenantSimple(db);

      if (relatoriosMaoObraPresencasNaoSincronizadas.isNotEmpty) {
        for (final row in relatoriosMaoObraPresencasNaoSincronizadas) {
          if (row['uuid'] == null ||
              (row['uuid'] as String?)?.trim().isEmpty == true) {
            final newUuid = _generateUuid();
            await db.update(
              'relatorio_mao_obra_presenca',
              {'uuid': newUuid},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            print(
                '✅ Gerado UUID para relatorio mao de obra presenca: ${row['id']} -> $newUuid');
          }
        }

        final relatoriosMaoObraPresencasComUuid =
            await pendingRelatorioMaoObraPresencaForTenantSimple(db);

        final relatoriosMaoObraPresencasParaEnviar =
            <Map<String, dynamic>>[];
        for (final rowMp in relatoriosMaoObraPresencasComUuid) {
          final linha = Map<String, dynamic>.from(rowMp);
          await backfillRelatorioUuidForPayloadRow(db, linha);
          relatoriosMaoObraPresencasParaEnviar.add({
            'uuid': linha['uuid'],
            'company_id': linha['company_id'],
            'company_uuid': linha['company_uuid'],
            'relatorio_id': linha['relatorio_id'],
            'relatorio_uuid': linha['relatorio_uuid'],
            'obra_item_id': linha['obra_item_id'],
            'obra_item_uuid': linha['obra_item_uuid'],
            'data_referencia': _normalizeDateReferenciaApi(
                    linha['data_referencia']) ??
                linha['data_referencia'],
            'status_presenca': linha['status_presenca'],
            'hora_entrada': linha['hora_entrada'],
            'hora_saida': linha['hora_saida'],
            'intervalo_inicio': linha['intervalo_inicio'],
            'intervalo_fim': linha['intervalo_fim'],
            'horas_trabalhadas':
                _normalizeHorasTrabalhadas(linha['horas_trabalhadas']),
            'motivo_ausencia': linha['motivo_ausencia'],
            'motivo_saida_cedo': linha['motivo_saida_cedo'],
            'minutos_atraso': linha['minutos_atraso'],
            'motivo_atraso': linha['motivo_atraso'],
            'confirmado': linha['confirmado'],
            'confirmado_por': linha['confirmado_por'],
            'confirmado_em': _normalizeDateTimeApi(linha['confirmado_em']) ??
                linha['confirmado_em'],
            'created_by_uuid': linha['created_by'],
            'updated_by': linha['updated_by'],
            'created_at': linha['created_at'],
            'updated_at': linha['updated_at'],
            'situacao': _situacaoPresencaFromApi(linha['situacao']),
          });
        }

        print(
            '📤 Enviando ${relatoriosMaoObraPresencasParaEnviar.length} relatorios mao de obra presencas...');
        print('📤 POST ${_uriMaoObraPresencaUpload()}');

        final uploadResponse = await http.post(
          _uriMaoObraPresencaUpload(),
          headers: headers,
          body: json.encode({'dados': relatoriosMaoObraPresencasParaEnviar}),
        );

        if (uploadResponse.statusCode == 200) {
          final uploadBody =
              mapaRespostaSyncJson(json.decode(uploadResponse.body));
          final stUpload = serverTimeDoJsonResposta(uploadBody);

          for (final rowSrv in servidorVenceuLwwDoJson(uploadBody)) {
            await _processarOrdemTarefa(rowSrv, stUpload,
                prioridadeServidor: true);
          }

          // MARCAR RELATORIOS TAREFAS COMO SINCRONIZADAS
          final sinc = uploadBody['sincronizados'];
          for (var relatorioMaoObraPresenca in (sinc is List ? sinc : const [])) {
            if (relatorioMaoObraPresenca is! Map) continue;
            final u = relatorioMaoObraPresenca['uuid']?.toString();
            if (u == null || u.isEmpty) continue;
            await db.update(
              'relatorio_mao_obra_presenca',
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
          print(
              '✅ Upload concluído: $uploadedCount relatorios mao de obra presencas');
        } else if (uploadResponse.statusCode == 401) {
          _updateSyncStatus(
              false, 'Token expirado. Faça login novamente.', 0, 0);
          return;
        } else {
          // INCREMENTAR TENTATIVAS EM CASO DE ERRO
          for (var relatorioMaoObraPresenca
              in relatoriosMaoObraPresencasComUuid) {
            final currentCount =
                relatorioMaoObraPresenca['sync_try_count'] as int? ?? 0;
            await db.update(
              'relatorio_mao_obra_presenca',
              {'sync_try_count': currentCount + 1},
              where: 'uuid = ?',
              whereArgs: [relatorioMaoObraPresenca['uuid']],
            );
          }
          print(
              '❌ Erro no upload: ${uploadResponse.statusCode} — ${uploadResponse.body}');
        }
      } else {
        print('ℹ️ Nenhuma relatorio mao de obra presenca para enviar');
      }
    } catch (e) {
      print('❌ Erro no upload: $e');
    }

    // ===== 2. DOWNLOAD - Buscar atualizações =====
    try {
      final lastSync = await _getUltimaSync('relatorio_mao_obra_presenca');
      print('📥 Buscando relatorios mao de obra presencas desde: $lastSync');
      print('📥 POST ${_uriMaoObraPresencaDownload()}');

      final downloadResponse = await http.post(
        _uriMaoObraPresencaDownload(),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (downloadResponse.statusCode == 200) {
        final downloadResult = json.decode(downloadResponse.body);
        final relatoriosMaoObraPresencasDoServidor =
            downloadResult['dados'] as List;

        print(
            '📥 Recebidas ${relatoriosMaoObraPresencasDoServidor.length} mao de obra presencas');

        for (var relatorioMaoObraPresencaServer
            in relatoriosMaoObraPresencasDoServidor) {
          await _processarOrdemTarefa(
              relatorioMaoObraPresencaServer, downloadResult['server_time']);
          downloadedCount++;
        }

        if (relatoriosMaoObraPresencasDoServidor.isNotEmpty) {
          await updateLastSyncMaoObraPresencaSyncedForTenant(
            db,
            downloadResult['server_time'].toString(),
          );
        }
        print(
            '✅ Download concluído: $downloadedCount relatorios mao de obra presencas');
      } else if (downloadResponse.statusCode == 401) {
        _updateSyncStatus(
            false, 'Token expirado. Faça login novamente.', uploadedCount, 0);
        return;
      } else {
        print(
            '❌ Erro no download: ${downloadResponse.statusCode} — ${downloadResponse.body}');
      }
    } catch (e) {
      print('❌ Erro no download: $e');
    }

    // ===== 3. SUCESSO =====
    _updateSyncStatus(
      true,
      'Sync mao de obra concluída: ↑$uploadedCount ↓$downloadedCount',
      uploadedCount,
      downloadedCount,
    );
    print('🎉 Sync relatorios mao de obra presencas concluída com sucesso!');
  } catch (e) {
    print('❌ Erro geral sync relatorios mao de obra: $e');
    _updateSyncStatus(
        false, 'Erro geral sync relatorios mao de obra presencas: $e', 0, 0);
  }
}

// ===== FUNÇÃO DE PROCESSAMENTO DE ORDEM TAREFAs =====

Future<void> _processarOrdemTarefa(
    Map<String, dynamic> relatorioMaoObraPresencaServer,
    String serverTime,
    {bool prioridadeServidor = false}) async {
  final db = await SQLiteManager.instance.database;

  final s = relatorioMaoObraPresencaServer;
  final dataReferencia = _normalizeDateBr(s['data_referencia']) ??
      _normalizeDateBr(serverTime) ??
      DateFormat('dd/MM/yyyy').format(DateTime.now());
  final horaEntrada = _normalizeTimeHm(s['hora_entrada']);
  final horaSaida = _normalizeTimeHm(s['hora_saida']);
  final intervaloInicio = _normalizeTimeHm(s['intervalo_inicio']);
  final intervaloFim = _normalizeTimeHm(s['intervalo_fim']);
  final horasTrabalhadas = _normalizeHorasTrabalhadas(s['horas_trabalhadas']);

  String uuid = relatorioMaoObraPresencaServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (relatorioMaoObraPresencaServer['id'] != null) {
    await _salvarMapeamento('relatorio_mao_obra_presenca',
        relatorioMaoObraPresencaServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'relatorio_mao_obra_presenca',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    if (mantemVersaoLocalNaSyncDownloadRelatorioFilha(
          localRow: Map<String, dynamic>.from(existe.first),
          serverRow: s,
          tabela: 'relatorio_mao_obra_presenca',
          prioridadeServidor: prioridadeServidor,
        )) {
      return;
    }
    // UPDATE
    await db.update(
      'relatorio_mao_obra_presenca',
      {
        'company_id': relatorioMaoObraPresencaServer['company_id'],
        'company_uuid':
            _nonEmptyStr(relatorioMaoObraPresencaServer['company_uuid']),
        'relatorio_id': relatorioMaoObraPresencaServer['relatorio_id'],
        'relatorio_uuid':
            _nonEmptyStr(relatorioMaoObraPresencaServer['relatorio_uuid']),
        'obra_item_id': relatorioMaoObraPresencaServer['obra_item_id'],
        'obra_item_uuid':
            _nonEmptyStr(relatorioMaoObraPresencaServer['obra_item_uuid']),
        'data_referencia': dataReferencia,
        'status_presenca': relatorioMaoObraPresencaServer['status_presenca'],
        'hora_entrada': horaEntrada,
        'hora_saida': horaSaida,
        'intervalo_inicio': intervaloInicio,
        'intervalo_fim': intervaloFim,
        'horas_trabalhadas': horasTrabalhadas,
        'motivo_ausencia': relatorioMaoObraPresencaServer['motivo_ausencia'],
        'motivo_saida_cedo': relatorioMaoObraPresencaServer['motivo_saida_cedo'],
        'minutos_atraso': relatorioMaoObraPresencaServer['minutos_atraso'],
        'motivo_atraso': relatorioMaoObraPresencaServer['motivo_atraso'],
        'confirmado': relatorioMaoObraPresencaServer['confirmado'],
        'confirmado_por': relatorioMaoObraPresencaServer['confirmado_por'],
        'confirmado_em': relatorioMaoObraPresencaServer['confirmado_em'],
        'created_by': _createdByLocal(relatorioMaoObraPresencaServer),
        'updated_by': relatorioMaoObraPresencaServer['updated_by'],
        'situacao': _situacaoPresencaFromApi(s['situacao']),
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': relatorioMaoObraPresencaServer['created_at'],
        'updated_at': relatorioMaoObraPresencaServer['updated_at']
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert('relatorio_mao_obra_presenca', {
      'uuid': uuid,
      'company_id': relatorioMaoObraPresencaServer['company_id'],
      'company_uuid':
          _nonEmptyStr(relatorioMaoObraPresencaServer['company_uuid']),
      'relatorio_id': relatorioMaoObraPresencaServer['relatorio_id'],
      'relatorio_uuid':
          _nonEmptyStr(relatorioMaoObraPresencaServer['relatorio_uuid']),
      'obra_item_id': relatorioMaoObraPresencaServer['obra_item_id'],
      'obra_item_uuid':
          _nonEmptyStr(relatorioMaoObraPresencaServer['obra_item_uuid']),
      'data_referencia': dataReferencia,
      'status_presenca': relatorioMaoObraPresencaServer['status_presenca'],
      'hora_entrada': horaEntrada,
      'hora_saida': horaSaida,
      'intervalo_inicio': intervaloInicio,
      'intervalo_fim': intervaloFim,
      'horas_trabalhadas': horasTrabalhadas,
      'motivo_ausencia': relatorioMaoObraPresencaServer['motivo_ausencia'],
      'motivo_saida_cedo': relatorioMaoObraPresencaServer['motivo_saida_cedo'],
      'minutos_atraso': relatorioMaoObraPresencaServer['minutos_atraso'],
      'motivo_atraso': relatorioMaoObraPresencaServer['motivo_atraso'],
      'confirmado': relatorioMaoObraPresencaServer['confirmado'],
      'confirmado_por': relatorioMaoObraPresencaServer['confirmado_por'],
      'confirmado_em': relatorioMaoObraPresencaServer['confirmado_em'],
      'created_by': _createdByLocal(relatorioMaoObraPresencaServer),
      'updated_by': relatorioMaoObraPresencaServer['updated_by'],
      'situacao': _situacaoPresencaFromApi(s['situacao']),
      'synced': 1,
      'last_sync_date': serverTime,
      'created_at': relatorioMaoObraPresencaServer['created_at'],
      'updated_at': relatorioMaoObraPresencaServer['updated_at']
    });
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

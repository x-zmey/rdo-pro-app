import 'package:intl/intl.dart';

// --- Contrato de sync (filhas do relatório) ---------------------------------
//
// [synced] no SQLite:
//   - 0 → alteração local ainda não “ack” pelo servidor (edição normal, inclusão ou
//     soft-delete: `situacao = -2`). Essas linhas entram na fila de UPLOAD (`WHERE synced = 0`).
//   - 1 → estado refletindo último ACK de download/upload com sucesso.
//
// Ao editar/apagar logicamente uma filha em [queries/update.dart], use sempre
// `synced = 0` + `updated_at` (UTC ISO) na própria filha [e `_touchRelatorioModificadoLocal`
// no pai quando aplicável].
//
// DOWN (merge servidor → SQLite), [mantemVersaoLocalNaSyncDownloadRelatorioFilha]:
//   1) Se `synced == 0` → **não** sobrescreve o local (prioridade máxima: envio pendente).
//   2) Caso contrário, compara `updated_at` local vs servidor (UTC); se o servidor **não** é
//      estritamente mais novo, mantém o local (LWW com empate preservando cliente).
//
// Identidade no pull: usar [normalizeSyncUuid] / [resolveLocalRowForSyncDownload]
// (`sync_uuid_upsert.dart`). **Nunca** inventar UUID no download — uuid ausente = skip.
//
// UP (API): [servidorRejeitarUploadStaleVersusCliente] rejeita gravação se o servidor tem
// `updated_at` mais recente que o `updated_at` enviado pelo app (entrada em `servidor_venceu_lww`).
//
// Reconciliação: após upload, linhas retornadas em `servidor_venceu_lww` devem ser aplicadas com
// [prioridadeServidor] true para sobrescrever o guard sem perder verdade consolidada na API.

/// Alteração local ainda pendente de enviar ao servidor (`synced == 0`).
///
/// SQLite costuma devolver [int]; em migrações raras pode vir como string numérica.
/// [null]: legado/coluna ausente — **não** tratamos como pendente (mantém comportamento anterior;
/// assim o download pode aplicar payloads do servidor nestes registros).
bool relatorioFilhaSyncedPendenteEnvio(Map<String, dynamic> localRow) {
  final s = localRow['synced'];
  if (s == null) {
    return false;
  }
  if (s is int) return s == 0;
  if (s is num) return s.toInt() == 0;
  final parsed = int.tryParse(s.toString());
  if (parsed == null) {
    // Valor estranho: por segurança, considerar pendente de envio para não sobrescrever dados locais no download.
    return true;
  }
  return parsed == 0;
}

/// Normaliza [updated_at] vindos da API/SQLite para comparação em UTC.
DateTime? parseRelatorioFilhaUpdatedAtUtc(dynamic v) {
  if (v == null) return null;
  var s = v.toString().trim();
  if (s.isEmpty) return null;

  try {
    return DateTime.parse(s).toUtc();
  } catch (_) {}

  if (RegExp(r'^\d{4}-\d{2}-\d{2}\s+\d').hasMatch(s)) {
    try {
      return DateFormat('yyyy-MM-dd HH:mm:ss').parse(s, true).toUtc();
    } catch (_) {}
  }

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
      final norm =
          '${y.toString().padLeft(4, '0')}-${mo.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')} '
          '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}:${se.toString().padLeft(2, '0')}';
      try {
        return DateFormat('yyyy-MM-dd HH:mm:ss').parse(norm, true).toUtc();
      } catch (_) {}
    }
  }

  return null;
}

/// Corpo JSON de resposta tratado como mapa (`upload`/`download`).
Map<String, dynamic> mapaRespostaSyncJson(dynamic decoded) {
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return {};
}

/// `server_time` do envelope ou [fallbackIso] (UTC ISO).
String serverTimeDoJsonResposta(
  Map<String, dynamic> body, [
  String? fallbackIso,
]) {
  final fb =
      fallbackIso ?? DateTime.now().toUtc().toIso8601String();
  final s = body['server_time']?.toString().trim();
  if (s == null || s.isEmpty) return fb;
  return s;
}

/// Linhas em [servidor_venceu_lww] quando o API recusa upload (servidor mais recente — LWW).
List<Map<String, dynamic>> servidorVenceuLwwDoJson(Map<String, dynamic> body) {
  final raw = body['servidor_venceu_lww'];
  if (raw == null || raw is! List) return [];
  final out = <Map<String, dynamic>>[];
  for (final e in raw) {
    if (e is Map<String, dynamic>) {
      out.add(Map<String, dynamic>.from(e));
    } else if (e is Map) {
      out.add(Map<String, dynamic>.from(e));
    }
  }
  return out;
}

/// No download (ou reconciliação pós-upload), preserva dados locais se:
/// - há envio pendente ([relatorioFilhaSyncedPendenteEnvio]); ou
/// - [updated_at] local ≥ [updated_at] do servidor em UTC (LWW incluindo empate).
///
/// Para aplicar servidor “à força”, use [prioridadeServidor] (ex.: payload de `servidor_venceu_lww`).
bool mantemVersaoLocalNaSyncDownloadRelatorioFilha({
  required Map<String, dynamic> localRow,
  required Map<String, dynamic> serverRow,
  required String tabela,
  bool prioridadeServidor = false,
}) {
  if (prioridadeServidor) {
    return false;
  }
  if (relatorioFilhaSyncedPendenteEnvio(localRow)) {
    // ignore: avoid_print
    print(
      'ℹ️ $tabela uuid=${localRow['uuid']}: mantendo dados locais (synced=0).',
    );
    return true;
  }
  final localAt = parseRelatorioFilhaUpdatedAtUtc(localRow['updated_at']);
  final serverAt = parseRelatorioFilhaUpdatedAtUtc(serverRow['updated_at']);
  if (localAt != null && serverAt != null && !serverAt.isAfter(localAt)) {
    // ignore: avoid_print
    print(
      'ℹ️ $tabela uuid=${localRow['uuid']}: mantendo dados locais (updated_at local >= servidor).',
    );
    return true;
  }
  return false;
}

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'download_obra_foto_local.dart';
import 'obra_foto_url.dart';

/// Cache da última resposta do servidor nesta sessão (evita spam de API).
Map<String, Map<String, String>>? _fotosServidorCache;

/// Serializa chamadas simultâneas (abertura da tela + fim do sync).
Future<int>? _execucaoEmAndamento;

/// Garante que a capa de cada obra esteja baixada no dispositivo.
///
/// O download de obras é incremental (`ultima_sync`), então uma obra que não
/// mudou nunca volta no payload do sync e a capa jamais seria baixada. Aqui a
/// verificação parte do SQLite: se alguma obra está sem arquivo local, pedimos
/// ao servidor a lista completa (`foto` + `foto_url`) e baixamos o que falta.
/// Também corrige o caso de a foto existir no servidor e a coluna `obras.foto`
/// local estar vazia (foto cadastrada na web depois do último sync).
///
/// Retorna quantas capas foram baixadas.
Future<int> ensureObrasFotosLocais({bool forcar = false}) {
  final emAndamento = _execucaoEmAndamento;
  if (emAndamento != null) return emAndamento;
  final execucao = _ensureObrasFotosLocais(forcar: forcar);
  _execucaoEmAndamento = execucao;
  return execucao.whenComplete(() => _execucaoEmAndamento = null);
}

/// Limpa o cache de capas (ex.: troca de tenant / logout).
void resetObrasFotosLocaisCache() {
  _fotosServidorCache = null;
}

Future<int> _ensureObrasFotosLocais({required bool forcar}) async {
  final db = SQLiteManager.instance.database;

  List<Map<String, Object?>> locais;
  try {
    locais = await db.query(
      'obras',
      columns: ['uuid', 'foto', 'foto_local'],
    );
  } catch (e) {
    debugPrint('ensureObrasFotosLocais: leitura das obras falhou: $e');
    return 0;
  }
  if (locais.isEmpty) return 0;

  final semCapaLocal = <String, Map<String, String>>{};
  for (final row in locais) {
    final uuid = (row['uuid']?.toString() ?? '').trim();
    if (uuid.isEmpty) continue;
    final foto = (row['foto']?.toString() ?? '').trim();
    final fotoLocal = (row['foto_local']?.toString() ?? '').trim();
    if (!forcar && await _arquivoLocalOk(fotoLocal)) continue;
    semCapaLocal[uuid] = {'foto': foto, 'foto_local': fotoLocal};
  }
  if (semCapaLocal.isEmpty) return 0;

  final doServidor = await _obterFotosNoServidor(forcar: forcar);
  if (doServidor == null) {
    // Sem API: ainda tenta baixar com path relativo → URL S3 montada.
    return _baixarComFallbackLocal(semCapaLocal);
  }

  var baixadas = 0;
  for (final entry in semCapaLocal.entries) {
    final uuid = entry.key;
    final servidor = doServidor[uuid];
    final fotoLocalAtual = entry.value['foto_local'] ?? '';

    final fotoServidor = (servidor?['foto'] ?? entry.value['foto'] ?? '').trim();
    final fotoUrl = (servidor?['foto_url'] ?? '').trim();

    // Servidor passou a ter (ou trocou) a foto: mantém `obras.foto` alinhada.
    if (servidor != null && fotoServidor != (entry.value['foto'] ?? '')) {
      try {
        await db.update(
          'obras',
          {'foto': fotoServidor.isEmpty ? null : fotoServidor},
          where: 'uuid = ?',
          whereArgs: [uuid],
        );
      } catch (e) {
        debugPrint('ensureObrasFotosLocais: update foto de $uuid: $e');
      }
    }

    if (fotoServidor.isEmpty && fotoUrl.isEmpty) {
      // Sem foto no servidor e sem path local útil: limpa arquivo órfão.
      if (fotoLocalAtual.isNotEmpty) {
        await downloadObraFotoLocal(
          obraUuid: uuid,
          fotoLocalAtual: fotoLocalAtual,
        );
      }
      continue;
    }

    final destino = await downloadObraFotoLocal(
      obraUuid: uuid,
      fotoServidor: fotoServidor,
      fotoUrl: resolveObraFotoNetworkUrl(foto: fotoServidor, fotoUrl: fotoUrl),
      fotoLocalAtual: fotoLocalAtual,
    );
    if (destino != null) baixadas++;
  }

  if (baixadas > 0) {
    debugPrint('ensureObrasFotosLocais: $baixadas capa(s) baixada(s)');
  }
  return baixadas;
}

/// Quando a API falha, tenta baixar com a URL S3 montada a partir de `obras.foto`.
Future<int> _baixarComFallbackLocal(
  Map<String, Map<String, String>> semCapaLocal,
) async {
  var baixadas = 0;
  for (final entry in semCapaLocal.entries) {
    final foto = entry.value['foto'] ?? '';
    final url = resolveObraFotoNetworkUrl(foto: foto);
    if (url == null) continue;
    final destino = await downloadObraFotoLocal(
      obraUuid: entry.key,
      fotoServidor: foto,
      fotoUrl: url,
      fotoLocalAtual: entry.value['foto_local'],
    );
    if (destino != null) baixadas++;
  }
  if (baixadas > 0) {
    debugPrint(
      'ensureObrasFotosLocais: $baixadas capa(s) via fallback S3 (sem API)',
    );
  }
  return baixadas;
}

Future<bool> _arquivoLocalOk(String caminho) async {
  if (caminho.isEmpty) return false;
  if (caminho.startsWith('http')) return false;
  try {
    final arquivo = caminho.startsWith('file://')
        ? File.fromUri(Uri.parse(caminho))
        : File(caminho);
    return await arquivo.exists();
  } catch (_) {
    return false;
  }
}

Future<Map<String, Map<String, String>>?> _obterFotosNoServidor({
  required bool forcar,
}) async {
  if (!forcar && _fotosServidorCache != null) {
    return _fotosServidorCache;
  }
  final mapa = await _buscarFotosNoServidor();
  if (mapa != null) {
    _fotosServidorCache = mapa;
  }
  return mapa;
}

/// `uuid` → `{foto, foto_url}` de todas as obras do tenant. `null` em falha.
Future<Map<String, Map<String, String>>?> _buscarFotosNoServidor() async {
  final token = FFAppState().UserToken.trim();
  if (token.isEmpty) return null;

  try {
    final resposta = await http
        .post(
          Uri.parse('https://api.rdopro.com.br/api/v1/sync/obras/download'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
          // Sem `ultima_sync` o servidor devolve todas as obras.
          body: json.encode({'ultima_sync': null}),
        )
        .timeout(const Duration(seconds: 45));

    if (resposta.statusCode != 200) {
      debugPrint('ensureObrasFotosLocais: HTTP ${resposta.statusCode}');
      return null;
    }

    final corpo = json.decode(resposta.body);
    final dados = corpo is Map ? corpo['dados'] : null;
    if (dados is! List) return null;

    final mapa = <String, Map<String, String>>{};
    for (final item in dados) {
      if (item is! Map) continue;
      final uuid = (item['uuid']?.toString() ?? '').trim();
      if (uuid.isEmpty) continue;
      mapa[uuid] = {
        'foto': (item['foto']?.toString() ?? '').trim(),
        'foto_url': (item['foto_url']?.toString() ?? '').trim(),
      };
    }
    return mapa;
  } catch (e) {
    debugPrint('ensureObrasFotosLocais: $e');
    return null;
  }
}

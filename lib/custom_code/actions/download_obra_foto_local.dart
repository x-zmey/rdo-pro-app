import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '/backend/sqlite/sqlite_manager.dart';
import 'obra_foto_url.dart';

/// Baixa a foto da obra para o armazenamento local e grava o caminho em
/// [obras.foto_local].
///
/// - [foto] permanece com o path relativo do S3 (sincronizado com o servidor).
/// - [fotoLocal] aponta para o arquivo no dispositivo (uso offline).
///
/// Retorna o caminho local se o download (ou arquivo já existente) estiver ok.
Future<String?> downloadObraFotoLocal({
  required String obraUuid,
  String? fotoServidor,
  String? fotoUrl,
  String? fotoLocalAtual,
}) async {
  final uuid = obraUuid.trim();
  if (uuid.isEmpty) return null;

  final pathServidor = (fotoServidor ?? '').trim();
  final downloadUrl = resolveObraFotoNetworkUrl(
        foto: pathServidor,
        fotoUrl: fotoUrl,
      ) ??
      '';
  if (downloadUrl.isEmpty && pathServidor.isEmpty) {
    await _limparFotoLocal(uuid, fotoLocalAtual);
    return null;
  }

  if (downloadUrl.isEmpty) {
    // Sem URL absoluta não dá para baixar; mantém o local se ainda existir.
    final atual = (fotoLocalAtual ?? '').trim();
    if (atual.isNotEmpty && await File(atual).exists()) return atual;
    return null;
  }

  final atual = (fotoLocalAtual ?? '').trim();
  if (atual.isNotEmpty) {
    final f = File(atual);
    if (await f.exists()) {
      // Mesmo path remoto → não baixa de novo (nome do arquivo inclui hash do path).
      final esperado = await _caminhoLocalEsperado(uuid, pathServidor, downloadUrl);
      if (esperado != null && atual == esperado) {
        return atual;
      }
    }
  }

  try {
    final resp = await http.get(Uri.parse(downloadUrl)).timeout(
          const Duration(seconds: 45),
        );
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      print('❌ Foto obra $uuid: HTTP ${resp.statusCode}');
      return atual.isNotEmpty && await File(atual).exists() ? atual : null;
    }
    if (resp.bodyBytes.isEmpty) return null;

    final destino =
        await _caminhoLocalEsperado(uuid, pathServidor, downloadUrl);
    if (destino == null) return null;

    final file = File(destino);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(resp.bodyBytes, flush: true);

    if (atual.isNotEmpty && atual != destino) {
      try {
        final antigo = File(atual);
        if (await antigo.exists()) await antigo.delete();
      } catch (_) {}
    }

    final db = await SQLiteManager.instance.database;
    await db.update(
      'obras',
      {'foto_local': destino},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
    return destino;
  } catch (e) {
    print('❌ Erro ao baixar foto da obra $uuid: $e');
    return atual.isNotEmpty && await File(atual).exists() ? atual : null;
  }
}

Future<void> _limparFotoLocal(String uuid, String? fotoLocalAtual) async {
  final atual = (fotoLocalAtual ?? '').trim();
  if (atual.isNotEmpty) {
    try {
      final f = File(atual);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
  try {
    final db = await SQLiteManager.instance.database;
    await db.update(
      'obras',
      {'foto_local': null},
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } catch (_) {}
}

Future<String?> _caminhoLocalEsperado(
  String uuid,
  String pathServidor,
  String downloadUrl,
) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final fotosDir = Directory('${dir.path}/fotos_obras');
    if (!await fotosDir.exists()) {
      await fotosDir.create(recursive: true);
    }
    final ext = _extensaoDe(pathServidor.isNotEmpty ? pathServidor : downloadUrl);
    final chave = pathServidor.isNotEmpty
        ? pathServidor.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_')
        : downloadUrl.hashCode.toRadixString(16);
    return '${fotosDir.path}/${uuid}_$chave$ext';
  } catch (_) {
    return null;
  }
}

String _extensaoDe(String pathOrUrl) {
  final limpo = pathOrUrl.split('?').first;
  final ponto = limpo.lastIndexOf('.');
  if (ponto < 0 || ponto >= limpo.length - 1) return '.jpg';
  final ext = limpo.substring(ponto).toLowerCase();
  if (ext.length > 5) return '.jpg';
  if (!RegExp(r'^\.[a-z0-9]+$').hasMatch(ext)) return '.jpg';
  return ext;
}

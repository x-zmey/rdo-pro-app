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

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '/backend/api_requests/api_config.dart';
import 'checklist_complementos.dart';

bool _isHttpUrl(String value) {
  final v = value.toLowerCase().trim();
  return v.startsWith('http://') || v.startsWith('https://');
}

bool _anexoJaNoServidor(Map anexo) {
  if (anexo['local'] == true || anexo['local'] == 1 || anexo['local'] == '1') {
    return false;
  }
  final url = (anexo['url'] ?? '').toString().trim();
  if (_isHttpUrl(url)) return true;
  final path = checklistPathAnexo(anexo);
  if (_isHttpUrl(path)) return true;
  // path S3 relativo sem file local
  if (path.isNotEmpty &&
      !path.startsWith('/') &&
      !path.contains(':\\') &&
      !File(path).existsSync()) {
    return true;
  }
  return false;
}

Future<Map<String, dynamic>?> uploadChecklistAnexoLocal({
  required String localPath,
  required String token,
  String destino = 'checklists/respostas',
}) async {
  final resolved = localPath.replaceFirst(RegExp(r'^file://'), '').trim();
  if (resolved.isEmpty) return null;
  final file = File(resolved);
  if (!await file.exists()) return null;

  final uri = Uri.parse(
    '$kApiBaseUrl/api/v1/sync/checklists-preenchidos/anexos/upload'.trim(),
  );
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $token';
  req.headers['Accept'] = 'application/json';
  req.fields['destino'] = destino;
  req.files.add(
    await http.MultipartFile.fromPath(
      'arquivo',
      resolved,
      filename: p.basename(resolved),
    ),
  );

  final streamed = await req.send();
  final body = await streamed.stream.bytesToString();
  if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
    print('❌ upload anexo checklist HTTP ${streamed.statusCode}: $body');
    return null;
  }
  final decoded = json.decode(body);
  if (decoded is! Map || decoded['status'] != 'ok') {
    print('❌ upload anexo checklist resposta: $body');
    return null;
  }
  final anexo = decoded['anexo'];
  if (anexo is! Map) return null;
  return Map<String, dynamic>.from(anexo);
}

Future<List<Map<String, dynamic>>> uploadListaAnexosLocais({
  required List<Map<String, dynamic>> anexos,
  required String token,
  required String destino,
}) async {
  final out = <Map<String, dynamic>>[];
  for (final raw in anexos) {
    final a = Map<String, dynamic>.from(raw);
    if (_anexoJaNoServidor(a)) {
      a['local'] = false;
      out.add(a);
      continue;
    }
    final localPath = checklistPathAnexo(a);
    if (localPath.isEmpty || _isHttpUrl(localPath)) {
      out.add(a);
      continue;
    }
    final uploaded = await uploadChecklistAnexoLocal(
      localPath: localPath,
      token: token,
      destino: destino,
    );
    if (uploaded == null) {
      // Mantém local para retry na próxima sync
      a['local'] = true;
      a['sync_pending'] = true;
      out.add(a);
      continue;
    }
    out.add({
      ...a,
      ...uploaded,
      'local': false,
      'sync_pending': false,
      // preserva path local se ainda existir (cache offline)
      'caminho_local': localPath,
    });
  }
  return out;
}

/// Reescreve anexos locais em `json_respostas` (áreas/itens + planos embutidos).
Future<Map<String, dynamic>> rewriteChecklistRespostasAnexos({
  required Map<String, dynamic> respostas,
  required String token,
}) async {
  final areas = respostas['areas'];
  if (areas is! List) return respostas;

  for (var ai = 0; ai < areas.length; ai++) {
    final area = areas[ai];
    if (area is! Map) continue;
    final items = area['items'];
    if (items is! List) continue;
    for (var ii = 0; ii < items.length; ii++) {
      final item = items[ii];
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);

      for (final key in [
        'anexos',
        'anexosComplementares',
        'anexosComplementaresOpcao',
      ]) {
        final list = checklistListaAnexos(map[key]);
        if (list.isEmpty) continue;
        final destino = key == 'anexos'
            ? 'checklists/respostas'
            : 'checklists/complementos';
        map[key] = await uploadListaAnexosLocais(
          anexos: list,
          token: token,
          destino: destino,
        );
      }

      for (final planoKey in ['planoAcao', 'planoAcaoOpcao']) {
        final plano = map[planoKey];
        if (plano is! Map) continue;
        final planoMap = Map<String, dynamic>.from(plano);
        final list = checklistListaAnexos(planoMap['anexos']);
        if (list.isNotEmpty) {
          planoMap['anexos'] = await uploadListaAnexosLocais(
            anexos: list,
            token: token,
            destino: 'planos-acoes',
          );
        }
        final sol = planoMap['solucao'];
        if (sol is Map) {
          final solMap = Map<String, dynamic>.from(sol);
          final solAnexos = checklistListaAnexos(solMap['anexos']);
          if (solAnexos.isNotEmpty) {
            solMap['anexos'] = await uploadListaAnexosLocais(
              anexos: solAnexos,
              token: token,
              destino: 'planos-acoes/solucoes',
            );
            planoMap['solucao'] = solMap;
          }
        }
        map[planoKey] = planoMap;
      }

      items[ii] = map;
    }
  }
  return respostas;
}

/// Câmera, galeria ou arquivo → path local (mesmo diretório de anexos).
Future<String?> pickChecklistAnexoLocal({
  required BuildContext context,
}) async {
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tirar foto'),
            onTap: () => Navigator.pop(ctx, 'camera'),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Escolher da galeria'),
            onTap: () => Navigator.pop(ctx, 'gallery'),
          ),
          ListTile(
            leading: const Icon(Icons.attach_file),
            title: const Text('Arquivo (PDF/imagem)'),
            onTap: () => Navigator.pop(ctx, 'file'),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('Cancelar'),
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    ),
  );

  if (choice == null) return null;
  if (choice == 'file') {
    return pickAndSaveFileLocal();
  }

  final picker = ImagePicker();
  final source =
      choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
  final xfile = await picker.pickImage(
    source: source,
    imageQuality: 85,
    maxWidth: 1920,
  );
  if (xfile == null) return null;

  final appDocDir = await getApplicationDocumentsDirectory();
  final anexosDir = Directory('${appDocDir.path}/anexos');
  if (!await anexosDir.exists()) {
    await anexosDir.create(recursive: true);
  }
  final name =
      '${DateTime.now().millisecondsSinceEpoch}_${p.basename(xfile.path)}';
  final dest = '${anexosDir.path}/$name';
  await File(xfile.path).copy(dest);
  return dest;
}

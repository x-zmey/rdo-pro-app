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

import '/backend/sqlite/situacao_soft_delete.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:io';
import 'dart:math';

String _generateUuid() {
  final random = Random();
  const hexDigits = '0123456789abcdef';
  String part(int length) {
    return List.generate(length, (_) => hexDigits[random.nextInt(16)]).join();
  }

  return '${part(8)}-${part(4)}-4${part(3)}-${part(4)}-${part(12)}';
}

Future<bool> _tabelaTemColuna(Database db, String tabela, String coluna) async {
  final rows = await db.rawQuery('PRAGMA table_info($tabela)');
  for (final r in rows) {
    if (r['name'] == coluna) return true;
  }
  return false;
}

/// `dd/MM/aaaa HH:mm:ss` (padrão Brasil, compatível com o parse no servidor).
String _dataHoraAgoraFormatoBrasileiro() {
  final n = DateTime.now();
  String z(int v) => v < 10 ? '0$v' : '$v';
  return '${z(n.day)}/${z(n.month)}/${n.year} ${z(n.hour)}:${z(n.minute)}:${z(n.second)}';
}

/// Tenta obter posição GPS (mesma regra para todas as fotos do lote).
///
/// Usa precisão baixa + limite de tempo para não travar a UI após a câmera (GPS
/// “frio” ou indoor pode levar dezenas de segundos sem isso).
Future<({String? lat, String? lon})> _tentarObterCoordenadas() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return (lat: null, lon: null);
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
    }
    if (p == LocationPermission.denied ||
        p == LocationPermission.deniedForever) {
      return (lat: null, lon: null);
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 6),
      ),
    );
    return (
      lat: pos.latitude.toString(),
      lon: pos.longitude.toString(),
    );
  } catch (_) {
    return (lat: null, lon: null);
  }
}

/// Nome de arquivo amigável baseado na descrição da atividade (coluna `nome` + arquivo em disco).
String _nomeArquivoPorDescricao(String? descricao, int atividadeId, int indice, int ts) {
  var base = (descricao ?? '').trim();
  if (base.isEmpty) base = 'atividade_$atividadeId';
  base = base
      .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]'), '_')
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'_+'), '_');
  if (base.length > 55) base = base.substring(0, 55);
  if (base.isEmpty) base = 'atividade_$atividadeId';
  return '${base}_${ts}_$indice.jpg';
}

/// Copia [images] para o disco e grava em `relatorio_atividade_fotos`.
/// GPS só quando [capturarGps] (foto da câmera); galeria não anexa coordenadas.
Future<void> _persistirFotosAtividade({
  required List<XFile> images,
  required int atividadeId,
  bool capturarGps = false,
}) async {
  if (images.isEmpty) return;

  final Future<({String? lat, String? lon})>? gpsFuture =
      capturarGps ? _tentarObterCoordenadas() : null;

  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final String fotosDir = '${appDocDir.path}/fotos_atividades';
  final Directory fotosDirectory = Directory(fotosDir);

  if (!await fotosDirectory.exists()) {
    await fotosDirectory.create(recursive: true);
  }

  final database = SQLiteManager.instance.database;

  final atividadeRows = await database.rawQuery(
    'SELECT uuid, descricao, relatorio_id FROM relatorio_atividades WHERE id = ? LIMIT 1',
    [atividadeId],
  );
  if (atividadeRows.isEmpty) {
    throw Exception('Atividade não encontrada (id=$atividadeId).');
  }
  final relatorioIdPai = atividadeRows.first['relatorio_id'] as int?;
  final atividadeUuid = atividadeRows.first['uuid'] as String?;
  if (atividadeUuid == null || atividadeUuid.isEmpty) {
    throw Exception(
      'Atividade sem UUID. Sincronize o relatório antes de anexar fotos.',
    );
  }
  final descricaoAtividade = atividadeRows.first['descricao']?.toString();

  final createdByUuid = FFAppState().creatorUuid.trim();
  if (createdByUuid.isEmpty) {
    throw Exception('Usuário sem UUID (creatorUuid). Faça login novamente.');
  }

  final ts = DateTime.now().millisecondsSinceEpoch;
  final temSituacao =
      await _tabelaTemColuna(database, 'relatorio_atividade_fotos', 'situacao');
  final colLat =
      await _tabelaTemColuna(database, 'relatorio_atividade_fotos', 'latitude');
  final colLng =
      await _tabelaTemColuna(database, 'relatorio_atividade_fotos', 'longitude');
  final colDataHora = await _tabelaTemColuna(
      database, 'relatorio_atividade_fotos', 'data_hora');

  final ({String? lat, String? lon}) gps =
      gpsFuture != null ? await gpsFuture : (lat: null, lon: null);

  for (int i = 0; i < images.length; i++) {
    final XFile image = images[i];
    final String fileName =
        _nomeArquivoPorDescricao(descricaoAtividade, atividadeId, i, ts);
    final String localPath = '$fotosDir/$fileName';

    final File localFile = await File(image.path).copy(localPath);
    final now = DateTime.now().toIso8601String();

    final row = <String, dynamic>{
      'uuid': _generateUuid(),
      'relatorio_atividade_id': atividadeId,
      'relatorio_atividade_uuid': atividadeUuid,
      'nome': fileName,
      'arquivo': localFile.path,
      'created_by': createdByUuid,
      'created_at': now,
      'updated_at': now,
      'synced': 0,
    };
    if (colDataHora) {
      row['data_hora'] = _dataHoraAgoraFormatoBrasileiro();
    }
    // Coordenadas só em fotos da câmera.
    if (capturarGps) {
      if (colLat) {
        row['latitude'] = gps.lat;
      }
      if (colLng) {
        row['longitude'] = gps.lon;
      }
    }
    if (temSituacao) {
      row['situacao'] = kSituacaoAtivo;
    }

    await database.insert('relatorio_atividade_fotos', row);
  }

  final touchedAtUtc = DateTime.now().toUtc().toIso8601String();
  await database.rawUpdate(
    'UPDATE relatorio_atividades SET updated_at = ?, synced = 0 WHERE id = ?',
    [touchedAtUtc, atividadeId],
  );

  if (relatorioIdPai != null) {
    await SQLiteManager.instance.touchRelatorioModificadoLocal(
      relatorioId: relatorioIdPai,
    );
  }
}

/// Anexa fotos à atividade: [useCamera] `false` = várias da galeria; `true` = uma foto pela câmera.
///
/// GPS (latitude/longitude) é capturado **apenas** quando [useCamera] é `true`.
///
/// Parâmetros alinhados ao `FotosAtividadeWidget`: [atividadeId], [userId] (`creatorId`).
Future<void> addFotosAtividade(
  int atividadeId,
  int userId, {
  bool useCamera = false,
}) async {
  try {
    final ImagePicker picker = ImagePicker();
    List<XFile> images = [];

    if (useCamera) {
      final XFile? shot = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (shot == null) return;
      images = [shot];
    } else {
      images = await picker.pickMultiImage(
        imageQuality: 85,
        maxWidth: 4096,
        maxHeight: 4096,
      );
      if (images.isEmpty) return;
    }

    await _persistirFotosAtividade(
      images: images,
      atividadeId: atividadeId,
      capturarGps: useCamera,
    );
  } catch (e) {
    // ignore: avoid_print
    print('Erro ao salvar fotos da atividade: $e');
    throw Exception('Falha ao salvar fotos: $e');
  }
}

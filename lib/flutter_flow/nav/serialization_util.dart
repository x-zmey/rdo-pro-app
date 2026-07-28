import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:from_css_color/from_css_color.dart';

import '/backend/schema/structs/index.dart';

import '/backend/sqlite/queries/sqlite_row.dart';
import '/backend/sqlite/queries/read.dart';
import '../../flutter_flow/lat_lng.dart';
import '../../flutter_flow/place.dart';
import '../../flutter_flow/uploaded_file.dart';

/// SERIALIZATION HELPERS

String dateTimeRangeToString(DateTimeRange dateTimeRange) {
  final startStr = dateTimeRange.start.millisecondsSinceEpoch.toString();
  final endStr = dateTimeRange.end.millisecondsSinceEpoch.toString();
  return '$startStr|$endStr';
}

String placeToString(FFPlace place) => jsonEncode({
      'latLng': place.latLng.serialize(),
      'name': place.name,
      'address': place.address,
      'city': place.city,
      'state': place.state,
      'country': place.country,
      'zipCode': place.zipCode,
    });

String uploadedFileToString(FFUploadedFile uploadedFile) =>
    uploadedFile.serialize();

String? serializeParam(
  dynamic param,
  ParamType paramType, {
  bool isList = false,
}) {
  try {
    if (param == null) {
      return null;
    }
    if (isList) {
      final serializedValues = (param as Iterable)
          .map((p) => serializeParam(p, paramType, isList: false))
          .where((p) => p != null)
          .map((p) => p!)
          .toList();
      return json.encode(serializedValues);
    }
    String? data;
    switch (paramType) {
      case ParamType.int:
        data = param.toString();
      case ParamType.double:
        data = param.toString();
      case ParamType.String:
        data = param;
      case ParamType.bool:
        data = param ? 'true' : 'false';
      case ParamType.DateTime:
        data = (param as DateTime).millisecondsSinceEpoch.toString();
      case ParamType.DateTimeRange:
        data = dateTimeRangeToString(param as DateTimeRange);
      case ParamType.LatLng:
        data = (param as LatLng).serialize();
      case ParamType.Color:
        data = (param as Color).toCssString();
      case ParamType.FFPlace:
        data = placeToString(param as FFPlace);
      case ParamType.FFUploadedFile:
        data = uploadedFileToString(param as FFUploadedFile);
      case ParamType.JSON:
        data = json.encode(param);

      case ParamType.DataStruct:
        data = param is BaseStruct ? param.serialize() : null;

      case ParamType.SqliteRow:
        return json.encode((param as SqliteRow).data);

      default:
        data = null;
    }
    return data;
  } catch (e) {
    print('Error serializing parameter: $e');
    return null;
  }
}

/// END SERIALIZATION HELPERS

/// DESERIALIZATION HELPERS

DateTimeRange? dateTimeRangeFromString(String dateTimeRangeStr) {
  final pieces = dateTimeRangeStr.split('|');
  if (pieces.length != 2) {
    return null;
  }
  return DateTimeRange(
    start: DateTime.fromMillisecondsSinceEpoch(int.parse(pieces.first)),
    end: DateTime.fromMillisecondsSinceEpoch(int.parse(pieces.last)),
  );
}

LatLng? latLngFromString(String? latLngStr) {
  final pieces = latLngStr?.split(',');
  if (pieces == null || pieces.length != 2) {
    return null;
  }
  return LatLng(
    double.parse(pieces.first.trim()),
    double.parse(pieces.last.trim()),
  );
}

FFPlace placeFromString(String placeStr) {
  final serializedData = jsonDecode(placeStr) as Map<String, dynamic>;
  final data = {
    'latLng': serializedData.containsKey('latLng')
        ? latLngFromString(serializedData['latLng'] as String)
        : const LatLng(0.0, 0.0),
    'name': serializedData['name'] ?? '',
    'address': serializedData['address'] ?? '',
    'city': serializedData['city'] ?? '',
    'state': serializedData['state'] ?? '',
    'country': serializedData['country'] ?? '',
    'zipCode': serializedData['zipCode'] ?? '',
  };
  return FFPlace(
    latLng: data['latLng'] as LatLng,
    name: data['name'] as String,
    address: data['address'] as String,
    city: data['city'] as String,
    state: data['state'] as String,
    country: data['country'] as String,
    zipCode: data['zipCode'] as String,
  );
}

FFUploadedFile uploadedFileFromString(String uploadedFileStr) =>
    FFUploadedFile.deserialize(uploadedFileStr);

enum ParamType {
  int,
  double,
  String,
  bool,
  DateTime,
  DateTimeRange,
  LatLng,
  Color,
  FFPlace,
  FFUploadedFile,
  JSON,

  DataStruct,

  SqliteRow,
}

dynamic deserializeParam<T>(
  String? param,
  ParamType paramType,
  bool isList, {
  StructBuilder<T>? structBuilder,
}) {
  try {
    if (param == null) {
      return null;
    }
    if (isList) {
      final paramValues = json.decode(param);
      if (paramValues is! Iterable || paramValues.isEmpty) {
        return null;
      }
      return paramValues
          .where((p) => p is String)
          .map((p) => p as String)
          .map((p) => deserializeParam<T>(
                p,
                paramType,
                false,
                structBuilder: structBuilder,
              ))
          .where((p) => p != null)
          .map((p) => p! as T)
          .toList();
    }
    switch (paramType) {
      case ParamType.int:
        return int.tryParse(param);
      case ParamType.double:
        return double.tryParse(param);
      case ParamType.String:
        return param;
      case ParamType.bool:
        return param == 'true';
      case ParamType.DateTime:
        final milliseconds = int.tryParse(param);
        return milliseconds != null
            ? DateTime.fromMillisecondsSinceEpoch(milliseconds)
            : null;
      case ParamType.DateTimeRange:
        return dateTimeRangeFromString(param);
      case ParamType.LatLng:
        return latLngFromString(param);
      case ParamType.Color:
        return fromCssColor(param);
      case ParamType.FFPlace:
        return placeFromString(param);
      case ParamType.FFUploadedFile:
        return uploadedFileFromString(param);
      case ParamType.JSON:
        return json.decode(param);

      case ParamType.DataStruct:
        final data = json.decode(param) as Map<String, dynamic>? ?? {};
        return structBuilder != null ? structBuilder(data) : null;

      case ParamType.SqliteRow:
        final data = json.decode(param) as Map<String, dynamic>;
        switch (T) {
          case CarregaObrasRow:
            return CarregaObrasRow(data);
          case CarregaPlanosRow:
            return CarregaPlanosRow(data);
          case ObraDetalhesRow:
            return ObraDetalhesRow(data);
          case RelatoriosObraRow:
            return RelatoriosObraRow(data);
          case RelatorioDetalhesRow:
            return RelatorioDetalhesRow(data);
          case ModelosRelatoriosRow:
            return ModelosRelatoriosRow(data);
          case CarregaUltimoRelatorioRow:
            return CarregaUltimoRelatorioRow(data);
          case ListaComentariosRelatoriosRow:
            return ListaComentariosRelatoriosRow(data);
          case CarregaOcorrenciasRelatorioRow:
            return CarregaOcorrenciasRelatorioRow(data);
          case CarregaItensObraRow:
            return CarregaItensObraRow(data);
          case CarregaComentariosObraRow:
            return CarregaComentariosObraRow(data);
          case CarregaOcorrenciasObraRow:
            return CarregaOcorrenciasObraRow(data);
          case ListaEtapasObraRow:
            return ListaEtapasObraRow(data);
          case ListaTarefasEtapasObraRow:
            return ListaTarefasEtapasObraRow(data);
          case UltimosRelatoriosObraRow:
            return UltimosRelatoriosObraRow(data);
          case CarregaAnexosRelatorioRow:
            return CarregaAnexosRelatorioRow(data);
          case EquipamentosRecebidosObraRow:
            return EquipamentosRecebidosObraRow(data);
          case DetalhesMaterialRecebidoRow:
            return DetalhesMaterialRecebidoRow(data);
          case CarregaUltimaAtividadeRelatorioRow:
            return CarregaUltimaAtividadeRelatorioRow(data);
          case GetitensdaobraRow:
            return GetitensdaobraRow(data);
          case GetItensAtividadeRow:
            return GetItensAtividadeRow(data);
          case CarregaFotosAtividadeRow:
            return CarregaFotosAtividadeRow(data);
          case GetFotosAtividadeRow:
            return GetFotosAtividadeRow(data);
          case GetDadosAtividadeRow:
            return GetDadosAtividadeRow(data);
          case GetAtividadesRelatorioRow:
            return GetAtividadesRelatorioRow(data);
          case GetOrdensServicoRow:
            return GetOrdensServicoRow(data);
          case GetTarefasOrdemRow:
            return GetTarefasOrdemRow(data);
          case GetDetalhesTarefaRow:
            return GetDetalhesTarefaRow(data);
          case GetTarefasOrdemDetalhesRow:
            return GetTarefasOrdemDetalhesRow(data);
          case GetGruposObrasRow:
            return GetGruposObrasRow(data);
          case GetClientesRow:
            return GetClientesRow(data);
          case GetModelosChecklistRow:
            return GetModelosChecklistRow(data);
          case GetMaoObraRelatorioRow:
            return GetMaoObraRelatorioRow(data);
          case GetMaoObraRelatorioDetalhesRow:
            return GetMaoObraRelatorioDetalhesRow(data);
          case GetOrdensServicoRelatorioRow:
            return GetOrdensServicoRelatorioRow(data);
          case GetCustosOrdensRelatoriosRow:
            return GetCustosOrdensRelatoriosRow(data);
          case DetalhesComentarioRow:
            return DetalhesComentarioRow(data);
          case DetalhesOcorrenciaRow:
            return DetalhesOcorrenciaRow(data);
          case GetDetalhesItemAtividadeRow:
            return GetDetalhesItemAtividadeRow(data);
          case GetTipoOcorrenciaDetalhesRow:
            return GetTipoOcorrenciaDetalhesRow(data);
          case GetTipoUserDetalhesCopyRow:
            return GetTipoUserDetalhesCopyRow(data);
          case GetStatusRelatorioDetalhesRow:
            return GetStatusRelatorioDetalhesRow(data);
          case GetIdServidorRow:
            return GetIdServidorRow(data);
          case GetEquipamentosRow:
            return GetEquipamentosRow(data);
          case GetInsumosRow:
            return GetInsumosRow(data);
          case GetLocaisRow:
            return GetLocaisRow(data);
          case GetMaoObraRow:
            return GetMaoObraRow(data);
          case GetUsuariosRow:
            return GetUsuariosRow(data);
          case SituacaoObraRow:
            return SituacaoObraRow(data);
          case GetTipoOcorrenciasRow:
            return GetTipoOcorrenciasRow(data);
          case RelatorioDetalhesCopyRow:
            return RelatorioDetalhesCopyRow(data);
          case RelatoriosObraUltimosRow:
            return RelatoriosObraUltimosRow(data);
          case ObraLocaisRow:
            return ObraLocaisRow(data);
          default:
            return null;
        }

      default:
        return null;
    }
  } catch (e) {
    print('Error deserializing parameter: $e');
    return null;
  }
}

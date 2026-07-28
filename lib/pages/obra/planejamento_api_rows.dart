import '/flutter_flow/flutter_flow_util.dart';

double? _asDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _asString(dynamic value) {
  final text = value?.toString();
  if (text == null || text.trim().isEmpty) return null;
  return text;
}

class ListaEtapasObraRow {
  ListaEtapasObraRow({
    required this.uuid,
    this.id,
    this.item,
    this.nome,
    this.total,
    this.porcentagem,
    this.tarefas = const [],
  });

  final int? id;
  final String uuid;
  final String? item;
  final String? nome;
  final double? total;
  final double? porcentagem;
  final List<ListaTarefasEtapasObraRow> tarefas;

  factory ListaEtapasObraRow.fromMap(Map<String, dynamic> map) {
    final uuid = _asString(map['uuid']) ?? _asString(map['id']) ?? '';
    final tarefas = <ListaTarefasEtapasObraRow>[];
    final rawTarefas = map['tarefas'];

    if (rawTarefas is List) {
      for (final raw in rawTarefas) {
        if (raw is Map) {
          tarefas.addAll(
            ListaTarefasEtapasObraRow.fromMapWithFilhos(
              Map<String, dynamic>.from(raw),
            ),
          );
        }
      }
    }

    return ListaEtapasObraRow(
      id: castToType<int>(map['id']),
      uuid: uuid,
      item: _asString(map['item']),
      nome: _asString(map['nome']),
      total: _asDouble(map['total']),
      porcentagem: _asDouble(map['porcentagem']),
      tarefas: tarefas,
    );
  }
}

class ListaTarefasEtapasObraRow {
  ListaTarefasEtapasObraRow({
    required this.uuid,
    this.id,
    this.tarefaPaiUuid,
    this.tipo,
    this.item,
    this.descricao,
    this.qtd,
    this.unidade,
    this.valorUnitario,
    this.meta,
    this.metaUnidade,
    this.porcentagem,
  });

  final int? id;
  final String uuid;
  final String? tarefaPaiUuid;
  final String? tipo;
  final String? item;
  final String? descricao;
  final double? qtd;
  final String? unidade;
  final double? valorUnitario;
  final double? meta;
  final String? metaUnidade;
  final double? porcentagem;

  static List<ListaTarefasEtapasObraRow> fromMapWithFilhos(
    Map<String, dynamic> map, {
    String? parentUuid,
  }) {
    final uuid = _asString(map['uuid']) ?? _asString(map['id']) ?? '';
    final row = ListaTarefasEtapasObraRow(
      id: castToType<int>(map['id']),
      uuid: uuid,
      tarefaPaiUuid: parentUuid ?? _asString(map['tarefa_pai_uuid']),
      tipo: _asString(map['tipo']),
      item: _asString(map['item']),
      descricao: _asString(map['descricao']),
      qtd: _asDouble(map['qtd']),
      unidade: _asString(map['unidade']),
      valorUnitario: _asDouble(map['valor_unitario']),
      meta: _asDouble(map['meta']),
      metaUnidade: _asString(map['meta_unidade']),
      porcentagem: _asDouble(map['porcentagem']),
    );
    final rows = <ListaTarefasEtapasObraRow>[row];
    final filhos = map['filhos'];

    if (filhos is List) {
      for (final raw in filhos) {
        if (raw is Map) {
          rows.addAll(
            ListaTarefasEtapasObraRow.fromMapWithFilhos(
              Map<String, dynamic>.from(raw),
              parentUuid: uuid,
            ),
          );
        }
      }
    }

    return rows;
  }
}

List<ListaEtapasObraRow> parseEtapasPlanejamento(dynamic body) {
  final raw = body is Map ? body['etapasResult'] : null;
  if (raw is! List) return [];

  return raw
      .whereType<Map>()
      .map((e) => ListaEtapasObraRow.fromMap(Map<String, dynamic>.from(e)))
      .toList();
}

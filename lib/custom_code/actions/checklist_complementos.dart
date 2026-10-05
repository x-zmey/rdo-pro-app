import 'dart:io';

import 'package:path/path.dart' as p;

/// Requisitos ativos da opção/emoji selecionada no item.
Map<String, dynamic> checklistRequisitosAtivos(Map item) {
  final tipo = (item['type'] ?? '').toString().toLowerCase();

  if (tipo.contains('emoji')) {
    final valor = (item['respostaEmoji'] ?? '').toString();
    final opcoes = item['emojiRatingOptions'] as List? ?? [];
    for (final op in opcoes) {
      if (op is Map && op['valor']?.toString() == valor) {
        final r = op['requisitos'];
        if (r is Map) return Map<String, dynamic>.from(r);
      }
    }
  }

  if (tipo.contains('opç') || tipo.contains('opc')) {
    final valor = (item['respostaOpcao'] ?? '').toString();
    final opcoes = item['options'] as List? ?? [];
    for (final op in opcoes) {
      if (op is! Map) continue;
      final match = op['valor']?.toString() == valor ||
          op['label']?.toString() == valor ||
          op['texto']?.toString() == valor ||
          op['name']?.toString() == valor;
      if (match) {
        final r = op['requisitos'];
        if (r is Map) return Map<String, dynamic>.from(r);
      }
    }
  }

  if ((tipo.contains('sim') && tipo.contains('não')) ||
      (tipo.contains('sim') && tipo.contains('nao'))) {
    final raw = item['respostaBoolean'];
    bool? v;
    if (raw is bool) {
      v = raw;
    } else if (raw != null) {
      v = raw.toString() == 'true' || raw.toString() == '1';
    }
    if (v == true) {
      final r = item['requisitosSim'] ?? item['requisitos_sim'];
      if (r is Map) return Map<String, dynamic>.from(r);
    }
    if (v == false) {
      final r = item['requisitosNao'] ?? item['requisitos_nao'];
      if (r is Map) return Map<String, dynamic>.from(r);
    }
  }

  return {};
}

bool _flagTrue(dynamic v) => v == true || v == 1 || v == '1' || v == 'true';

/// Exige complemento (bloqueia finalizar se faltar).
bool checklistExigeComplemento(Map item, String key) {
  final c = item['complementos'];
  if (c is Map && _flagTrue(c[key])) return true;
  final req = checklistRequisitosAtivos(item);
  if (_flagTrue(req[key])) return true;
  if (key == 'plano_acao' && _flagTrue(item['precisa_plano_acao'])) return true;
  return false;
}

/// Exibe botão/seção de complemento.
/// Templates sem `complementos` (legado): mostra tudo como opcional.
bool checklistMostraComplemento(Map item, String key) {
  final c = item['complementos'];
  if (c == null) return true;
  return checklistExigeComplemento(item, key);
}

List<Map<String, dynamic>> checklistListaAnexos(dynamic raw) {
  if (raw is! List) return [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}

Map<String, dynamic> checklistAnexoFromLocalPath(String localPath) {
  final name = p.basename(localPath);
  final ext = p.extension(localPath).replaceFirst('.', '').toLowerCase();
  return {
    'path': localPath,
    'caminho': localPath,
    'nome': name,
    'name': name,
    'local': true,
    'tipo': ext,
    'mime': ext == 'pdf'
        ? 'application/pdf'
        : (ext == 'png' ? 'image/png' : 'image/jpeg'),
    'size': () {
      try {
        return File(localPath).lengthSync();
      } catch (_) {
        return null;
      }
    }(),
  };
}

String checklistNomeAnexo(Map anexo) {
  final n = (anexo['nome'] ?? anexo['name'] ?? anexo['path'] ?? anexo['caminho'] ?? '')
      .toString()
      .trim();
  if (n.isEmpty) return 'Arquivo';
  return p.basename(n);
}

String checklistPathAnexo(Map anexo) {
  return (anexo['path'] ?? anexo['caminho'] ?? anexo['url'] ?? '').toString();
}

bool checklistComentarioPreenchido(Map item) {
  final a = (item['respostaComentario'] ?? item['comentario'] ?? '')
      .toString()
      .trim();
  return a.isNotEmpty;
}

bool checklistPlanoPreenchido(Map item) {
  final plano = item['planoAcao'];
  if (plano is! Map) return false;
  return (plano['descricao'] ?? '').toString().trim().isNotEmpty;
}

bool checklistAnexosComplementaresPreenchidos(Map item) {
  return checklistListaAnexos(item['anexosComplementares']).isNotEmpty;
}

bool checklistAnexosRespostaPreenchidos(Map item) {
  return checklistListaAnexos(item['anexos']).isNotEmpty;
}

/// Retorna lista de pendências de complementos obrigatórios do item.
List<String> checklistPendenciasComplementos(Map item) {
  final out = <String>[];
  if (checklistExigeComplemento(item, 'comentario') &&
      !checklistComentarioPreenchido(item)) {
    out.add('comentário');
  }
  if (checklistExigeComplemento(item, 'plano_acao') &&
      !checklistPlanoPreenchido(item)) {
    out.add('plano de ação');
  }
  if (checklistExigeComplemento(item, 'anexo') &&
      !checklistAnexosComplementaresPreenchidos(item)) {
    out.add('anexo');
  }
  return out;
}

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
import 'dart:math';

Future<String> iniciarNovoChecklist(
  int templateId,
  int obraId,
  int usuarioId,
) async {
  print('👤 Template ID: $templateId');
  print('🏗️ Obra ID: $obraId');
  print('👤 Usuário ID: $usuarioId');

  try {
    final db = await SQLiteManager.instance.database;

    // Buscar template do SQLite
    final templates = await db.query(
      'checklists_templates',
      where: 'id = ?',
      whereArgs: [templateId],
    );

    print('📋 Templates encontrados: ${templates.length}');

    if (templates.isEmpty) {
      throw Exception('Template de checklist não encontrado');
    }

    final template = templates.first;

    // VERIFICAR OS CAMPOS EXISTENTES
    print('🔍 Campos do template: ${template.keys}');
    print('🔍 Template completo: $template');

    // O campo correto é json_config, não json_template!
    final templateJson = template['json_config'] as String?;

    if (templateJson == null) {
      throw Exception('Campo json_config não encontrado ou está nulo');
    }

    print('📄 JSON do template: $templateJson');

    final templateData = json.decode(templateJson);

    // Validar estrutura do template
    if (templateData['areas'] == null) {
      throw Exception('Template sem áreas definidas');
    }

    // Criar estrutura com respostas vazias
    final checklistComRespostas = _inicializarRespostas(templateData);

    // Gerar UUID único
    final uuid = _generateUuid();

    // Criar objeto de resultado
    final resultado = {
      'uuid': uuid,
      'template_data': checklistComRespostas,
      'template_id': templateId,
      'obra_id': obraId,
      'usuario_id': usuarioId,
      'template_name': template['nome'] ?? 'Checklist sem nome',
      'template_descricao': template['descricao'] ?? '',
      'status': 'rascunho',
      'data_criacao': DateTime.now().toIso8601String(),
      'versao_template': templateData['versao'] ?? '1.0',
    };

    // Converter para JSON string
    final resultadoJson = json.encode(resultado);

    print('✅ Novo checklist iniciado: ${template['nome']}');
    print('📝 UUID: $uuid');
    print('🏗️ Obra ID: $obraId');
    print('👤 Usuário ID: $usuarioId');

    return resultadoJson;
  } catch (e) {
    print('❌ Erro ao iniciar checklist: $e');

    // Retornar erro como JSON string também
    final erro = {
      'erro': true,
      'mensagem': e.toString(),
      'template_id': templateId,
      'obra_id': obraId,
    };

    return json.encode(erro);
  }
}

Map<String, dynamic> _inicializarRespostas(Map<String, dynamic> template) {
  try {
    final areas = template['areas'] as List;

    // Copiar o template para não modificar o original
    final templateComRespostas = Map<String, dynamic>.from(template);

    // Processar cada área
    final novasAreas = areas.map<Map<String, dynamic>>((area) {
      final areaMap = Map<String, dynamic>.from(area);
      final items = areaMap['items'] as List? ?? [];

      // Processar cada item da área
      final novosItems = items.map<Map<String, dynamic>>((item) {
        final itemMap = Map<String, dynamic>.from(item);
        final tipo = itemMap['type'] as String? ?? '';
        final id = itemMap['id']?.toString() ?? 'sem-id';

        print('🔄 Inicializando item: $id - Tipo: $tipo');

        // Adicionar campos de resposta baseado no tipo
        switch (tipo) {
          case 'Avaliativo Sim/Não':
            itemMap['respostaBoolean'] = null;
            itemMap['anexosComplementares'] = [];
            itemMap['anexosComplementaresOpcao'] = [];
            itemMap['comentario'] = null;
            break;

          case 'Avaliativo Emojis':
            itemMap['respostaEmoji'] = null;
            itemMap['comentario'] = null;
            break;

          case 'Texto longo':
            itemMap['respostaTexto'] = null;
            itemMap['comentario'] = null;
            break;

          case 'Data':
            itemMap['respostaData'] = null;
            itemMap['comentario'] = null;
            break;

          case 'Número':
            itemMap['respostaNumero'] = null;
            itemMap['comentario'] = null;
            break;

          case 'Opções':
            itemMap['respostaOpcao'] = null;
            itemMap['anexosComplementares'] = [];
            itemMap['comentario'] = null;
            break;

          default:
            // Para tipos desconhecidos, usar campo genérico
            itemMap['resposta'] = null;
            itemMap['comentario'] = null;
            print('⚠️ Tipo desconhecido: $tipo - usando resposta genérica');
        }

        return itemMap;
      }).toList();

      areaMap['items'] = novosItems;
      return areaMap;
    }).toList();

    templateComRespostas['areas'] = novasAreas;

    // Adicionar campos gerais do checklist
    templateComRespostas['comentario_geral'] = null;
    templateComRespostas['assinatura'] = null;
    templateComRespostas['anexos_gerais'] = [];
    templateComRespostas['data_inicio_preenchimento'] =
        DateTime.now().toIso8601String();

    print('✅ Template inicializado com ${novasAreas.length} áreas');

    return templateComRespostas;
  } catch (e) {
    print('❌ Erro ao inicializar respostas: $e');
    return template; // Retornar template original em caso de erro
  }
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

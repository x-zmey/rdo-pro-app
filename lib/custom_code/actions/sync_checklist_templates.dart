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

import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

// ===== FUNÇÕES UTILITÁRIAS =====

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
  } catch (e) {
    // Ignora erro de duplicidade (UNIQUE constraint)
    if (!e.toString().contains('UNIQUE constraint')) {
      print('❌ Erro ao salvar mapeamento: $e');
    }
  }
}

Future<int?> _getIdLocalPorIdServidor(String tabela, int idServidor) async {
  final db = await SQLiteManager.instance.database;

  try {
    // 1. Buscar UUID no mapeamento
    final mapeamento = await db.query(
      'sync_id_mapping',
      where: 'tabela = ? AND id_servidor = ?',
      whereArgs: [tabela, idServidor],
    );

    if (mapeamento.isEmpty) return null;

    final uuid = mapeamento.first['uuid'] as String;

    // 2. Buscar ID local pelo UUID
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

  final registro = await db.query(
    tabela,
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

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

String _converterJsonParaString(dynamic jsonConfig) {
  if (jsonConfig == null) return '{}';
  if (jsonConfig is String) {
    // Se já é string, retorna como está
    return jsonConfig;
  }
  // Se é objeto, converte para JSON string
  return json.encode(jsonConfig);
}

int _converterBoolParaInt(dynamic valor) {
  if (valor == null) return 0;
  if (valor is bool) return valor ? 1 : 0;
  if (valor is int) return valor;
  return 0;
}

// ===== FUNÇÃO PRINCIPAL =====

Future syncChecklistTemplates() async {
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

    int downloadedCount = 0;
    int templateObrasCount = 0;

    // ===== 1. DOWNLOAD - CATEGORIAS =====
    try {
      final lastSync = await _getUltimaSync('checklists_template_categorias');
      print('📥 Buscando categorias desde: $lastSync');

      final response = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/checklists/categorias/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final categorias = result['dados'] as List;

        print('📥 Recebidas ${categorias.length} categorias');

        for (var catServer in categorias) {
          await _processarCategoria(catServer, result['server_time']);
        }

        // Atualizar last_sync_date
        if (categorias.isNotEmpty) {
          await db.update(
            'checklists_template_categorias',
            {'last_sync_date': result['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download categorias concluído');
      } else {
        print('❌ Erro categorias: ${response.statusCode}');
        return;
      }
    } catch (e) {
      print('❌ Erro no download categorias: $e');
      _updateSyncStatus(false, 'Erro no download categorias: $e', 0, 0);
      return;
    }

    // ===== 2. DOWNLOAD - TEMPLATES =====
    try {
      final lastSync = await _getUltimaSync('checklists_templates');
      print('📥 Buscando templates desde: $lastSync');

      final response = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/checklists/templates/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final templates = result['dados'] as List;

        print('📥 Recebidos ${templates.length} templates');

        for (var templateServer in templates) {
          await _processarTemplate(templateServer, result['server_time']);
          downloadedCount++;
        }

        // Atualizar last_sync_date
        if (templates.isNotEmpty) {
          await db.update(
            'checklists_templates',
            {'last_sync_date': result['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print('✅ Download templates concluído: $downloadedCount templates');
      } else {
        print('❌ Erro templates: ${response.statusCode}');
        return;
      }
    } catch (e) {
      print('❌ Erro no download templates: $e');
      _updateSyncStatus(false, 'Erro no download templates: $e', 0, 0);
      return;
    }

    // ===== 3. DOWNLOAD - TEMPLATE_OBRAS =====
    try {
      final lastSync = await _getUltimaSync('checklists_template_obras');
      print('📥 Buscando template_obras desde: $lastSync');

      final response = await http.post(
        Uri.parse(
            'https://api.rdopro.com.br/api/v1/sync/checklists/template-obras/download'),
        headers: headers,
        body: json.encode({'ultima_sync': lastSync}),
      );

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        final templateObras = result['dados'] as List;

        print(
            '📥 Recebidas ${templateObras.length} vinculações template-obras');

        for (var templateObraServer in templateObras) {
          await _processarTemplateObra(
              templateObraServer, result['server_time']);
          templateObrasCount++;
        }

        // Atualizar last_sync_date
        if (templateObras.isNotEmpty) {
          await db.update(
            'checklists_template_obras',
            {'last_sync_date': result['server_time']},
            where: 'synced = ?',
            whereArgs: [1],
          );
        }
        print(
            '✅ Download template_obras concluído: $templateObrasCount vinculações');
      } else {
        print('❌ Erro template_obras: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Erro no download template_obras: $e');
    }

    // ===== 4. SUCESSO =====
    _updateSyncStatus(
      true,
      'Download checklists concluído: ↓$downloadedCount templates, ↓$templateObrasCount vinculações',
      0,
      downloadedCount + templateObrasCount,
    );
    print('🎉 Download checklists concluído com sucesso!');
  } catch (e) {
    print('❌ Erro geral download checklists: $e');
    _updateSyncStatus(false, 'Erro geral download checklists: $e', 0, 0);
  }
}

// ===== FUNÇÕES DE PROCESSAMENTO =====

Future<void> _processarCategoria(
    Map<String, dynamic> catServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = catServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (catServer['id'] != null) {
    await _salvarMapeamento(
        'checklists_template_categorias', catServer['id'] as int, uuid);
  }

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'checklists_template_categorias',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'checklists_template_categorias',
      {
        'nome': catServer['nome'],
        'cor': catServer['cor'],
        'created_by': catServer['created_by'],
        'situacao': catServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': catServer['created_at'],
        'updated_at': catServer['updated_at'],
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert(
      'checklists_template_categorias',
      {
        'uuid': uuid,
        'nome': catServer['nome'],
        'cor': catServer['cor'],
        'created_by': catServer['created_by'],
        'situacao': catServer['situacao'],
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': catServer['created_at'],
        'updated_at': catServer['updated_at'],
      },
    );
  }
}

Future<void> _processarTemplate(
    Map<String, dynamic> templateServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  String uuid = templateServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (templateServer['id'] != null) {
    await _salvarMapeamento(
        'checklists_templates', templateServer['id'] as int, uuid);
  }

  // BUSCAR CATEGORIA_ID LOCAL
  int? categoriaIdLocal;
  if (templateServer['categoria_id'] != null) {
    categoriaIdLocal = await _getIdLocalPorIdServidor(
      'checklists_template_categorias',
      templateServer['categoria_id'] as int,
    );
    if (categoriaIdLocal == null) {
      print('⚠️ Categoria não mapeada: ${templateServer['categoria_id']}');
    }
  }

  // CONVERTER CAMPOS (USANDO FUNÇÕES UTILITÁRIAS)
  String jsonConfigString =
      _converterJsonParaString(templateServer['json_config']);
  int isModelo = _converterBoolParaInt(templateServer['is_modelo']);

  // VERIFICAR SE EXISTE
  final existe = await db.query(
    'checklists_templates',
    where: 'uuid = ?',
    whereArgs: [uuid],
  );

  print('🔍 jsonConfig tipo: ${templateServer['json_config'].runtimeType}');
  print('🔍 jsonConfig conteúdo: ${templateServer['json_config']}');
  print('🔍 jsonConfigString após conversão: $jsonConfigString');

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'checklists_templates',
      {
        'nome': templateServer['nome']?.toString() ?? '',
        'descricao': templateServer['descricao']?.toString(),
        'categoria_id': categoriaIdLocal,
        'json_config': jsonConfigString,
        'is_modelo': isModelo,
        'created_by': templateServer['created_by'],
        'versao': templateServer['versao'] ?? 1,
        'status': templateServer['status']?.toString() ?? 'ativo',
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': templateServer['created_at']?.toString(),
        'updated_at': templateServer['updated_at']?.toString(),
      },
      where: 'uuid = ?',
      whereArgs: [uuid],
    );
  } else {
    // INSERT
    await db.insert(
      'checklists_templates',
      {
        'uuid': uuid,
        'nome': templateServer['nome']?.toString() ?? '',
        'descricao': templateServer['descricao']?.toString(),
        'categoria_id': categoriaIdLocal,
        'json_config': jsonConfigString,
        'is_modelo': isModelo,
        'created_by': templateServer['created_by'],
        'versao': templateServer['versao'] ?? 1,
        'status': templateServer['status']?.toString() ?? 'ativo',
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': templateServer['created_at']?.toString(),
        'updated_at': templateServer['updated_at']?.toString(),
      },
    );
  }
}

Future<void> _processarTemplateObra(
    Map<String, dynamic> templateObraServer, String serverTime) async {
  final db = await SQLiteManager.instance.database;

  // GERAR UUID (já que a tabela principal não tem UUID)
  String uuid = templateObraServer['uuid'] ?? _generateUuid();

  // SALVAR MAPEAMENTO (ID servidor → UUID)
  if (templateObraServer['id'] != null) {
    await _salvarMapeamento(
        'checklists_template_obras', templateObraServer['id'] as int, uuid);
  }

  // ✅ USA UUIDs DIRETOS (MAIS SIMPLES E RÁPIDO)
  int? templateIdLocal;
  if (templateObraServer['checklist_template_uuid'] != null) {
    // Busca ID local DIRETAMENTE pelo UUID do template
    templateIdLocal = await _getIdLocalPorUuid(
      'checklists_templates',
      templateObraServer['checklist_template_uuid'] as String,
    );
    if (templateIdLocal == null) {
      print(
          '⚠️ Template não encontrado pelo UUID: ${templateObraServer['checklist_template_uuid']}');
      return;
    }
  }

  int? obraIdLocal;
  if (templateObraServer['obra_uuid'] != null) {
    // Busca ID local DIRETAMENTE pelo UUID da obra
    obraIdLocal = await _getIdLocalPorUuid(
      'obras',
      templateObraServer['obra_uuid'] as String,
    );
    if (obraIdLocal == null) {
      print(
          '⚠️ Obra não encontrada pelo UUID: ${templateObraServer['obra_uuid']}');
      return;
    }
  }

  // VERIFICAR SE EXISTE (por UUID ou pelas chaves únicas)
  final existe = await db.query(
    'checklists_template_obras',
    where: 'uuid = ? OR (checklist_template_id = ? AND obra_id = ?)',
    whereArgs: [uuid, templateIdLocal, obraIdLocal],
  );

  if (existe.isNotEmpty) {
    // UPDATE
    await db.update(
      'checklists_template_obras',
      {
        'checklist_template_id': templateIdLocal,
        'obra_id': obraIdLocal,
        'synced': 1,
        'last_sync_date': serverTime,
        'updated_at': templateObraServer['updated_at']?.toString(),
      },
      where: 'id = ?',
      whereArgs: [existe.first['id']],
    );
    print(
        '🔄 Template-Obra atualizado: Template $templateIdLocal ↔ Obra $obraIdLocal');
  } else {
    // INSERT
    await db.insert(
      'checklists_template_obras',
      {
        'uuid': uuid,
        'checklist_template_id': templateIdLocal,
        'obra_id': obraIdLocal,
        'synced': 1,
        'last_sync_date': serverTime,
        'created_at': templateObraServer['created_at']?.toString(),
        'updated_at': templateObraServer['updated_at']?.toString(),
      },
    );
    print(
        '✅ Nova vinculação Template-Obra: Template $templateIdLocal ↔ Obra $obraIdLocal');
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

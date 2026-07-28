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

// essa ação é para fazer upload de um arquivo podendo ser foto ou pdf que vai ser armazenado de forma local e quero que o caminho dele retorne para eu poder salvar no banco de dados
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

Future<String?> pickAndSaveFileLocal() async {
  try {
    // Permite selecionar arquivos PDF e imagens
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: false,
    );

    if (result != null && result.files.single.path != null) {
      File selectedFile = File(result.files.single.path!);

      // Obtém o diretório de documentos da aplicação
      Directory appDocDir = await getApplicationDocumentsDirectory();

      // Cria um diretório específico para anexos se não existir
      Directory anexosDir = Directory('${appDocDir.path}/anexos');
      if (!await anexosDir.exists()) {
        await anexosDir.create(recursive: true);
      }

      // Gera um nome único para o arquivo usando timestamp
      String fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${result.files.single.name}';
      String localPath = '${anexosDir.path}/$fileName';

      // Copia o arquivo para o diretório local
      File localFile = await selectedFile.copy(localPath);

      // Retorna o caminho do arquivo salvo localmente
      return localFile.path;
    }

    return null;
  } catch (e) {
    print('Erro ao selecionar e salvar arquivo: $e');
    return null;
  }
}

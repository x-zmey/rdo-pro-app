import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import 'package:flutter/material.dart';

const String kMensagemCadastroObraSemRede =
    'Cadastrar itens na obra exige conexão com a internet. '
    'Conecte-se à rede e tente novamente.';

/// Retorna `true` se há rede; exibe aviso e retorna `false` se offline.
Future<bool> garantirInternetParaCadastroObra(BuildContext context) async {
  final online = await actions.checkInternetConnection();
  if (!online && context.mounted) {
    final theme = FlutterFlowTheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          kMensagemCadastroObraSemRede,
          style: TextStyle(color: theme.primaryText),
        ),
        duration: const Duration(milliseconds: 4500),
        backgroundColor: theme.error,
      ),
    );
  }
  return online;
}

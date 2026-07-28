import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'obra_add_etapa_model.dart';
export 'obra_add_etapa_model.dart';

/// Cadastro de etapa na API (`POST .../add-etapa`) e sync `obra_etapas`.
class ObraAddEtapaWidget extends StatefulWidget {
  const ObraAddEtapaWidget({
    super.key,
    required this.obraServidorId,
    required this.obraUuid,
    this.obraId,
  });

  final int obraServidorId;
  final String obraUuid;
  final int? obraId;

  static String routeName = 'obraAddEtapa';
  static String routePath = '/obraAddEtapa';

  @override
  State<ObraAddEtapaWidget> createState() => _ObraAddEtapaWidgetState();
}

class _ObraAddEtapaWidgetState extends State<ObraAddEtapaWidget> {
  late ObraAddEtapaModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ObraAddEtapaModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('create_tarefas')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para criar tarefas.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
      }
    });
    _model.itemTextController ??= TextEditingController();
    _model.itemFocusNode ??= FocusNode();
    _model.nomeTextController ??= TextEditingController();
    _model.nomeFocusNode ??= FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregarProximoItem());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _proximoItemApartirDaLista(List<dynamic> etapas) {
    if (etapas.isEmpty) return '1';
    Map<String, dynamic>? last;
    var maxId = -1;
    for (final e in etapas) {
      if (e is! Map) continue;
      final id = (e['id'] as num?)?.toInt() ?? -1;
      if (id > maxId) {
        maxId = id;
        last = Map<String, dynamic>.from(e);
      }
    }
    final it = last?['item']?.toString().trim() ?? '';
    if (it.isEmpty) return '1';
    final simple = int.tryParse(it);
    if (simple != null) return '${simple + 1}';
    final parts = it.split('.');
    if (parts.isEmpty) return '1';
    final lastPart = int.tryParse(parts.last) ?? 0;
    parts[parts.length - 1] = '${lastPart + 1}';
    return parts.join('.');
  }

  Future<void> _carregarProximoItem() async {
    final token = FFAppState().UserToken;
    if (token.isEmpty) return;
    final resp = await ListarEtapasObraApiCall.call(
      token: token,
      obraServidorId: widget.obraServidorId,
      obraUuid: widget.obraUuid,
    );
    if (!mounted) return;
    if (resp.statusCode == 200 && resp.jsonBody is Map) {
      final list = (resp.jsonBody as Map)['etapasResult'] as List?;
      if (list != null) {
        safeSetState(() {
          _model.itemTextController?.text = _proximoItemApartirDaLista(list);
        });
        return;
      }
    }
    safeSetState(() {
      _model.itemTextController?.text = '1';
    });
  }

  Future<void> _salvar() async {
    if (_model.salvando) return;
    if (_model.formKey.currentState?.validate() != true) return;
    final token = FFAppState().UserToken;
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Faça login novamente.',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).primaryText)),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    final item = _model.itemTextController?.text.trim() ?? '';
    final nome = _model.nomeTextController?.text.trim() ?? '';
    if (item.isEmpty || nome.isEmpty) return;

    safeSetState(() => _model.salvando = true);
    try {
      final resp = await AddObraEtapaCall.call(
        token: token,
        obraServidorId: widget.obraServidorId,
        obraUuid: widget.obraUuid,
        item: item,
        nome: nome,
      );
      if (!mounted) return;
      if (resp.statusCode != 200) {
        final msg =
            resp.jsonBody is Map && (resp.jsonBody as Map)['error'] != null
                ? (resp.jsonBody as Map)['error'].toString()
                : 'Não foi possível salvar a etapa.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg,
                style:
                    TextStyle(color: FlutterFlowTheme.of(context).primaryText)),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }
      await actions.syncObrasEtapas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Etapa criada e sincronizada.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
      context.safePop();
    } finally {
      if (mounted) safeSetState(() => _model.salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    if (widget.obraServidorId <= 0 && widget.obraUuid.trim().isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Nova etapa'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.safePop(),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Obra sem identificador no servidor. Sincronize as obras e tente de novo.',
              textAlign: TextAlign.center,
              style: theme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.secondaryBackground,
          elevation: 0,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30,
            buttonSize: 48,
            icon: Icon(Icons.chevron_left_rounded,
                color: theme.primaryText, size: 28),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            'Nova etapa',
            style: theme.titleLarge.override(
              font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
              color: theme.primaryText,
            ),
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _model.formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'A etapa é criada no servidor e depois baixada para o app.',
                  style: theme.bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _model.itemTextController,
                  focusNode: _model.itemFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Nº item',
                    hintText: 'Ex.: 1 ou 2.1',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o item';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _model.nomeTextController,
                  focusNode: _model.nomeFocusNode,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: 'Nome da etapa',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Informe o nome';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: FFButtonWidget(
                        onPressed:
                            _model.salvando ? null : () => context.safePop(),
                        text: 'Cancelar',
                        options: FFButtonOptions(
                          height: 48,
                          color: theme.alternate,
                          textStyle: theme.titleSmall.override(
                            font: GoogleFonts.interTight(),
                            color: theme.primary,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FFButtonWidget(
                        onPressed: _model.salvando ? null : _salvar,
                        text: _model.salvando ? 'Salvando…' : 'Salvar',
                        options: FFButtonOptions(
                          height: 48,
                          color: theme.primary,
                          textStyle: theme.titleSmall.override(
                            font: GoogleFonts.interTight(color: Colors.white),
                            color: Colors.white,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

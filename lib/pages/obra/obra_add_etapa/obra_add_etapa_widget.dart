import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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
        backgroundColor: theme.primaryBackground,
        appBar: _buildAppBar(theme),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Obra sem identificador no servidor. Sincronize as obras e tente de novo.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
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
        appBar: _buildAppBar(theme),
        body: SafeArea(
          child: Form(
            key: _model.formKey,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    children: [
                      RdoSectionCard(
                        title: 'Dados da etapa',
                        icon: Icons.add_chart_outlined,
                        subtitle:
                            'Criada no servidor e sincronizada para o app',
                        margin: EdgeInsets.zero,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _model.itemTextController,
                              focusNode: _model.itemFocusNode,
                              style: rdoFormFieldTextStyle(context),
                              decoration: rdoFormFieldDecoration(
                                context,
                                label: 'Nº item',
                                hint: 'Ex.: 1 ou 2.1',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Informe o item';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _model.nomeTextController,
                              focusNode: _model.nomeFocusNode,
                              textCapitalization: TextCapitalization.sentences,
                              style: rdoFormFieldTextStyle(context),
                              decoration: rdoFormFieldDecoration(
                                context,
                                label: 'Nome da etapa',
                                hint: 'Ex.: Fundação',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Informe o nome';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildBarraAcoes(theme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FlutterFlowTheme theme) {
    return AppBar(
      backgroundColor: theme.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 0,
      toolbarHeight: 58,
      iconTheme: const IconThemeData(color: Colors.white),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.safePop(),
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nova etapa',
              style: GoogleFonts.interTight(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              'Planejamento da obra',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarraAcoes(FlutterFlowTheme theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        border: Border(top: BorderSide(color: theme.alternate)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _model.salvando ? null : () => context.safePop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: theme.primaryText,
                  side: BorderSide(color: theme.alternate),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Cancelar',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _model.salvando ? null : _salvar,
                icon: _model.salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 18),
                label: Text(
                  _model.salvando ? 'Salvando…' : 'Salvar etapa',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

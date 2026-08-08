import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'cadastrar_local_model.dart';
export 'cadastrar_local_model.dart';

/// Formulário de cadastrar local (bottom sheet).
class CadastrarLocalWidget extends StatefulWidget {
  const CadastrarLocalWidget({
    super.key,
    required this.obraUuid,
  });

  final String? obraUuid;

  @override
  State<CadastrarLocalWidget> createState() => _CadastrarLocalWidgetState();
}

class _CadastrarLocalWidgetState extends State<CadastrarLocalWidget> {
  late CadastrarLocalModel _model;
  bool _salvando = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CadastrarLocalModel());
    _model.textController ??= TextEditingController();
    _model.textFieldFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    if (!MembershipAccess.canPermission('create_cadastros_gerais')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para criar cadastros gerais.',
      );
      return;
    }
    final nome = _model.textController?.text.trim() ?? '';
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do local.')),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      _model.apiResult61u = await CadastrarObraLocalCall.call(
        nome: nome,
        obraUuid: widget.obraUuid,
        token: FFAppState().UserToken,
      );

      if (!mounted) return;
      if (_model.apiResult61u?.succeeded ?? false) {
        await actions.syncObraLocais();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Local cadastrado',
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        FFAppState().gatilhoRebuilderPage =
            FFAppState().gatilhoRebuilderPage + 1;
        FFAppState().update(() {});
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Falha ao cadastrar local',
              style: TextStyle(
                color: FlutterFlowTheme.of(context).primaryText,
              ),
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: theme.primary,
            padding: const EdgeInsets.fromLTRB(4, 6, 4, 12),
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Fechar',
                      onPressed:
                          _salvando ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Novo local',
                            style: GoogleFonts.interTight(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Vincular à obra',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.85),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: RdoSectionCard(
              title: 'Dados do local',
              icon: Icons.place_outlined,
              subtitle: 'Nome exibido nas tarefas e RDOs',
              margin: EdgeInsets.zero,
              child: TextFormField(
                controller: _model.textController,
                focusNode: _model.textFieldFocusNode,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _salvar(),
                style: rdoFormFieldTextStyle(context),
                decoration: rdoFormFieldDecoration(
                  context,
                  label: 'Nome do local *',
                  hint: 'Ex.: Bloco A · Pavimento 2',
                ),
                validator:
                    _model.textControllerValidator.asValidator(context),
              ),
            ),
          ),
          Container(
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
                      onPressed:
                          _salvando ? null : () => Navigator.pop(context),
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
                      onPressed: _salvando ? null : _salvar,
                      icon: _salvando
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
                        _salvando ? 'Salvando…' : 'Salvar',
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
          ),
        ],
      ),
    );
  }
}

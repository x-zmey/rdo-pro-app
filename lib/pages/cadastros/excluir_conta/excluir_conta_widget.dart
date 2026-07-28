import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fluxo dedicado de exclusão de conta (LGPD): informações, motivo e confirmação explícita.
class ExcluirContaWidget extends StatefulWidget {
  const ExcluirContaWidget({super.key});

  static String routeName = 'excluirConta';
  static String routePath = '/excluirConta';

  @override
  State<ExcluirContaWidget> createState() => _ExcluirContaWidgetState();
}

class _ExcluirContaWidgetState extends State<ExcluirContaWidget> {
  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// 0 = não uso mais, 1 = privacidade, 2 = outro
  int _motivo = 0;
  bool _liEConcordo = false;
  final _confirmacaoController = TextEditingController();
  bool _processando = false;

  static const _textoConfirmacao = 'EXCLUIR';

  @override
  void dispose() {
    _confirmacaoController.dispose();
    super.dispose();
  }

  bool get _podeEnviar {
    if (!_liEConcordo) return false;
    if (_confirmacaoController.text.trim().toUpperCase() !=
        _textoConfirmacao) {
      return false;
    }
    return true;
  }

  Future<void> _executarExclusao() async {
    final uid = FFAppState().UserID;
    final token = FFAppState().UserToken;
    if (uid < 1 || token.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Sessão inválida. Faça login novamente.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    setState(() => _processando = true);
    try {
      final resp = await ExcluirUsuarioCall.call(id: uid, token: token);
      if (!mounted) return;

      if (resp.succeeded) {
        FFAppState().clearAuthSession();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Conta encerrada. Até logo.'),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        context.goNamed(LoginWidget.routeName);
      } else {
        final msg = resp.bodyText.isNotEmpty
            ? resp.bodyText
            : 'Não foi possível excluir a conta.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.secondaryBackground,
        appBar: AppBar(
          backgroundColor: theme.secondaryBackground,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: theme.primaryText,
              size: 30.0,
            ),
            onPressed: () async {
              context.safePop();
            },
          ),
          title: Text(
            'Excluir conta',
            style: theme.headlineMedium.override(
              font: GoogleFonts.interTight(
                fontWeight: FontWeight.w600,
                fontStyle: theme.headlineMedium.fontStyle,
              ),
              letterSpacing: 0.0,
            ),
          ),
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(24.0, 8.0, 24.0, 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Antes de continuar, leia com atenção.',
                  style: theme.titleMedium.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 12),
                _infoBox(
                  theme,
                  'A exclusão da conta é permanente. Você perderá o acesso ao aplicativo e aos dados associados a este usuário, conforme as regras do sistema.',
                ),
                const SizedBox(height: 12),
                _infoBox(
                  theme,
                  'Relatórios e informações já enviadas à sua empresa podem permanecer registrados por obrigação legal ou contratual — a exclusão aqui encerra o seu acesso pessoal.',
                ),
                const SizedBox(height: 12),
                _infoBox(
                  theme,
                  'Se tiver dúvidas, entre em contato com o suporte antes de confirmar.',
                ),
                const SizedBox(height: 24),
                Text(
                  'Motivo da solicitação (opcional para o seu registro)',
                  style: theme.labelLarge.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 8),
                RadioListTile<int>(
                  dense: true,
                  value: 0,
                  groupValue: _motivo,
                  onChanged: _processando
                      ? null
                      : (v) => setState(() => _motivo = v ?? 0),
                  title: Text(
                    'Não utilizo mais o aplicativo',
                    style: theme.bodyMedium,
                  ),
                ),
                RadioListTile<int>(
                  dense: true,
                  value: 1,
                  groupValue: _motivo,
                  onChanged: _processando
                      ? null
                      : (v) => setState(() => _motivo = v ?? 0),
                  title: Text(
                    'Preocupações com privacidade ou dados',
                    style: theme.bodyMedium,
                  ),
                ),
                RadioListTile<int>(
                  dense: true,
                  value: 2,
                  groupValue: _motivo,
                  onChanged: _processando
                      ? null
                      : (v) => setState(() => _motivo = v ?? 0),
                  title: Text(
                    'Outro motivo',
                    style: theme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _liEConcordo,
                  onChanged: _processando
                      ? null
                      : (v) => setState(() => _liEConcordo = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(
                    'Li e entendo que esta ação não pode ser desfeita e desejo prosseguir.',
                    style: theme.bodySmall.override(
                      font: GoogleFonts.inter(),
                      color: theme.primaryText,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Para confirmar, digite ${_textoConfirmacao} em letras maiúsculas no campo abaixo:',
                  style: theme.bodySmall.override(
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmacaoController,
                  enabled: !_processando,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: _textoConfirmacao,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 28),
                FFButtonWidget(
                  onPressed: (!_podeEnviar || _processando)
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Confirmar exclusão'),
                              content: const Text(
                                'Sua conta será encerrada e você será desconectado. Deseja continuar?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(
                                    'Sim, excluir',
                                    style: TextStyle(
                                      color: FlutterFlowTheme.of(ctx).error,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                          if (ok == true && mounted) {
                            await _executarExclusao();
                          }
                        },
                  text: _processando ? 'Processando…' : 'Excluir minha conta definitivamente',
                  options: FFButtonOptions(
                    width: double.infinity,
                    height: 50.0,
                    color: theme.error,
                    textStyle: theme.titleSmall.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FontWeight.w600,
                      ),
                      color: theme.info,
                    ),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                const SizedBox(height: 12),
                FFButtonWidget(
                  onPressed:
                      _processando ? null : () => context.safePop(),
                  text: 'Cancelar e voltar',
                  options: FFButtonOptions(
                    width: double.infinity,
                    height: 48.0,
                    color: theme.secondaryBackground,
                    textStyle: theme.titleSmall.override(
                      color: theme.secondaryText,
                    ),
                    borderSide: BorderSide(color: theme.alternate),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBox(FlutterFlowTheme theme, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(color: theme.alternate),
      ),
      child: Text(
        text,
        style: theme.bodySmall.override(
          font: GoogleFonts.inter(),
          color: theme.secondaryText,
          lineHeight: 1.4,
        ),
      ),
    );
  }
}

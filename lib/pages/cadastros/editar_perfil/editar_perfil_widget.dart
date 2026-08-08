import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'editar_perfil_model.dart';
export 'editar_perfil_model.dart';

String _mensagemErroSalvarPerfil(dynamic jsonBody) {
  if (jsonBody is Map) {
    final errors = jsonBody['errors'];
    if (errors is Map) {
      for (final v in errors.values) {
        if (v is List && v.isNotEmpty) return v.first.toString();
        if (v is String && v.isNotEmpty) return v;
      }
    }
    final m = jsonBody['message']?.toString();
    if (m != null && m.isNotEmpty) return m;
  }
  return 'Não foi possível salvar o perfil.';
}

String _strCampo(dynamic v) {
  if (v == null) return '';
  return v.toString().trim();
}

/// Editar perfil: nome, sobrenome, telefone, cargo, registro profissional,
/// alterar senha e exclusão de conta.
class EditarPerfilWidget extends StatefulWidget {
  const EditarPerfilWidget({super.key});

  static String routeName = 'editarPerfil';
  static String routePath = '/editarPerfil';

  @override
  State<EditarPerfilWidget> createState() => _EditarPerfilWidgetState();
}

class _EditarPerfilWidgetState extends State<EditarPerfilWidget> {
  late EditarPerfilModel _model;
  late Future<ApiCallResponse> _meusDadosFuture;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _controllersProntos = false;
  bool _salvando = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditarPerfilModel());
    _meusDadosFuture = GetMeusDadosCall.call(token: FFAppState().UserToken);
    _model.textFieldFocusNode1 ??= FocusNode();
    _model.textFieldFocusNode2 ??= FocusNode();
    _model.textFieldFocusNode3 ??= FocusNode();
    _model.textFieldFocusNode4 ??= FocusNode();
    _model.textFieldFocusNode5 ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  void _garantirControllers(dynamic jsonBody) {
    if (_controllersProntos) return;
    _model.textController1 ??= TextEditingController(
      text: GetMeusDadosCall.nome(jsonBody) ?? '',
    );
    _model.textController2 ??= TextEditingController(
      text: GetMeusDadosCall.sobrenome(jsonBody) ?? '',
    );
    _model.textController3 ??= TextEditingController(
      text: GetMeusDadosCall.telefone(jsonBody) ?? '',
    );
    _model.textController4 ??= TextEditingController(
      text: _strCampo(GetMeusDadosCall.cargo(jsonBody)),
    );
    _model.textController5 ??= TextEditingController(
      text: _strCampo(GetMeusDadosCall.registroProfissional(jsonBody)),
    );
    _email = GetMeusDadosCall.email(jsonBody);
    _controllersProntos = true;
  }

  Future<void> _recarregar() async {
    setState(() {
      _controllersProntos = false;
      _model.textController1?.dispose();
      _model.textController2?.dispose();
      _model.textController3?.dispose();
      _model.textController4?.dispose();
      _model.textController5?.dispose();
      _model.textController1 = null;
      _model.textController2 = null;
      _model.textController3 = null;
      _model.textController4 = null;
      _model.textController5 = null;
      _meusDadosFuture =
          GetMeusDadosCall.call(token: FFAppState().UserToken);
    });
    await _meusDadosFuture;
  }

  Future<void> _salvarPerfil() async {
    if (_salvando) return;
    final nome = _model.textController1?.text.trim() ?? '';
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nome é obrigatório')),
      );
      return;
    }
    final token = FFAppState().UserToken;
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sessão expirada. Faça login novamente.'),
        ),
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      final res = await UpdateProfileUserCall.call(
        token: token,
        nome: nome,
        sobrenome: _model.textController2?.text.trim() ?? '',
        telefone: _model.textController3?.text.trim() ?? '',
        cargo: _model.textController4?.text.trim() ?? '',
        registroProfissional: _model.textController5?.text.trim() ?? '',
      );
      if (!mounted) return;
      if (res.succeeded) {
        final msg = UpdateProfileUserCall.message(res.jsonBody) ??
            'Dados atualizados com sucesso!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
        final sob = _model.textController2?.text.trim() ?? '';
        FFAppState().UserName = sob.isEmpty ? nome : '$nome $sob'.trim();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mensagemErroSalvarPerfil(res.jsonBody)),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: $e'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  String get _iniciais {
    final n = (_model.textController1?.text ?? '').trim();
    final s = (_model.textController2?.text ?? '').trim();
    if (n.isEmpty && s.isEmpty) return '?';
    final a = n.isNotEmpty ? n[0] : '';
    final b = s.isNotEmpty ? s[0] : (n.length > 1 ? n[1] : '');
    return ('$a$b').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
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
            onPressed: () {
              if (context.canPop()) {
                context.safePop();
              } else {
                context.pushNamed(MenuWidget.routeName);
              }
            },
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editar perfil',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Dados pessoais e segurança',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 21),
              onPressed: _salvando ? null : _recarregar,
            ),
            TextButton(
              onPressed: _salvando ? null : _salvarPerfil,
              child: Text(
                _salvando ? 'Salvando…' : 'Salvar',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildBody(theme)),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FlutterFlowTheme theme) {
    return FutureBuilder<ApiCallResponse>(
      future: _meusDadosFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !_controllersProntos) {
          return const Center(
            child: SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
          );
        }

        if (snapshot.hasError) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 40, color: theme.error.withValues(alpha: 0.7)),
              const SizedBox(height: 12),
              Text(
                'Erro ao carregar perfil',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: _recarregar,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tentar novamente'),
                ),
              ),
            ],
          );
        }

        final res = snapshot.data;
        if (res == null || !res.succeeded) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
            children: [
              Icon(Icons.person_off_outlined,
                  size: 40,
                  color: theme.secondaryText.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                'Não foi possível carregar seus dados.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: FilledButton.icon(
                  onPressed: _recarregar,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tentar novamente'),
                ),
              ),
            ],
          );
        }

        _garantirControllers(res.jsonBody);

        return Form(
          key: _model.formKey,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              kBarraNavegacaoPrincipalReservaScroll,
            ),
            children: [
              _buildCabecalho(theme),
              const SizedBox(height: 10),
              _buildDadosPessoais(theme),
              const SizedBox(height: 10),
              _buildDadosProfissionais(theme),
              const SizedBox(height: 10),
              _buildSeguranca(theme),
              const SizedBox(height: 10),
              _buildZonaPerigo(theme),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _salvando ? null : _salvarPerfil,
                icon: _salvando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _salvando ? 'Salvando…' : 'Salvar alterações',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCabecalho(FlutterFlowTheme theme) {
    final nome = (_model.textController1?.text ?? '').trim();
    final sob = (_model.textController2?.text ?? '').trim();
    final display = [nome, sob].where((e) => e.isNotEmpty).join(' ');

    return RdoSectionCard(
      title: 'Sua conta',
      icon: Icons.account_circle_outlined,
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.primary,
            child: Text(
              _iniciais,
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  display.isEmpty ? 'Seu perfil' : display,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText,
                  ),
                ),
                if ((_email ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _email!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      color: theme.secondaryText,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  'Atualize os dados enviados ao servidor',
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _campo({
    required FlutterFlowTheme theme,
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    List<TextInputFormatter>? formatters,
    List<String>? autofillHints,
    TextInputAction inputAction = TextInputAction.next,
    bool obrigatorio = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: inputAction,
      autofillHints: autofillHints,
      inputFormatters: formatters,
      style: rdoFormFieldTextStyle(context),
      decoration: rdoFormFieldDecoration(
        context,
        label: obrigatorio ? '$label *' : label,
        hint: hint,
      ),
      validator: obrigatorio
          ? (v) {
              if ((v ?? '').trim().isEmpty) return '$label é obrigatório';
              return null;
            }
          : null,
    );
  }

  Widget _buildDadosPessoais(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Dados pessoais',
      icon: Icons.badge_outlined,
      subtitle: 'Nome e contato',
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _campo(
            theme: theme,
            controller: _model.textController1,
            focusNode: _model.textFieldFocusNode1,
            label: 'Nome',
            hint: 'Seu nome',
            keyboardType: TextInputType.name,
            capitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.name],
            formatters: [FilteringTextInputFormatter.singleLineFormatter],
            obrigatorio: true,
          ),
          const SizedBox(height: 10),
          _campo(
            theme: theme,
            controller: _model.textController2,
            focusNode: _model.textFieldFocusNode2,
            label: 'Sobrenome',
            hint: 'Seu sobrenome',
            keyboardType: TextInputType.name,
            capitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.familyName],
            formatters: [FilteringTextInputFormatter.singleLineFormatter],
          ),
          const SizedBox(height: 10),
          _campo(
            theme: theme,
            controller: _model.textController3,
            focusNode: _model.textFieldFocusNode3,
            label: 'Telefone / WhatsApp',
            hint: '(11) 99999-9999',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
          ),
        ],
      ),
    );
  }

  Widget _buildDadosProfissionais(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Dados profissionais',
      icon: Icons.work_outline_rounded,
      subtitle: 'Cargo e registro',
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _campo(
            theme: theme,
            controller: _model.textController4,
            focusNode: _model.textFieldFocusNode4,
            label: 'Cargo / Função',
            hint: 'Ex.: Engenheiro, Supervisor',
            capitalization: TextCapitalization.words,
            formatters: [FilteringTextInputFormatter.singleLineFormatter],
          ),
          const SizedBox(height: 10),
          _campo(
            theme: theme,
            controller: _model.textController5,
            focusNode: _model.textFieldFocusNode5,
            label: 'Registro profissional',
            hint: 'CREA, CAU, etc.',
            inputAction: TextInputAction.done,
            formatters: [FilteringTextInputFormatter.singleLineFormatter],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required FlutterFlowTheme theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final accent = destructive ? theme.error : theme.primary;
    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 20, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: destructive ? theme.error : theme.primaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: theme.secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, size: 20, color: accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeguranca(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Segurança',
      icon: Icons.lock_outline_rounded,
      margin: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      child: _buildLinkTile(
        theme: theme,
        icon: Icons.password_rounded,
        title: 'Alterar senha',
        subtitle: 'Redefina sua senha de acesso',
        onTap: () {
          context.pushNamed(AlterarSenhaWidget.routeName);
        },
      ),
    );
  }

  Widget _buildZonaPerigo(FlutterFlowTheme theme) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: rdoCardDecoration(context).copyWith(
        border: Border.all(color: theme.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
            constraints: const BoxConstraints(minHeight: 44),
            decoration: BoxDecoration(
              color: theme.error.withValues(alpha: 0.06),
              border: Border(
                bottom: BorderSide(color: theme.error.withValues(alpha: 0.2)),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: theme.error),
                const SizedBox(width: 8),
                Text(
                  'Zona de perigo',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.error,
                  ),
                ),
              ],
            ),
          ),
          _buildLinkTile(
            theme: theme,
            icon: Icons.delete_forever_outlined,
            title: 'Excluir conta',
            subtitle: 'Ver informações e confirmar na próxima tela',
            destructive: true,
            onTap: () {
              context.pushNamed(ExcluirContaWidget.routeName);
            },
          ),
        ],
      ),
    );
  }
}

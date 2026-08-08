import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import 'cadastrar_usuario_model.dart';
import 'cadastro_usuario_email_flow.dart';
import 'vincular_usuario_sheet.dart';
export 'cadastrar_usuario_model.dart';

String _apenasDigitos(String? raw) =>
    (raw ?? '').replaceAll(RegExp(r'\D'), '');

MaskTextInputFormatter _novaMascaraCpf([String? digitos]) =>
    MaskTextInputFormatter(
      mask: '###.###.###-##',
      filter: {'#': RegExp(r'[0-9]')},
      initialText: digitos ?? '',
      type: MaskAutoCompletionType.lazy,
    );

MaskTextInputFormatter _novaMascaraCnpj([String? digitos]) =>
    MaskTextInputFormatter(
      mask: '##.###.###/####-##',
      filter: {'#': RegExp(r'[0-9]')},
      initialText: digitos ?? '',
      type: MaskAutoCompletionType.lazy,
    );

/// Telefone BR: `(##) ####-####` (10) ou `(##) #####-####` (11).
class _TelefoneMaskFormatter extends MaskTextInputFormatter {
  _TelefoneMaskFormatter([String? digitos])
      : super(
          mask: (digitos ?? '').length > 10
              ? '(##) #####-####'
              : '(##) ####-####',
          filter: {'#': RegExp(r'[0-9]')},
          initialText: digitos ?? '',
          type: MaskAutoCompletionType.lazy,
        );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final maskDesejada =
        digits.length > 10 ? '(##) #####-####' : '(##) ####-####';
    if (getMask() != maskDesejada) {
      updateMask(mask: maskDesejada);
    }
    return super.formatEditUpdate(oldValue, newValue);
  }
}

/// Cadastro/edição de usuário (pessoa física ou jurídica).
class CadastrarUsuarioWidget extends StatefulWidget {
  const CadastrarUsuarioWidget({super.key, this.usuarioUuid});

  /// Quando informado, abre em modo edição via API (`PUT /api/usuarios/{uuid}`).
  final String? usuarioUuid;

  static String routeName = 'cadastrarUsuario';
  static String routePath = '/cadastrarUsuario';

  @override
  State<CadastrarUsuarioWidget> createState() => _CadastrarUsuarioWidgetState();
}

class _CadastrarUsuarioWidgetState extends State<CadastrarUsuarioWidget> {
  late CadastrarUsuarioModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  late CadastroUsuarioEmailFlow _emailFlow;

  bool _editDadosCarregados = false;
  bool _editErroCarregamento = false;
  bool _salvando = false;

  late MaskTextInputFormatter _cpfMask;
  late MaskTextInputFormatter _cnpjMask;
  late _TelefoneMaskFormatter _telefoneMask;
  late _TelefoneMaskFormatter _whatsappMask;

  static const _tiposUi = [
    'Operador',
    'Cliente',
    'Supervisor',
    'Administrador',
  ];

  bool get _modoEdicao =>
      widget.usuarioUuid != null && widget.usuarioUuid!.trim().isNotEmpty;

  bool get _isJuridica =>
      (_model.radioButtonValue1 ?? _model.tipo) == 'Pessoa Jurídica';

  bool get _podeMostrarForm =>
      _modoEdicao || _emailFlow.canShowNewUserForm;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CadastrarUsuarioModel());

    _cpfMask = _novaMascaraCpf();
    _cnpjMask = _novaMascaraCnpj();
    _telefoneMask = _TelefoneMaskFormatter();
    _whatsappMask = _TelefoneMaskFormatter();

    _model.textController1 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();
    _model.textController2 ??= TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();
    _model.textController3 ??= TextEditingController();
    _model.textFieldFocusNode3 ??= FocusNode();
    _model.textController4 ??= TextEditingController();
    _model.textFieldFocusNode4 ??= FocusNode();
    _model.textController5 ??= TextEditingController();
    _model.textFieldFocusNode5 ??= FocusNode();
    _model.textController6 ??= TextEditingController();
    _model.textFieldFocusNode6 ??= FocusNode();
    _model.textController7 ??= TextEditingController();
    _model.textFieldFocusNode7 ??= FocusNode();
    _model.textController8 ??= TextEditingController();
    _model.textFieldFocusNode8 ??= FocusNode();
    _model.textController9 ??= TextEditingController();
    _model.textFieldFocusNode9 ??= FocusNode();
    _model.textController10 ??= TextEditingController();
    _model.textFieldFocusNode10 ??= FocusNode();
    _model.textController11 ??= TextEditingController();
    _model.textFieldFocusNode11 ??= FocusNode();

    _model.radioButtonValueController1 ??=
        FormFieldController<String>('Pessoa Física');
    _model.radioButtonValueController2 ??=
        FormFieldController<String>('Ativo');
    _model.dropDownValueController ??= FormFieldController<String>(null);

    _emailFlow = CadastroUsuarioEmailFlow(
      emailController: _model.textController6!,
      onChanged: () => safeSetState(() {}),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perm =
          _modoEdicao ? 'edit_usuarios' : 'create_usuarios';
      if (!MembershipAccess.canPermission(perm)) {
        MembershipAccess.showDenied(
          context,
          _modoEdicao
              ? 'Sem permissão para editar usuários.'
              : 'Sem permissão para criar usuários.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
        return;
      }
      if (_modoEdicao) {
        _carregarUsuarioEdicao();
      }
    });

    if (!_modoEdicao) {
      _editDadosCarregados = true;
    }
  }

  @override
  void dispose() {
    _emailFlow.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregarUsuarioEdicao() async {
    final uuid = widget.usuarioUuid!.trim();
    try {
      final resp = await GetUsuarioShowCall.call(
        usuarioUuid: uuid,
        token: FFAppState().UserToken,
      );
      if (!mounted) return;
      final r = resp.succeeded && resp.jsonBody is Map
          ? (resp.jsonBody as Map)['value']
          : null;
      if (r is! Map) {
        setState(() {
          _editErroCarregamento = true;
          _editDadosCarregados = true;
        });
        return;
      }
      final jur = r['juridica'] == 1 ||
          r['juridica'] == true ||
          (r['juridica'] != null && r['juridica'].toString() == '1');
      final tipoPessoa = jur ? 'Pessoa Jurídica' : 'Pessoa Física';
      _model.radioButtonValueController1 =
          FormFieldController<String>(tipoPessoa);
      _model.tipo = tipoPessoa;
      final docDigits = _apenasDigitos(r['documento']?.toString());
      if (jur) {
        _model.textController4?.text = r['nome']?.toString() ?? '';
        _cnpjMask = _novaMascaraCnpj(docDigits);
        _model.textController5?.text = _cnpjMask.getMaskedText();
      } else {
        _model.textController1?.text = r['nome']?.toString().trim() ?? '';
        final sob = r['sobrenome']?.toString().trim();
        if (sob != null && sob.isNotEmpty) {
          _model.textController2?.text = sob;
        } else {
          final nomeFull = r['nome']?.toString().trim() ?? '';
          final parts = nomeFull.split(RegExp(r'\s+'));
          if (parts.length > 1) {
            _model.textController1?.text = parts.first;
            _model.textController2?.text = parts.sublist(1).join(' ');
          } else {
            _model.textController2?.text = '';
          }
        }
        _cpfMask = _novaMascaraCpf(docDigits);
        _model.textController3?.text = _cpfMask.getMaskedText();
      }
      _model.textController6?.text = r['email']?.toString() ?? '';
      _model.textController7?.clear();
      final telDigits = _apenasDigitos(r['telefone']?.toString());
      _telefoneMask = _TelefoneMaskFormatter(telDigits);
      _model.textController8?.text = _telefoneMask.getMaskedText();
      if (r.containsKey('whatsapp') && r['whatsapp'] != null) {
        final waDigits = _apenasDigitos(r['whatsapp'].toString());
        _whatsappMask = _TelefoneMaskFormatter(waDigits);
        _model.textController9?.text = _whatsappMask.getMaskedText();
      }
      _model.textController10?.text = r['cargo']?.toString() ?? '';
      _model.textController11?.text =
          r['registro_profissional']?.toString() ?? '';

      final t = r['type']?.toString() ?? 'operador';
      final ui = _typeUiFromApi(t);
      _model.dropDownValueController = FormFieldController<String>(ui);
      _model.dropDownValue = ui;

      final sit = r['situacao'];
      final ativo = sit == null || sit == 1;
      _model.radioButtonValueController2 =
          FormFieldController<String>(ativo ? 'Ativo' : 'Inativo');

      _model.textController7Validator = (context, val) => null;

      setState(() {
        _editDadosCarregados = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _editErroCarregamento = true;
        _editDadosCarregados = true;
      });
    }
  }

  String _typeUiFromApi(String t) {
    switch (t) {
      case 'operador':
        return 'Operador';
      case 'cliente':
        return 'Cliente';
      case 'supervisor':
        return 'Supervisor';
      case 'administrador':
        return 'Administrador';
      default:
        return 'Operador';
    }
  }

  String? _typeApiFromUi(String? display) {
    switch (display) {
      case 'Operador':
        return 'operador';
      case 'Cliente':
        return 'cliente';
      case 'Supervisor':
        return 'supervisor';
      case 'Administrador':
        return 'administrador';
      default:
        return null;
    }
  }

  void _voltar() {
    if (context.canPop()) {
      context.safePop();
      return;
    }
    context.pushNamed(UsuariosWidget.routeName);
  }

  void _setTipoPessoa(String value) {
    if ((_model.radioButtonValue1 ?? _model.tipo) == value) return;
    setState(() {
      _model.tipo = value;
      _model.radioButtonValueController1 = FormFieldController<String>(value);
    });
  }

  void _setStatus(String value) {
    if (_model.radioButtonValue2 == value) return;
    setState(() {
      _model.radioButtonValueController2 = FormFieldController<String>(value);
    });
  }

  Future<void> _openVincularSheet() async {
    final user = _emailFlow.existingUser;
    if (user == null) return;

    final payload = await showVincularUsuarioSheet(context, user: user);
    if (payload == null || !mounted) return;

    await _vincularUsuario(payload);
  }

  Future<void> _vincularUsuario(Map<String, dynamic> payload) async {
    final userId = payload['user_id'];
    if (userId == null) return;

    final resp = await VincularUsuarioCall.call(
      token: FFAppState().UserToken,
      userId: userId is int ? userId : int.parse(userId.toString()),
      type: payload['type']?.toString() ?? 'operador',
      obraTravada: payload['obra_travada'] == true,
    );

    if (!mounted) return;

    if (resp.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuário vinculado à empresa'),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
      context.pushNamed(UsuariosWidget.routeName);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp.bodyText.isNotEmpty
                ? resp.bodyText
                : 'Falha ao vincular usuário',
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _salvarUsuario() async {
    if (_salvando) return;

    final tipoUser = _typeApiFromUi(
        _model.dropDownValue ?? _model.dropDownValueController?.value);
    if (tipoUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione o tipo de usuário.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final pessoaFisica =
        (_model.radioButtonValue1 ?? 'Pessoa Física') == 'Pessoa Física';
    late String nome;
    late String sobrenome;
    late bool juridica;
    String? documento;

    if (pessoaFisica) {
      nome = _model.textController1?.text.trim() ?? '';
      sobrenome = _model.textController2?.text.trim() ?? '';
      final cpf = _cpfMask.getUnmaskedText();
      documento = cpf.isEmpty ? null : cpf;
      juridica = false;
      if (nome.isEmpty || sobrenome.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preencha nome e sobrenome.'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }
    } else {
      nome = _model.textController4?.text.trim() ?? '';
      sobrenome = '-';
      final cnpj = _cnpjMask.getUnmaskedText();
      documento = cnpj.isEmpty ? null : cnpj;
      juridica = true;
      if (nome.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preencha a razão social e o CNPJ.'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }
    }

    final telefoneDigits = _telefoneMask.getUnmaskedText();
    final telefone =
        telefoneDigits.isEmpty ? null : telefoneDigits;

    final email = _model.textController6?.text.trim() ?? '';
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Informe o e-mail.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final password = _model.textController7?.text ?? '';
    if (!_modoEdicao && password.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('A senha deve ter no mínimo 6 caracteres.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    if (_modoEdicao &&
        password.trim().isNotEmpty &&
        password.trim().length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('A nova senha deve ter no mínimo 6 caracteres.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    setState(() => _salvando = true);
    final token = FFAppState().UserToken;

    try {
      if (_modoEdicao) {
        final ativo = (_model.radioButtonValue2 ?? 'Ativo') == 'Ativo';
        final resp = await UpdateUsuarioCall.call(
          usuarioUuid: widget.usuarioUuid,
          token: token,
          nome: nome,
          sobrenome: sobrenome,
          email: email,
          password: password.trim().isEmpty ? null : password.trim(),
          type: tipoUser,
          situacao: ativo ? 1 : 0,
          telefone: telefone,
          documento: documento,
          cargo: _model.textController10?.text.trim(),
          registroProfissional: _model.textController11?.text.trim(),
        );
        if (!mounted) return;
        if (resp.succeeded) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Usuário atualizado'),
              backgroundColor: FlutterFlowTheme.of(context).secondary,
            ),
          );
          context.pushNamed(UsuariosWidget.routeName);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao atualizar',
              ),
              backgroundColor: FlutterFlowTheme.of(context).error,
            ),
          );
        }
        return;
      }

      final resp = await CadastrarUsuarioCall.call(
        token: token,
        nome: nome,
        sobrenome: sobrenome,
        email: email,
        password: password.trim(),
        type: tipoUser,
        juridica: juridica,
        telefone: telefone,
        documento: documento,
        cargo: _model.textController10?.text.trim(),
        registroProfissional: _model.textController11?.text.trim(),
      );
      if (!mounted) return;
      if (resp.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Usuário cadastrado'),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        context.pushNamed(UsuariosWidget.routeName);
        return;
      }

      if (resp.statusCode == 409 && resp.jsonBody is Map) {
        final body = resp.jsonBody as Map;
        if (body['code']?.toString() == 'USER_EXISTS_LINK_AVAILABLE') {
          final u = body['user'];
          if (u is Map) {
            _emailFlow.existingUser = Map<String, dynamic>.from(u);
            _emailFlow.status = EmailCadastroStatus.linkAvailable;
            _emailFlow.message = body['message']?.toString() ?? '';
            safeSetState(() {});
            await _openVincularSheet();
          }
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao cadastrar',
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final titulo = _modoEdicao ? 'Editar usuário' : 'Novo usuário';

    if (_modoEdicao && !_editDadosCarregados) {
      return Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: _buildAppBar(theme, titulo),
        body: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: theme.primary,
            ),
          ),
        ),
      );
    }

    if (_modoEdicao && _editErroCarregamento) {
      return Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: _buildAppBar(theme, titulo),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_off_outlined,
                    size: 40,
                    color: theme.secondaryText.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'Não foi possível carregar o usuário.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      _editErroCarregamento = false;
                      _editDadosCarregados = false;
                    });
                    _carregarUsuarioEdicao();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Tentar novamente'),
                ),
              ],
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
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: _buildAppBar(theme, titulo),
        body: Column(
          children: [
            Expanded(
              child: Form(
                key: _model.formKey,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    if (!_modoEdicao) ...[
                      _emailFlow.buildEmailSection(
                        context,
                        onOpenLink: _openVincularSheet,
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_podeMostrarForm) ...[
                      if (_modoEdicao) ...[
                        RdoSectionCard(
                          title: 'E-mail',
                          icon: Icons.email_outlined,
                          margin: EdgeInsets.zero,
                          child: _campo(
                            controller: _model.textController6,
                            focusNode: _model.textFieldFocusNode6,
                            label: 'E-mail *',
                            hint: 'exemplo@email.com',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      _buildTipoPessoa(theme),
                      const SizedBox(height: 10),
                      _buildIdentificacao(theme),
                      const SizedBox(height: 10),
                      _buildAcesso(theme),
                      const SizedBox(height: 10),
                      _buildContato(theme),
                      const SizedBox(height: 10),
                      _buildProfissional(theme),
                      const SizedBox(height: 10),
                      _buildConfiguracoes(theme),
                    ],
                  ],
                ),
              ),
            ),
            if (_podeMostrarForm) _buildAcoesInferiores(theme),
            if (!_podeMostrarForm)
              Material(
                color: theme.secondaryBackground,
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: OutlinedButton(
                      onPressed: _voltar,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.primaryText,
                        side: BorderSide(color: theme.alternate),
                        minimumSize: const Size(double.infinity, 44),
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
                ),
              ),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FlutterFlowTheme theme, String titulo) {
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
        onPressed: _voltar,
      ),
      title: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              titulo,
              style: GoogleFonts.interTight(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              _modoEdicao
                  ? 'Atualizar dados de acesso'
                  : 'Cadastro de acesso ao sistema',
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
    );
  }

  Widget _campo({
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction inputAction = TextInputAction.next,
    bool obscureText = false,
    Widget? suffixIcon,
    List<TextInputFormatter>? formatters,
    List<String>? autofillHints,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      textInputAction: inputAction,
      obscureText: obscureText,
      autofillHints: autofillHints,
      inputFormatters: formatters,
      onChanged: onChanged,
      style: rdoFormFieldTextStyle(context),
      decoration: rdoFormFieldDecoration(
        context,
        label: label,
        hint: hint,
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildTipoPessoa(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Tipo de pessoa',
      icon: Icons.badge_outlined,
      subtitle: 'Física ou jurídica',
      margin: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.primaryBackground.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.alternate),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _tipoBotao(
                theme,
                value: 'Pessoa Física',
                titulo: 'Física',
                subtitulo: 'CPF e nome',
                icon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _tipoBotao(
                theme,
                value: 'Pessoa Jurídica',
                titulo: 'Jurídica',
                subtitulo: 'CNPJ e razão',
                icon: Icons.apartment_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tipoBotao(
    FlutterFlowTheme theme, {
    required String value,
    required String titulo,
    required String subtitulo,
    required IconData icon,
  }) {
    final selecionado =
        (_model.radioButtonValue1 ?? _model.tipo) == value;
    return Material(
      color: selecionado ? theme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _setTipoPessoa(value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          child: Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selecionado
                      ? Colors.white.withValues(alpha: 0.18)
                      : theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(8),
                  border: selecionado
                      ? null
                      : Border.all(color: theme.alternate),
                ),
                child: Icon(
                  icon,
                  size: 16,
                  color: selecionado ? Colors.white : theme.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                titulo,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: selecionado ? Colors.white : theme.primaryText,
                ),
              ),
              Text(
                subtitulo,
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  color: selecionado
                      ? Colors.white.withValues(alpha: 0.85)
                      : theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIdentificacao(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: _isJuridica ? 'Dados da empresa' : 'Dados pessoais',
      icon: _isJuridica
          ? Icons.business_outlined
          : Icons.person_outline_rounded,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          if (_isJuridica) ...[
            _campo(
              controller: _model.textController4,
              focusNode: _model.textFieldFocusNode4,
              label: 'Razão social *',
              hint: 'Nome da empresa',
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.organizationName],
            ),
            const SizedBox(height: 10),
            _campo(
              controller: _model.textController5,
              focusNode: _model.textFieldFocusNode5,
              label: 'CNPJ',
              hint: '00.000.000/0000-00',
              keyboardType: TextInputType.number,
              formatters: [_cnpjMask],
            ),
          ] else ...[
            _campo(
              controller: _model.textController1,
              focusNode: _model.textFieldFocusNode1,
              label: 'Nome *',
              hint: 'Primeiro nome',
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.givenName],
            ),
            const SizedBox(height: 10),
            _campo(
              controller: _model.textController2,
              focusNode: _model.textFieldFocusNode2,
              label: 'Sobrenome *',
              hint: 'Sobrenome',
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.familyName],
            ),
            const SizedBox(height: 10),
            _campo(
              controller: _model.textController3,
              focusNode: _model.textFieldFocusNode3,
              label: 'CPF',
              hint: '000.000.000-00',
              keyboardType: TextInputType.number,
              formatters: [_cpfMask],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAcesso(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Acesso',
      icon: Icons.lock_outline_rounded,
      subtitle: _modoEdicao
          ? 'Deixe em branco para manter a senha'
          : 'Senha de acesso ao app',
      margin: EdgeInsets.zero,
      child: _campo(
        controller: _model.textController7,
        focusNode: _model.textFieldFocusNode7,
        label: _modoEdicao ? 'Nova senha' : 'Senha *',
        hint: _modoEdicao ? 'Opcional' : 'Mínimo 6 caracteres',
        obscureText: !_model.passwordVisibility,
        autofillHints: const [AutofillHints.newPassword],
        inputAction: TextInputAction.next,
        suffixIcon: IconButton(
          tooltip: _model.passwordVisibility ? 'Ocultar' : 'Mostrar',
          onPressed: () {
            setState(() {
              _model.passwordVisibility = !_model.passwordVisibility;
            });
          },
          icon: Icon(
            _model.passwordVisibility
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            size: 20,
            color: theme.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _buildContato(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Contato',
      icon: Icons.contact_phone_outlined,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _campo(
            controller: _model.textController8,
            focusNode: _model.textFieldFocusNode8,
            label: 'Telefone',
            hint: '(00) 00000-0000',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            formatters: [_telefoneMask],
          ),
          const SizedBox(height: 10),
          _campo(
            controller: _model.textController9,
            focusNode: _model.textFieldFocusNode9,
            label: 'WhatsApp',
            hint: '(00) 00000-0000',
            keyboardType: TextInputType.phone,
            formatters: [_whatsappMask],
          ),
        ],
      ),
    );
  }

  Widget _buildProfissional(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Dados profissionais',
      icon: Icons.work_outline_rounded,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _campo(
            controller: _model.textController10,
            focusNode: _model.textFieldFocusNode10,
            label: 'Cargo / função',
            hint: 'Ex.: Engenheiro, Encarregado…',
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          _campo(
            controller: _model.textController11,
            focusNode: _model.textFieldFocusNode11,
            label: 'Registro profissional',
            hint: 'CREA, CAU…',
            inputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _buildConfiguracoes(FlutterFlowTheme theme) {
    final tipoAtual =
        _model.dropDownValue ?? _model.dropDownValueController?.value;
    final statusAtual = _model.radioButtonValue2 ?? 'Ativo';

    return RdoSectionCard(
      title: 'Configurações',
      icon: Icons.settings_outlined,
      subtitle: 'Tipo de acesso e situação',
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            key: ValueKey('tipo-$tipoAtual'),
            initialValue: tipoAtual,
            isExpanded: true,
            decoration: rdoFormFieldDecoration(
              context,
              label: 'Tipo de usuário *',
              hint: 'Selecione',
            ),
            style: rdoFormFieldTextStyle(context),
            items: [
              for (final t in _tiposUi)
                DropdownMenuItem(value: t, child: Text(t)),
            ],
            onChanged: (val) {
              setState(() {
                _model.dropDownValue = val;
                _model.dropDownValueController =
                    FormFieldController<String>(val);
              });
            },
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Status',
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: theme.primaryBackground.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.alternate),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _statusBotao(
                    theme,
                    value: 'Ativo',
                    selecionado: statusAtual == 'Ativo',
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _statusBotao(
                    theme,
                    value: 'Inativo',
                    selecionado: statusAtual == 'Inativo',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBotao(
    FlutterFlowTheme theme, {
    required String value,
    required bool selecionado,
  }) {
    return Material(
      color: selecionado ? theme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => _setStatus(value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Center(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selecionado ? Colors.white : theme.primaryText,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAcoesInferiores(FlutterFlowTheme theme) {
    return Material(
      color: theme.secondaryBackground,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _salvando ? null : _voltar,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: theme.primaryText,
                    side: BorderSide(color: theme.alternate),
                    minimumSize: const Size(0, 44),
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
                  onPressed: _salvando ? null : _salvarUsuario,
                  icon: _salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _modoEdicao
                              ? Icons.save_rounded
                              : Icons.person_add_alt_1,
                          size: 18,
                        ),
                  label: Text(
                    _salvando
                        ? 'Salvando…'
                        : (_modoEdicao ? 'Salvar' : 'Cadastrar'),
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
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
    );
  }
}

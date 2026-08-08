import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'cadastrar_cliente_model.dart';
export 'cadastrar_cliente_model.dart';

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

const _kEstadosBr = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
  'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE',
  'TO',
];

/// Cadastro/edição de cliente (pessoa física ou jurídica).
class CadastrarClienteWidget extends StatefulWidget {
  const CadastrarClienteWidget({
    super.key,
    this.clienteUuid,
  });

  /// Se preenchido, abre em modo edição via API (`PUT /api/clientes/{uuid}`).
  final String? clienteUuid;

  static String routeName = 'cadastrarCliente';
  static String routePath = '/cadastrarCliente';

  @override
  State<CadastrarClienteWidget> createState() => _CadastrarClienteWidgetState();
}

class _CadastrarClienteWidgetState extends State<CadastrarClienteWidget> {
  late CadastrarClienteModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _editDadosCarregados = false;
  bool _editErroCarregamento = false;
  bool _salvando = false;

  late MaskTextInputFormatter _cpfMask;
  late MaskTextInputFormatter _cnpjMask;
  late _TelefoneMaskFormatter _telefoneMask;

  bool get _modoEdicao =>
      widget.clienteUuid != null && widget.clienteUuid!.trim().isNotEmpty;

  bool get _isJuridica => _model.tipoDocumento == 'juridica';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CadastrarClienteModel());

    _cpfMask = _novaMascaraCpf();
    _cnpjMask = _novaMascaraCnpj();
    _telefoneMask = _TelefoneMaskFormatter();

    _model.textFieldCpfTextController ??= TextEditingController();
    _model.textFieldCpfFocusNode ??= FocusNode();
    _model.textFieldNomeTextController ??= TextEditingController();
    _model.textFieldNomeFocusNode ??= FocusNode();
    _model.textFieldCnpjTextController ??= TextEditingController();
    _model.textFieldCnpjFocusNode ??= FocusNode();
    _model.textFieldRazaoSocialTextController ??= TextEditingController();
    _model.textFieldRazaoSocialFocusNode ??= FocusNode();
    _model.textFieldTelefoneTextController ??= TextEditingController();
    _model.textFieldTelefoneFocusNode ??= FocusNode();
    _model.textFieldEmailTextController ??= TextEditingController();
    _model.textFieldEmailFocusNode ??= FocusNode();
    _model.textFieldRuaTextController ??= TextEditingController();
    _model.textFieldRuaFocusNode ??= FocusNode();
    _model.textFieldNumeroTextController ??= TextEditingController();
    _model.textFieldNumeroFocusNode ??= FocusNode();
    _model.textFieldComplementoTextController ??= TextEditingController();
    _model.textFieldComplementoFocusNode ??= FocusNode();
    _model.textFieldBairroTextController ??= TextEditingController();
    _model.textFieldBairroFocusNode ??= FocusNode();
    _model.textFieldCidadeTextController ??= TextEditingController();
    _model.textFieldCidadeFocusNode ??= FocusNode();
    _model.textFieldObservacoesTextController ??= TextEditingController();
    _model.textFieldObservacoesFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final perm =
          _modoEdicao ? 'edit_clientes' : 'create_clientes';
      if (!MembershipAccess.canPermission(perm)) {
        MembershipAccess.showDenied(
          context,
          _modoEdicao
              ? 'Sem permissão para editar clientes.'
              : 'Sem permissão para criar clientes.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
        return;
      }
      if (_modoEdicao) {
        _carregarClienteParaEdicao();
      }
    });

    if (!_modoEdicao) {
      _editDadosCarregados = true;
    }
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  bool _juridicaFromRow(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is int) return v == 1;
    final t = v.toString();
    return t == '1' || t.toLowerCase() == 'true';
  }

  Future<void> _carregarClienteParaEdicao() async {
    final uuid = widget.clienteUuid!.trim();
    try {
      final resp = await ClienteDetalhesCall.call(
        clienteUuid: uuid,
        token: FFAppState().UserToken,
      );
      if (!mounted) return;
      if (!resp.succeeded || resp.jsonBody is! Map) {
        setState(() {
          _editErroCarregamento = true;
          _editDadosCarregados = true;
        });
        return;
      }
      final r = Map<String, dynamic>.from(resp.jsonBody as Map);
      final jur = _juridicaFromRow(r['juridica']);
      _model.tipoDocumento = jur ? 'juridica' : 'fisica';
      final docDigits = _apenasDigitos(r['documento']?.toString());
      if (jur) {
        _cnpjMask = _novaMascaraCnpj(docDigits);
        _model.textFieldCnpjTextController?.text = _cnpjMask.getMaskedText();
        _model.textFieldRazaoSocialTextController?.text =
            r['nome']?.toString() ?? '';
      } else {
        _cpfMask = _novaMascaraCpf(docDigits);
        _model.textFieldCpfTextController?.text = _cpfMask.getMaskedText();
        _model.textFieldNomeTextController?.text =
            r['nome']?.toString() ?? '';
      }
      _model.documento = r['documento']?.toString();
      _model.nome = r['nome']?.toString();
      final telDigits = _apenasDigitos(r['telefone']?.toString());
      _telefoneMask = _TelefoneMaskFormatter(telDigits);
      _model.textFieldTelefoneTextController?.text =
          _telefoneMask.getMaskedText();
      _model.textFieldEmailTextController?.text =
          r['email']?.toString() ?? '';
      _model.textFieldRuaTextController?.text = r['rua']?.toString() ?? '';
      _model.textFieldNumeroTextController?.text =
          r['numero']?.toString() ?? '';
      _model.textFieldComplementoTextController?.text =
          r['complemento']?.toString() ?? '';
      _model.textFieldBairroTextController?.text =
          r['bairro']?.toString() ?? '';
      _model.textFieldCidadeTextController?.text =
          r['cidade']?.toString() ?? '';
      final uf = (r['estado']?.toString() ?? '').trim().toUpperCase();
      _model.dropDownEstadosValue =
          _kEstadosBr.contains(uf) ? uf : null;
      _model.textFieldObservacoesTextController?.text =
          r['observacoes']?.toString() ?? '';
      setState(() {
        _editDadosCarregados = true;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _editErroCarregamento = true;
          _editDadosCarregados = true;
        });
      }
    }
  }

  String get _juridicaApi => _isJuridica ? '1' : '0';

  void _sincronizarNomeDocumento() {
    if (_isJuridica) {
      _model.documento = _cnpjMask.getUnmaskedText();
      _model.nome = _model.textFieldRazaoSocialTextController?.text.trim();
    } else {
      _model.documento = _cpfMask.getUnmaskedText();
      _model.nome = _model.textFieldNomeTextController?.text.trim();
    }
  }

  void _voltar() {
    if (context.canPop()) {
      context.safePop();
    } else {
      context.pushNamed(ClientesWidget.routeName);
    }
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    _sincronizarNomeDocumento();

    final nome = (_model.nome ?? '').trim();
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isJuridica
                ? 'Informe a razão social.'
                : 'Informe o nome completo.',
          ),
        ),
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
      final ApiCallResponse resp;
      if (_modoEdicao) {
        resp = await UpdateClienteCall.call(
          clienteUuid: widget.clienteUuid,
          nome: nome,
          telefone: _telefoneMask.getUnmaskedText(),
          email: _model.textFieldEmailTextController?.text ?? '',
          juridica: _juridicaApi,
          documento: _model.documento ?? '',
          rua: _model.textFieldRuaTextController?.text ?? '',
          numero: _model.textFieldNumeroTextController?.text ?? '',
          complemento: _model.textFieldComplementoTextController?.text ?? '',
          bairro: _model.textFieldBairroTextController?.text ?? '',
          cidade: _model.textFieldCidadeTextController?.text ?? '',
          estado: _model.dropDownEstadosValue ?? '',
          observacoes: _model.textFieldObservacoesTextController?.text ?? '',
          token: token,
        );
      } else {
        resp = await CadastrarClienteCall.call(
          nome: nome,
          telefone: _telefoneMask.getUnmaskedText(),
          email: _model.textFieldEmailTextController?.text ?? '',
          juridica: _juridicaApi,
          documento: _model.documento ?? '',
          rua: _model.textFieldRuaTextController?.text ?? '',
          numero: _model.textFieldNumeroTextController?.text ?? '',
          complemento: _model.textFieldComplementoTextController?.text ?? '',
          bairro: _model.textFieldBairroTextController?.text ?? '',
          cidade: _model.textFieldCidadeTextController?.text ?? '',
          estado: _model.dropDownEstadosValue ?? '',
          observacoes: _model.textFieldObservacoesTextController?.text ?? '',
          token: token,
        );
      }

      if (!mounted) return;
      _model.apiResultys7 = resp;

      if (resp.succeeded) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _modoEdicao ? 'Cliente atualizado' : 'Cliente cadastrado',
            ),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        context.pushNamed(ClientesWidget.routeName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              resp.bodyText.isNotEmpty
                  ? resp.bodyText
                  : (_modoEdicao
                      ? 'Erro ao atualizar cliente'
                      : 'Erro ao cadastrar cliente'),
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro: $e'),
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
    final titulo = _modoEdicao ? 'Editar cliente' : 'Novo cliente';

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
                    size: 40, color: theme.secondaryText.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                Text(
                  'Cliente não encontrado. Sincronize os dados e tente novamente.',
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
                    _carregarClienteParaEdicao();
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
                    _buildTipoPessoa(theme),
                    const SizedBox(height: 10),
                    _buildIdentificacao(theme),
                    const SizedBox(height: 10),
                    _buildContato(theme),
                    const SizedBox(height: 10),
                    _buildEndereco(theme),
                    const SizedBox(height: 10),
                    _buildObservacoes(theme),
                  ],
                ),
              ),
            ),
            _buildAcoesInferiores(theme),
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
                  ? 'Atualizar dados do cliente'
                  : 'Cadastro geral do sistema',
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
                value: 'fisica',
                titulo: 'Física',
                subtitulo: 'CPF e nome',
                icon: Icons.person_outline_rounded,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _tipoBotao(
                theme,
                value: 'juridica',
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
    final selecionado = _model.tipoDocumento == value;
    return Material(
      color: selecionado ? theme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () {
          if (_model.tipoDocumento == value) return;
          setState(() => _model.tipoDocumento = value);
        },
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

  Widget _campo({
    required TextEditingController? controller,
    required FocusNode? focusNode,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.none,
    TextInputAction inputAction = TextInputAction.next,
    int maxLines = 1,
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
      maxLines: maxLines,
      autofillHints: autofillHints,
      inputFormatters: formatters,
      onChanged: onChanged,
      style: rdoFormFieldTextStyle(context),
      decoration: rdoFormFieldDecoration(
        context,
        label: label,
        hint: hint,
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
              controller: _model.textFieldCnpjTextController,
              focusNode: _model.textFieldCnpjFocusNode,
              label: 'CNPJ',
              hint: '00.000.000/0000-00',
              keyboardType: TextInputType.number,
              formatters: [_cnpjMask],
            ),
            const SizedBox(height: 10),
            _campo(
              controller: _model.textFieldRazaoSocialTextController,
              focusNode: _model.textFieldRazaoSocialFocusNode,
              label: 'Razão social *',
              hint: 'Nome da empresa',
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.organizationName],
            ),
          ] else ...[
            _campo(
              controller: _model.textFieldCpfTextController,
              focusNode: _model.textFieldCpfFocusNode,
              label: 'CPF',
              hint: '000.000.000-00',
              keyboardType: TextInputType.number,
              formatters: [_cpfMask],
            ),
            const SizedBox(height: 10),
            _campo(
              controller: _model.textFieldNomeTextController,
              focusNode: _model.textFieldNomeFocusNode,
              label: 'Nome completo *',
              hint: 'Digite o nome completo',
              capitalization: TextCapitalization.words,
              autofillHints: const [AutofillHints.name],
            ),
          ],
        ],
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
            controller: _model.textFieldTelefoneTextController,
            focusNode: _model.textFieldTelefoneFocusNode,
            label: 'Telefone',
            hint: '(00) 00000-0000',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            formatters: [_telefoneMask],
          ),
          const SizedBox(height: 10),
          _campo(
            controller: _model.textFieldEmailTextController,
            focusNode: _model.textFieldEmailFocusNode,
            label: 'E-mail',
            hint: 'exemplo@email.com',
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
          ),
        ],
      ),
    );
  }

  Widget _buildEndereco(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Endereço',
      icon: Icons.location_on_outlined,
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          _campo(
            controller: _model.textFieldRuaTextController,
            focusNode: _model.textFieldRuaFocusNode,
            label: 'Rua',
            hint: 'Nome da rua',
            capitalization: TextCapitalization.words,
            autofillHints: const [AutofillHints.streetAddressLine1],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _campo(
                  controller: _model.textFieldNumeroTextController,
                  focusNode: _model.textFieldNumeroFocusNode,
                  label: 'Número',
                  hint: '123',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _campo(
                  controller: _model.textFieldComplementoTextController,
                  focusNode: _model.textFieldComplementoFocusNode,
                  label: 'Complemento',
                  hint: 'Apto, Bloco…',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _campo(
            controller: _model.textFieldBairroTextController,
            focusNode: _model.textFieldBairroFocusNode,
            label: 'Bairro',
            hint: 'Bairro',
            capitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _campo(
                  controller: _model.textFieldCidadeTextController,
                  focusNode: _model.textFieldCidadeFocusNode,
                  label: 'Cidade',
                  hint: 'Cidade',
                  capitalization: TextCapitalization.words,
                  autofillHints: const [AutofillHints.addressCity],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  key: ValueKey(
                    'uf-${_model.dropDownEstadosValue ?? 'none'}',
                  ),
                  initialValue: _model.dropDownEstadosValue,
                  isExpanded: true,
                  decoration: rdoFormFieldDecoration(
                    context,
                    label: 'UF',
                    hint: 'Estado',
                  ),
                  style: rdoFormFieldTextStyle(context),
                  items: [
                    for (final uf in _kEstadosBr)
                      DropdownMenuItem(value: uf, child: Text(uf)),
                  ],
                  onChanged: (val) {
                    setState(() => _model.dropDownEstadosValue = val);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildObservacoes(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Observações',
      icon: Icons.notes_outlined,
      margin: EdgeInsets.zero,
      child: _campo(
        controller: _model.textFieldObservacoesTextController,
        focusNode: _model.textFieldObservacoesFocusNode,
        label: 'Observações',
        hint: 'Informações adicionais',
        maxLines: 4,
        inputAction: TextInputAction.newline,
        keyboardType: TextInputType.multiline,
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

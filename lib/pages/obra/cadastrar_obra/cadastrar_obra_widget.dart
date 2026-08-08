import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';

import 'cadastrar_obra_model.dart';
export 'cadastrar_obra_model.dart';

/// Cadastro de obra: grupo, cliente, endereço, prazo, contrato e foto opcional.
class CadastrarObraWidget extends StatefulWidget {
  const CadastrarObraWidget({super.key});

  static String routeName = 'cadastrarObra';
  static String routePath = '/cadastrarObra';

  @override
  State<CadastrarObraWidget> createState() => _CadastrarObraWidgetState();
}

class _CadastrarObraWidgetState extends State<CadastrarObraWidget> {
  late CadastrarObraModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late final Future<ApiCallResponse> _gruposFuture;
  late final Future<ApiCallResponse> _clientesFuture;

  static const _estadosBr = [
    'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG',
    'PA', 'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE',
    'TO',
  ];

  static const _espacoCampo = 10.0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CadastrarObraModel());
    _gruposFuture = ListarGrupoObrasApiCall.call(
      token: FFAppState().UserToken,
    );
    _clientesFuture = ListarClientesApiCall.call(
      token: FFAppState().UserToken,
    );

    _model.textFieldNomeTextController ??= TextEditingController();
    _model.textFieldNomeFocusNode ??= FocusNode();
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
    _model.textFieldInicioTextController ??= TextEditingController();
    _model.textFieldInicioFocusNode ??= FocusNode();
    _model.textFieldInicioMask = MaskTextInputFormatter(mask: '##/##/####');
    _model.textFieldFimTextController ??= TextEditingController();
    _model.textFieldFimFocusNode ??= FocusNode();
    _model.textFieldFimMask = MaskTextInputFormatter(mask: '##/##/####');
    _model.textFieldContratoTextController ??= TextEditingController();
    _model.textFieldContratoFocusNode ??= FocusNode();

    _model.textFieldInicioTextControllerValidator =
        (ctx, val) => _validarDataInicio(ctx, val, aoDigitar: true);
    _model.textFieldFimTextControllerValidator =
        (ctx, val) => _validarDataFim(ctx, val, aoDigitar: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('create_obras')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para criar obras.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _mapFrom(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  List<Map<String, dynamic>> _paginatedList(dynamic body, String key) {
    final root = _mapFrom(body);
    final container = _mapFrom(root?[key]);
    final data = container?['data'];
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    if (root?[key] is List) {
      return (root![key] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  String _strFrom(dynamic value) => value?.toString() ?? '';

  /// Converte `dd/mm/aaaa` (ou ISO) em data de calendário válida.
  DateTime? _parseDataBr(String? raw) {
    var t = (raw ?? '').trim();
    if (t.isEmpty) return null;

    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(t);
    if (iso != null) {
      t = '${iso.group(3)}/${iso.group(2)}/${iso.group(1)}';
    }

    final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(t);
    if (m == null) return null;

    final d = int.tryParse(m.group(1)!);
    final mo = int.tryParse(m.group(2)!);
    final y = int.tryParse(m.group(3)!);
    if (d == null || mo == null || y == null) return null;
    if (y < 1900 || y > 2100) return null;

    final dt = DateTime(y, mo, d);
    if (dt.year != y || dt.month != mo || dt.day != d) return null;
    return dt;
  }

  String? _validarDataPrazo(String? val, {bool aoDigitar = false}) {
    final t = (val ?? '').trim();
    if (t.isEmpty) return null;
    final digitos = t.replaceAll(RegExp(r'\D'), '');
    // Enquanto digita, só valida formato completo.
    if (aoDigitar && digitos.length < 8) return null;
    if (_parseDataBr(t) == null) {
      return 'Informe uma data válida (dd/mm/aaaa)';
    }
    return null;
  }

  String? _validarDataInicio(
    BuildContext context,
    String? val, {
    bool aoDigitar = false,
  }) {
    final err = _validarDataPrazo(val, aoDigitar: aoDigitar);
    if (err != null) return err;
    final di = _parseDataBr(val);
    final df = _parseDataBr(_model.textFieldFimTextController?.text);
    if (di != null && df != null && df.isBefore(di)) {
      return 'Início deve ser anterior ou igual ao fim';
    }
    return null;
  }

  String? _validarDataFim(
    BuildContext context,
    String? val, {
    bool aoDigitar = false,
  }) {
    final err = _validarDataPrazo(val, aoDigitar: aoDigitar);
    if (err != null) return err;
    final df = _parseDataBr(val);
    final di = _parseDataBr(_model.textFieldInicioTextController?.text);
    if (di != null && df != null && df.isBefore(di)) {
      return 'Fim deve ser igual ou posterior ao início';
    }
    return null;
  }

  void _revalidarDatasPrazo() {
    _model.formKey.currentState?.validate();
  }

  String _dataDdMmYyyy(String raw) {
    final parsed = _parseDataBr(raw);
    if (parsed == null) return raw.trim();
    final d = parsed.day.toString().padLeft(2, '0');
    final m = parsed.month.toString().padLeft(2, '0');
    return '$d/$m/${parsed.year}';
  }

  void _voltar() {
    if (context.canPop()) {
      context.safePop();
      return;
    }
    context.pushNamed(InicioWidget.routeName);
  }

  String _mensagemErroApi(ApiCallResponse resp) {
    final b = resp.jsonBody;
    if (b is Map) {
      final m = b['message'];
      if (m is String && m.isNotEmpty) return m;
      final errs = b['errors'];
      if (errs is Map && errs.isNotEmpty) {
        final first = errs.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        return errs.toString();
      }
    }
    if (resp.bodyText.isNotEmpty) return resp.bodyText;
    return 'Falha ao cadastrar obra (HTTP ${resp.statusCode}).';
  }

  Future<void> _cadastrarObra() async {
    if (_model.salvando) return;

    final nome = _model.textFieldNomeTextController?.text.trim() ?? '';
    if (nome.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Informe o nome da obra.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final grupoUuid =
        (_model.grupoSelected ?? _model.dropDownGruposValue ?? '').trim();
    final clienteUuid =
        (_model.clienteSelected ?? _model.dropDownClientesValue ?? '').trim();
    if (grupoUuid.isEmpty || grupoUuid == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione o grupo da obra.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    if (clienteUuid.isEmpty || clienteUuid == '0') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecione o cliente.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final inicioRaw = _model.textFieldInicioTextController?.text ?? '';
    final fimRaw = _model.textFieldFimTextController?.text ?? '';
    if (_validarDataInicio(context, inicioRaw) != null ||
        _validarDataFim(context, fimRaw) != null) {
      _revalidarDatasPrazo();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Corrija as datas de prazo antes de continuar.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final token = FFAppState().UserToken;
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Faça login novamente para cadastrar a obra.'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final estado =
        (_model.dropDownEstadosValue ?? _model.estadoSelected ?? '').trim();
    final di = _dataDdMmYyyy(_model.textFieldInicioTextController?.text ?? '');
    final df = _dataDdMmYyyy(_model.textFieldFimTextController?.text ?? '');

    safeSetState(() => _model.salvando = true);
    try {
      final resp = await CadastrarObraCall.call(
        token: token,
        nome: nome,
        grupoUuid: grupoUuid,
        clienteUuid: clienteUuid,
        rua: _model.textFieldRuaTextController?.text ?? '',
        numero: _model.textFieldNumeroTextController?.text ?? '',
        complemento: _model.textFieldComplementoTextController?.text ?? '',
        bairro: _model.textFieldBairroTextController?.text ?? '',
        cidade: _model.textFieldCidadeTextController?.text ?? '',
        estado: estado,
        engenheiro: '',
        dataInicio: di,
        dataFinal: df,
        contrato: _model.textFieldContratoTextController?.text ?? '',
        file: _model.novaFotoObra,
      );

      if (!mounted) return;

      final ok = resp.succeeded &&
          (CadastrarObraCall.result(resp.jsonBody) == true ||
              resp.statusCode == 200 ||
              resp.statusCode == 201);

      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Obra cadastrada com sucesso!'),
            backgroundColor: FlutterFlowTheme.of(context).secondary,
          ),
        );
        try {
          await actions.syncObras();
        } catch (_) {}
        if (!mounted) return;
        FFAppState().gatilhoRebuilderPage =
            FFAppState().gatilhoRebuilderPage + 1;
        FFAppState().update(() {});
        context.pushNamed(InicioWidget.routeName);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_mensagemErroApi(resp)),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
      }
    } finally {
      if (mounted) safeSetState(() => _model.salvando = false);
    }
  }

  Widget _rotuloCampo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(texto.toUpperCase(), style: rdoColumnLabelStyle(context)),
      );

  List<TextInputFormatter> _formatadorPalavras() {
    if (isAndroid || isiOS) return const [];
    return [
      TextInputFormatter.withFunction((oldValue, newValue) {
        return TextEditingValue(
          selection: newValue.selection,
          text: newValue.text.toCapitalization(TextCapitalization.words),
        );
      }),
    ];
  }

  Widget _campoTexto({
    required String label,
    required TextEditingController? controller,
    required FocusNode? focusNode,
    String? hint,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(BuildContext, String?)? validator,
    bool comFormatadorPalavras = false,
    List<TextInputFormatter>? formatters,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rotuloCampo(label),
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          autofocus: false,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          obscureText: false,
          decoration: rdoCompactFieldDecoration(context, hint: hint),
          style: rdoCompactFieldTextStyle(context),
          cursorColor: theme.primary,
          validator: validator?.asValidator(context),
          onChanged: onChanged,
          inputFormatters: formatters ??
              (comFormatadorPalavras ? _formatadorPalavras() : null),
        ),
      ],
    );
  }

  Widget _loadingCampo() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );

  Widget _dropDownIcon(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Icon(
      Icons.keyboard_arrow_down_rounded,
      color: theme.secondaryText,
      size: 18,
    );
  }

  Widget _secaoIdentificacao() {
    final theme = FlutterFlowTheme.of(context);
    return RdoSectionCard(
      title: 'Identificação',
      icon: Icons.business_outlined,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _rotuloCampo('Grupo'),
          FutureBuilder<ApiCallResponse>(
            future: _gruposFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _loadingCampo();
              final grupos = _paginatedList(
                snapshot.data!.jsonBody,
                'grupoObras',
              );
              return FlutterFlowDropDown<String>(
                controller: _model.dropDownGruposValueController ??=
                    FormFieldController<String>(_model.dropDownGruposValue),
                options: List<String>.from(
                  grupos.map((e) => _strFrom(e['uuid'])).toList(),
                ),
                optionLabels: grupos.map((e) => _strFrom(e['nome'])).toList(),
                onChanged: (val) async {
                  safeSetState(() => _model.dropDownGruposValue = val);
                  _model.grupoSelected = _model.dropDownGruposValue;
                  safeSetState(() {});
                },
                width: double.infinity,
                height: 38,
                textStyle: rdoCompactFieldTextStyle(context),
                hintText: 'Selecione o grupo da obra',
                icon: _dropDownIcon(context),
                fillColor: theme.secondaryBackground,
                elevation: 0,
                borderColor: theme.alternate,
                borderWidth: 1,
                borderRadius: 8,
                margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                hidesUnderline: true,
                isSearchable: false,
                isMultiSelect: false,
              );
            },
          ),
          const SizedBox(height: _espacoCampo),
          _rotuloCampo('Cliente'),
          FutureBuilder<ApiCallResponse>(
            future: _clientesFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _loadingCampo();
              final clientes = _paginatedList(
                snapshot.data!.jsonBody,
                'clientes',
              );
              return FlutterFlowDropDown<String>(
                controller: _model.dropDownClientesValueController ??=
                    FormFieldController<String>(_model.dropDownClientesValue),
                options: List<String>.from(
                  clientes.map((e) => _strFrom(e['uuid'])).toList(),
                ),
                optionLabels:
                    clientes.map((e) => _strFrom(e['nome'])).toList(),
                onChanged: (val) async {
                  safeSetState(() => _model.dropDownClientesValue = val);
                  _model.clienteSelected = _model.dropDownClientesValue;
                  safeSetState(() {});
                },
                width: double.infinity,
                height: 38,
                searchHintTextStyle: rdoCompactFieldTextStyle(context),
                searchTextStyle: rdoCompactFieldTextStyle(context),
                textStyle: rdoCompactFieldTextStyle(context),
                hintText: 'Selecione o cliente',
                searchHintText: 'Buscar cliente...',
                icon: _dropDownIcon(context),
                fillColor: theme.secondaryBackground,
                elevation: 0,
                borderColor: theme.alternate,
                borderWidth: 1,
                borderRadius: 8,
                margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                hidesUnderline: true,
                isSearchable: true,
                isMultiSelect: false,
              );
            },
          ),
          const SizedBox(height: _espacoCampo),
          _campoTexto(
            label: 'Nome',
            controller: _model.textFieldNomeTextController,
            focusNode: _model.textFieldNomeFocusNode,
            hint: 'Digite o nome da obra',
            textCapitalization: TextCapitalization.words,
            comFormatadorPalavras: true,
            validator: _model.textFieldNomeTextControllerValidator,
          ),
        ],
      ),
    );
  }

  Widget _secaoEndereco() {
    final theme = FlutterFlowTheme.of(context);
    return RdoSectionCard(
      title: 'Endereço',
      icon: Icons.place_outlined,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _campoTexto(
            label: 'Rua',
            controller: _model.textFieldRuaTextController,
            focusNode: _model.textFieldRuaFocusNode,
            hint: 'Nome da rua',
            textCapitalization: TextCapitalization.words,
            comFormatadorPalavras: true,
            validator: _model.textFieldRuaTextControllerValidator,
          ),
          const SizedBox(height: _espacoCampo),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _campoTexto(
                  label: 'Número',
                  controller: _model.textFieldNumeroTextController,
                  focusNode: _model.textFieldNumeroFocusNode,
                  hint: 'Número',
                  validator: _model.textFieldNumeroTextControllerValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _campoTexto(
                  label: 'Complemento',
                  controller: _model.textFieldComplementoTextController,
                  focusNode: _model.textFieldComplementoFocusNode,
                  hint: 'Complemento',
                  textCapitalization: TextCapitalization.words,
                  comFormatadorPalavras: true,
                  validator: _model.textFieldComplementoTextControllerValidator,
                ),
              ),
            ],
          ),
          const SizedBox(height: _espacoCampo),
          _campoTexto(
            label: 'Bairro',
            controller: _model.textFieldBairroTextController,
            focusNode: _model.textFieldBairroFocusNode,
            hint: 'Bairro',
            textCapitalization: TextCapitalization.words,
            comFormatadorPalavras: true,
            validator: _model.textFieldBairroTextControllerValidator,
          ),
          const SizedBox(height: _espacoCampo),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: _campoTexto(
                  label: 'Cidade',
                  controller: _model.textFieldCidadeTextController,
                  focusNode: _model.textFieldCidadeFocusNode,
                  hint: 'Cidade',
                  textCapitalization: TextCapitalization.words,
                  comFormatadorPalavras: true,
                  validator: _model.textFieldCidadeTextControllerValidator,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _rotuloCampo('Estado'),
                    FlutterFlowDropDown<String>(
                      controller: _model.dropDownEstadosValueController ??=
                          FormFieldController<String>(null),
                      options: _estadosBr,
                      onChanged: (val) async {
                        safeSetState(() => _model.dropDownEstadosValue = val);
                        _model.estadoSelected = _model.dropDownEstadosValue;
                        safeSetState(() {});
                      },
                      height: 38,
                      searchHintTextStyle: rdoCompactFieldTextStyle(context),
                      searchTextStyle: rdoCompactFieldTextStyle(context),
                      textStyle: rdoCompactFieldTextStyle(context),
                      hintText: 'Estado',
                      searchHintText: 'Buscar estado...',
                      icon: _dropDownIcon(context),
                      fillColor: theme.secondaryBackground,
                      elevation: 0,
                      borderColor: theme.alternate,
                      borderWidth: 1,
                      borderRadius: 8,
                      margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                      hidesUnderline: true,
                      isSearchable: true,
                      isMultiSelect: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _secaoPrazoContrato() {
    return RdoSectionCard(
      title: 'Prazo e contrato',
      icon: Icons.calendar_today_outlined,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _campoTexto(
                  label: 'Início',
                  controller: _model.textFieldInicioTextController,
                  focusNode: _model.textFieldInicioFocusNode,
                  hint: 'dd/mm/aaaa',
                  keyboardType: TextInputType.number,
                  formatters: [_model.textFieldInicioMask],
                  validator: _model.textFieldInicioTextControllerValidator,
                  onChanged: (_) => _revalidarDatasPrazo(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _campoTexto(
                  label: 'Fim',
                  controller: _model.textFieldFimTextController,
                  focusNode: _model.textFieldFimFocusNode,
                  hint: 'dd/mm/aaaa',
                  keyboardType: TextInputType.number,
                  formatters: [_model.textFieldFimMask],
                  validator: _model.textFieldFimTextControllerValidator,
                  onChanged: (_) => _revalidarDatasPrazo(),
                ),
              ),
            ],
          ),
          const SizedBox(height: _espacoCampo),
          _campoTexto(
            label: 'Contrato',
            controller: _model.textFieldContratoTextController,
            focusNode: _model.textFieldContratoFocusNode,
            hint: 'Número do contrato',
            textInputAction: TextInputAction.done,
          ),
        ],
      ),
    );
  }

  Widget _secaoFotoCapa() {
    final theme = FlutterFlowTheme.of(context);
    final novaFoto = _model.novaFotoObra;

    return RdoSectionCard(
      title: 'Foto de capa',
      icon: Icons.image_outlined,
      subtitle: 'Opcional',
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _model.salvando
                ? null
                : () async {
                    final picker = ImagePicker();
                    final x = await picker.pickImage(
                      source: ImageSource.gallery,
                      maxWidth: 2048,
                      imageQuality: 85,
                    );
                    if (x == null || !mounted) return;
                    final bytes = await x.readAsBytes();
                    if (!mounted) return;
                    safeSetState(() {
                      _model.novaFotoObra = FFUploadedFile(
                        name: x.name,
                        bytes: bytes,
                      );
                    });
                  },
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: Text(
              novaFoto?.name != null
                  ? 'Foto: ${novaFoto!.name}'
                  : 'Selecionar imagem (JPG/PNG)',
              style: GoogleFonts.inter(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.primaryText,
              side: BorderSide(color: theme.alternate),
              minimumSize: const Size(double.infinity, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          if (novaFoto?.bytes != null) ...[
            const SizedBox(height: _espacoCampo),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                novaFoto!.bytes!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: _model.salvando
                    ? null
                    : () => safeSetState(() => _model.novaFotoObra = null),
                icon: Icon(Icons.delete_outline, size: 18, color: theme.error),
                label: Text(
                  'Remover foto selecionada',
                  style: GoogleFonts.inter(color: theme.error),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _botoesAcao() {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _model.salvando ? null : _voltar,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                side: BorderSide(color: theme.alternate),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Cancelar',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _model.salvando
                  ? null
                  : () async {
                      if (_model.formKey.currentState?.validate() != true) {
                        return;
                      }
                      await _cadastrarObra();
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: theme.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _model.salvando
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.add_business_outlined, size: 18),
              label: Text(
                _model.salvando ? 'Cadastrando…' : 'Cadastrar',
                style: GoogleFonts.inter(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
          automaticallyImplyLeading: false,
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
                  'Nova obra',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Cadastro de obra no sistema',
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
        ),
        body: Column(
          children: [
            Expanded(
              child: Form(
                key: _model.formKey,
                autovalidateMode: AutovalidateMode.disabled,
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    0,
                    0,
                    0,
                    kBarraNavegacaoPrincipalReservaScroll,
                  ),
                  children: [
                    _secaoIdentificacao(),
                    _secaoEndereco(),
                    _secaoPrazoContrato(),
                    _secaoFotoCapa(),
                    _botoesAcao(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }
}

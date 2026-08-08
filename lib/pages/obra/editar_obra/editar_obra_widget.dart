import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'editar_obra_model.dart';
export 'editar_obra_model.dart';

class EditarObraWidget extends StatefulWidget {
  const EditarObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'editarObra';
  static String routePath = '/editarObra';

  @override
  State<EditarObraWidget> createState() => _EditarObraWidgetState();
}

class _EditarObraWidgetState extends State<EditarObraWidget> {
  late EditarObraModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  late final Future<ApiCallResponse> _obraFuture;
  late final Future<ApiCallResponse> _situacoesFuture;
  late final Future<ApiCallResponse> _gruposFuture;
  late final Future<ApiCallResponse> _clientesFuture;

  static const _estadosBr = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];

  static const _espacoCampo = 10.0;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditarObraModel());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('edit_obras')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para editar obras.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
      }
    });

    _obraFuture = ObraDetalhesApiCall.call(
      token: FFAppState().UserToken,
      obraServidorId: widget.obraId,
      obraUuid: widget.obraUuid,
    );
    _situacoesFuture = ListarSituacoesObrasCall.call(
      token: FFAppState().UserToken,
    );
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
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _dataParaExibir(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    final s = raw.trim();
    if (s.length >= 10 && s[4] == '-' && s[7] == '-') {
      final y = s.substring(0, 4);
      final m = s.substring(5, 7);
      final d = s.substring(8, 10);
      return '$d/$m/$y';
    }
    return s;
  }

  Map<String, dynamic>? _mapFrom(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
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

  int? _intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _strFrom(dynamic value) => value?.toString() ?? '';

  void _aplicarDadosDaObra(Map<String, dynamic> o) {
    _model.textFieldNomeTextController?.text = _strFrom(o['nome']);
    _model.textFieldRuaTextController?.text = _strFrom(o['rua']);
    _model.textFieldNumeroTextController?.text = _strFrom(o['numero']);
    _model.textFieldComplementoTextController?.text =
        _strFrom(o['complemento']);
    _model.textFieldBairroTextController?.text = _strFrom(o['bairro']);
    _model.textFieldCidadeTextController?.text = _strFrom(o['cidade']);
    final inicioExibir = _dataParaExibir(o['data_inicio']?.toString());
    final fimExibir = _dataParaExibir(o['data_final']?.toString());
    _model.textFieldInicioMask = MaskTextInputFormatter(
      mask: '##/##/####',
      filter: {'#': RegExp(r'[0-9]')},
      initialText: inicioExibir,
      type: MaskAutoCompletionType.lazy,
    );
    _model.textFieldFimMask = MaskTextInputFormatter(
      mask: '##/##/####',
      filter: {'#': RegExp(r'[0-9]')},
      initialText: fimExibir,
      type: MaskAutoCompletionType.lazy,
    );
    _model.textFieldInicioTextController?.text =
        _model.textFieldInicioMask.getMaskedText();
    _model.textFieldFimTextController?.text =
        _model.textFieldFimMask.getMaskedText();

    final gid = _intFrom(o['grupo_id']) ?? 0;
    _model.dropDownGruposValue = gid;
    _model.dropDownGruposValueController?.value = gid;
    _model.grupoSelected = gid;
    _model.grupoUuidSelected = o['grupo_uuid']?.toString();

    final cid = _intFrom(o['cliente_id']) ?? 0;
    _model.dropDownClientesValue = cid;
    _model.dropDownClientesValueController?.value = cid;
    _model.clienteSelected = cid;
    _model.clienteUuidSelected = o['cliente_uuid']?.toString();

    final est = _strFrom(o['estado']).trim();
    if (est.isNotEmpty) {
      final uf = est.length >= 2 ? est.substring(0, 2).toUpperCase() : est;
      _model.dropDownEstadosValue = uf;
      _model.dropDownEstadosValueController?.value = uf;
      _model.estadoSelected = uf;
    }

    _model.textFieldContratoTextController?.text = _strFrom(o['contrato']);
    _model.engenheiroPersistido = _strFrom(o['engenheiro']);

    final sid = _intFrom(o['situacao_id']);
    if (sid != null) {
      _model.dropDownSituacaoValue = sid;
      _model.dropDownSituacaoValueController?.value = sid;
    }
  }

  String _dataDdMmYyyy(String raw) {
    final parsed = _parseDataBr(raw);
    if (parsed != null) {
      final d = parsed.day.toString().padLeft(2, '0');
      final m = parsed.month.toString().padLeft(2, '0');
      return '$d/$m/${parsed.year}';
    }
    final t = raw.trim();
    if (t.isEmpty) return '';
    List<String> p;
    if (t.contains('/')) {
      p = t.split('/');
    } else if (t.contains('-')) {
      p = t.split('-');
    } else {
      return t;
    }
    if (p.length != 3) return t;
    var d = p[0].trim().padLeft(2, '0');
    var m = p[1].trim().padLeft(2, '0');
    var y = p[2].trim();
    if (y.length == 2) y = '20$y';
    return '$d/$m/$y';
  }

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
    return 'Falha ao salvar (HTTP ${resp.statusCode}).';
  }

  Future<void> _salvarObraNaApiESincronizar(BuildContext context) async {
    if (_model.salvando) return;
    final token = FFAppState().UserToken;
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Faça login novamente para editar a obra.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final idServidor = widget.obraId;
    if (idServidor == null || idServidor <= 0) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Esta obra ainda não está vinculada ao servidor. Sincronize as obras antes de editar.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final gid = _model.dropDownGruposValue ?? _model.grupoSelected ?? 0;
    final cid = _model.dropDownClientesValue ?? _model.clienteSelected ?? 0;
    final sid = _model.dropDownSituacaoValue;
    if (sid == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecione a situação da obra.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final estado =
        (_model.dropDownEstadosValue ?? _model.estadoSelected ?? '').trim();
    final inicioRaw = _model.textFieldInicioTextController?.text ?? '';
    final fimRaw = _model.textFieldFimTextController?.text ?? '';
    if (_validarDataInicio(context, inicioRaw) != null ||
        _validarDataFim(context, fimRaw) != null) {
      _revalidarDatasPrazo();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Corrija as datas de prazo antes de continuar.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }

    final di = _dataDdMmYyyy(inicioRaw);
    final df = _dataDdMmYyyy(fimRaw);

    safeSetState(() => _model.salvando = true);
    try {
      final resp = await AtualizarObraCall.call(
        token: token,
        obraServidorId: idServidor,
        obraUuid: widget.obraUuid,
        nome: _model.textFieldNomeTextController?.text ?? '',
        grupoId: gid,
        clienteId: cid,
        grupoUuid: _model.grupoUuidSelected ?? '',
        clienteUuid: _model.clienteUuidSelected ?? '',
        situacaoId: sid,
        rua: _model.textFieldRuaTextController?.text ?? '',
        numero: _model.textFieldNumeroTextController?.text ?? '',
        complemento: _model.textFieldComplementoTextController?.text ?? '',
        bairro: _model.textFieldBairroTextController?.text ?? '',
        cidade: _model.textFieldCidadeTextController?.text ?? '',
        estado: estado,
        dataInicio: di,
        dataFinal: df,
        contrato: _model.textFieldContratoTextController?.text ?? '',
        file: _model.novaFotoObra,
      );

      if (!context.mounted) return;

      if (resp.statusCode != 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _mensagemErroApi(resp),
              style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
            ),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }

      await actions.syncObras();

      if (!context.mounted) return;
      FFAppState().update(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Obra atualizada no servidor e sincronizada.',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).primaryText,
            ),
          ),
          duration: const Duration(milliseconds: 3500),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
      context.safePop();
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

  Widget _secaoIdentificacao(Map<String, dynamic> obra) {
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
              return FlutterFlowDropDown<int>(
                key: ValueKey<String>(
                  'grupo_${obra['uuid']}_${_model.dropDownGruposValue}',
                ),
                controller: _model.dropDownGruposValueController ??=
                    FormFieldController<int>(_model.dropDownGruposValue),
                options: List<int>.from(
                  grupos.map((e) => _intFrom(e['id']) ?? 0).toList(),
                ),
                optionLabels: grupos.map((e) => _strFrom(e['nome'])).toList(),
                onChanged: (val) async {
                  safeSetState(() => _model.dropDownGruposValue = val);
                  _model.grupoSelected = _model.dropDownGruposValue;
                  _model.grupoUuidSelected = grupos
                      .where((e) => _intFrom(e['id']) == val)
                      .map((e) => e['uuid']?.toString())
                      .firstOrNull;
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
              return FlutterFlowDropDown<int>(
                key: ValueKey<String>(
                  'cli_${obra['uuid']}_${_model.dropDownClientesValue}',
                ),
                controller: _model.dropDownClientesValueController ??=
                    FormFieldController<int>(_model.dropDownClientesValue),
                options: List<int>.from(
                  clientes.map((e) => _intFrom(e['id']) ?? 0).toList(),
                ),
                optionLabels:
                    clientes.map((e) => _strFrom(e['nome'])).toList(),
                onChanged: (val) async {
                  safeSetState(() => _model.dropDownClientesValue = val);
                  _model.clienteSelected = _model.dropDownClientesValue;
                  _model.clienteUuidSelected = clientes
                      .where((e) => _intFrom(e['id']) == val)
                      .map((e) => e['uuid']?.toString())
                      .firstOrNull;
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
          const SizedBox(height: _espacoCampo),
          _rotuloCampo('Situação'),
          FutureBuilder<ApiCallResponse>(
            future: _situacoesFuture,
            builder: (context, situSnap) {
              if (!situSnap.hasData) return _loadingCampo();
              final resp = situSnap.data!;
              final body = resp.jsonBody;
              final ids = <int>[];
              final labels = <String>[];
              if (body is List) {
                for (final e in body) {
                  if (e is! Map) continue;
                  final idRaw = e['id'];
                  final nome = e['nome']?.toString() ?? '';
                  int? ii;
                  if (idRaw is int) {
                    ii = idRaw;
                  } else if (idRaw != null) {
                    ii = int.tryParse(idRaw.toString());
                  }
                  if (ii != null) {
                    ids.add(ii);
                    labels.add(nome);
                  }
                }
              }
              if (ids.isEmpty) {
                return Text(
                  'Não foi possível carregar as situações.',
                  style: FlutterFlowTheme.of(context).bodySmall,
                );
              }
              var val = _model.dropDownSituacaoValue;
              if (val == null || !ids.contains(val)) {
                val = ids.first;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  safeSetState(() {
                    _model.dropDownSituacaoValue = val;
                    _model.dropDownSituacaoValueController?.value = val;
                  });
                });
              }
              return FlutterFlowDropDown<int>(
                controller: _model.dropDownSituacaoValueController ??=
                    FormFieldController<int>(val),
                options: ids,
                optionLabels: labels,
                onChanged: (v) async {
                  safeSetState(() => _model.dropDownSituacaoValue = v);
                },
                width: double.infinity,
                height: 38,
                textStyle: rdoCompactFieldTextStyle(context),
                hintText: 'Situação da obra',
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

  Widget _secaoFotoCapa(Map<String, dynamic> obra) {
    final theme = FlutterFlowTheme.of(context);
    final fotoUrl = _strFrom(obra['foto_url']).trim();
    final novaFoto = _model.novaFotoObra;

    return RdoSectionCard(
      title: 'Foto de capa',
      icon: Icons.image_outlined,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (fotoUrl.isNotEmpty && novaFoto == null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                fotoUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 120,
                  alignment: Alignment.center,
                  color: theme.alternate.withValues(alpha: 0.3),
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: theme.secondaryText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: _espacoCampo),
          ],
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
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Remover foto selecionada'),
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
              onPressed: _model.salvando ? null : () => context.safePop(),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 40),
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
                      await _salvarObraNaApiESincronizar(context);
                    },
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                backgroundColor: theme.primary,
                disabledBackgroundColor: theme.primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _model.salvando
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: theme.info,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(
                _model.salvando ? 'Salvando...' : 'Salvar',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.info,
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.safePop(),
          ),
          title: FutureBuilder<ApiCallResponse>(
            future: _obraFuture,
            builder: (context, snap) {
              final obraNome = snap.hasData
                  ? _strFrom(
                      _mapFrom(_mapFrom(snap.data!.jsonBody)?['obra'])?['nome'],
                    )
                  : '';
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Editar Obra',
                      style: GoogleFonts.interTight(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    if (obraNome.isNotEmpty)
                      Text(
                        obraNome,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        body: SafeArea(
          top: true,
          child: FutureBuilder<ApiCallResponse>(
            future: _obraFuture,
            builder: (context, obraSnap) {
              if (!obraSnap.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: theme.primary),
                );
              }
              final obra = _mapFrom(_mapFrom(obraSnap.data!.jsonBody)?['obra']);
              if (obra == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Obra não encontrada.',
                      textAlign: TextAlign.center,
                      style: theme.bodyMedium,
                    ),
                  ),
                );
              }
              if (!_model.dadosObraCarregados) {
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted || _model.dadosObraCarregados) return;
                  _model.dadosObraCarregados = true;
                  _aplicarDadosDaObra(obra);
                  if (mounted) setState(() {});
                });
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 24),
                child: Form(
                  key: _model.formKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _secaoIdentificacao(obra),
                      _secaoEndereco(),
                      _secaoPrazoContrato(),
                      _secaoFotoCapa(obra),
                      _botoesAcao(),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

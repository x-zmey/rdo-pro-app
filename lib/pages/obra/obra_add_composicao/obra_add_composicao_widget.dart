import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/brazilian_currency_input_formatter.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../planejamento_api_rows.dart';
import 'obra_add_composicao_model.dart';
export 'obra_add_composicao_model.dart';

/// Cadastro de composição (insumo / equipamento / mão de obra) via `POST .../add-tarefa`,
/// alinhado ao drawer web `AddNewComposicaoDrawer.vue`.
class ObraAddComposicaoWidget extends StatefulWidget {
  const ObraAddComposicaoWidget({
    super.key,
    required this.obraUuid,
    this.obraId,
    this.etapaUuidInicial,
  });

  final String obraUuid;
  final int? obraId;
  final String? etapaUuidInicial;

  static String routeName = 'obraAddComposicao';
  static String routePath = '/obraAddComposicao';

  @override
  State<ObraAddComposicaoWidget> createState() =>
      _ObraAddComposicaoWidgetState();
}

class _ObraAddComposicaoWidgetState extends State<ObraAddComposicaoWidget> {
  static final _valorUnitarioMask = BrazilianCurrencyInputFormatter();

  late ObraAddComposicaoModel _model;
  late final Future<List<ListaEtapasObraRow>> _etapasFuture;
  bool _inicializou = false;

  List<String> _paiIds = [];
  List<String> _paiLabels = [];
  bool _carregandoPais = false;

  static const _tipos = ['insumo', 'equipamento', 'mao_obra'];
  static const _tipoLabels = ['Insumo', 'Equipamento', 'Mão de obra'];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ObraAddComposicaoModel());
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
    _etapasFuture = _carregarEtapasApi();

    _model.itemTextController ??= TextEditingController();
    _model.itemFocusNode ??= FocusNode();
    _model.descricaoTextController ??= TextEditingController();
    _model.descricaoFocusNode ??= FocusNode();
    _model.qtdTextController ??= TextEditingController(text: '1');
    _model.qtdFocusNode ??= FocusNode();
    _model.unidadeTextController ??= TextEditingController(text: 'un');
    _model.unidadeFocusNode ??= FocusNode();
    _model.valorUnitTextController ??= TextEditingController(text: '0,00');
    _model.valorUnitFocusNode ??= FocusNode();
    _model.metaTextController ??= TextEditingController(text: '0');
    _model.metaFocusNode ??= FocusNode();
    _model.metaUnidadeTextController ??= TextEditingController();
    _model.metaUnidadeFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  String _parseUltimoItem(dynamic body) {
    if (body == null) return '1';
    if (body is String) return body;
    if (body is num) return body.toString();
    return '1';
  }

  Future<List<ListaEtapasObraRow>> _carregarEtapasApi() async {
    final token = FFAppState().UserToken;
    if (token.isEmpty) return [];

    final resp = await ListarEtapasObraApiCall.call(
      token: token,
      obraServidorId: widget.obraId,
      obraUuid: widget.obraUuid,
    );
    if (resp.statusCode != 200) return [];

    return parseEtapasPlanejamento(resp.jsonBody);
  }

  List<Map<String, dynamic>> _parseTarefasPai(dynamic body) {
    if (body is! List) return [];
    final out = <Map<String, dynamic>>[];
    for (final e in body) {
      if (e is! Map) continue;
      final uuid = e['uuid']?.toString().trim();
      if (uuid == null || uuid.isEmpty) continue;
      out.add({
        'id': uuid,
        'descricao': e['descricao']?.toString() ?? '',
      });
    }
    return out;
  }

  Future<void> _carregarTarefasPai(String etapaUuid) async {
    final token = FFAppState().UserToken;
    if (token.isEmpty) return;
    safeSetState(() => _carregandoPais = true);
    try {
      final resp = await GetTarefasPaiEtapaCall.call(
        token: token,
        etapaUuid: etapaUuid,
      );
      if (!mounted) return;
      final list = resp.statusCode == 200
          ? _parseTarefasPai(resp.jsonBody)
          : <Map<String, dynamic>>[];
      final ids = list.map((m) => '${m['id']}').toList();
      final labels = list.map((m) => m['descricao'] as String).toList();
      safeSetState(() {
        _paiIds = ids;
        _paiLabels = labels;
        _model.dropDownTarefaPaiIdValue = null;
        _model.dropDownTarefaPaiIdValueController?.dispose();
        _model.dropDownTarefaPaiIdValueController = ids.isEmpty
            ? FormFieldController<String>(null)
            : FormFieldController<String>(null);
      });
    } finally {
      if (mounted) safeSetState(() => _carregandoPais = false);
    }
  }

  Future<void> _atualizarItemInsumoEtapa(String etapaUuid) async {
    if (etapaUuid.isEmpty) {
      safeSetState(() => _model.itemTextController?.text = '1');
      return;
    }
    final token = FFAppState().UserToken;
    if (token.isEmpty) return;
    final resp = await UltimoItemEtapaPorTipoCall.call(
      token: token,
      etapaUuid: etapaUuid,
      tipo: 'insumo',
    );
    if (!mounted) return;
    if (resp.statusCode == 200) {
      safeSetState(() {
        _model.itemTextController?.text = _parseUltimoItem(resp.jsonBody);
      });
    } else {
      safeSetState(() => _model.itemTextController?.text = '1');
    }
  }

  Future<void> _atualizarItemComposicao(String tarefaPaiUuid) async {
    final token = FFAppState().UserToken;
    if (token.isEmpty) return;
    final resp = await UltimoItemComposicaoCall.call(
      token: token,
      tarefaPaiUuid: tarefaPaiUuid,
    );
    if (!mounted) return;
    if (resp.statusCode == 200) {
      safeSetState(() {
        _model.itemTextController?.text = _parseUltimoItem(resp.jsonBody);
      });
    }
  }

  Future<void> _onEtapaChanged(String? etapaUuid) async {
    safeSetState(() => _model.dropDownEtapaUuidValue = etapaUuid);
    if (etapaUuid == null || etapaUuid.isEmpty) return;
    await _carregarTarefasPai(etapaUuid);
    await _atualizarItemInsumoEtapa(etapaUuid);
  }

  Future<void> _salvar() async {
    if (_model.salvando) return;
    if (_model.formKey.currentState?.validate() != true) return;
    // O FlutterFlowDropDown grava em FormFieldController; o listener nem sempre
    // repassa para os campos do model — usar o controller como fonte de verdade.
    final etapaUuid = (_model.dropDownEtapaUuidValueController?.value ??
            _model.dropDownEtapaUuidValue)
        ?.trim();
    if (etapaUuid == null || etapaUuid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione a etapa.',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).primaryText)),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    final paiStr = (_model.dropDownTarefaPaiIdValueController?.value ??
            _model.dropDownTarefaPaiIdValue)
        ?.trim();
    final tarefaPai = paiStr;
    if (tarefaPai == null || tarefaPai.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione a tarefa (pai).',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).primaryText)),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    final tipo =
        (_model.dropDownTipoValueController?.value ?? _model.dropDownTipoValue)
            ?.trim();
    if (tipo == null || tipo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selecione o tipo.',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).primaryText)),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
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
    final descricao = _model.descricaoTextController?.text.trim() ?? '';
    final qtdStr =
        _model.qtdTextController?.text.trim().replaceAll(',', '.') ?? '';
    final qtd = double.tryParse(qtdStr);
    if (qtd == null || qtd < 0.01) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Quantidade inválida (mín. 0,01).',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).primaryText)),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    final unidade = _model.unidadeTextController?.text.trim() ?? '';
    if (unidade.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Informe a unidade.',
              style:
                  TextStyle(color: FlutterFlowTheme.of(context).primaryText)),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    final vu = parseBrazilianCurrencyInput(
      _model.valorUnitTextController?.text ?? '0,00',
    );
    final meta = double.tryParse(
          _model.metaTextController?.text.trim().replaceAll(',', '.') ?? '',
        ) ??
        0;
    final metaUn = _model.metaUnidadeTextController?.text.trim() ?? '';

    safeSetState(() => _model.salvando = true);
    try {
      final resp = await AddObraTarefaCall.call(
        token: token,
        etapaUuid: etapaUuid,
        item: item.isEmpty ? '1' : item,
        tarefaPai: tarefaPai,
        tipo: tipo,
        local: null,
        descricao: descricao,
        qtd: qtd,
        unidade: unidade,
        valorUnitario: vu,
        meta: meta,
        metaUnidade: metaUn.isEmpty ? null : metaUn,
      );
      if (!mounted) return;
      if (resp.statusCode != 200) {
        String msg = 'Não foi possível salvar a composição.';
        if (resp.jsonBody is Map) {
          final m = resp.jsonBody as Map;
          if (m['error'] != null) msg = m['error'].toString();
          final det = m['details'];
          if (det != null) {
            if (det is Map && det.isNotEmpty) {
              msg = '$msg\n${det.values.first}';
            } else {
              msg = '$msg\n${det.toString()}';
            }
          }
        }
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
      await actions.syncObrasTarefas();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Composição criada e sincronizada.',
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
            'Nova composição',
            style: theme.titleLarge.override(
              font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
              color: theme.primaryText,
            ),
          ),
        ),
        body: SafeArea(
          child: FutureBuilder<List<ListaEtapasObraRow>>(
            future: _etapasFuture,
            builder: (context, snap) {
              if (!snap.hasData) {
                return Center(
                    child: LinearProgressIndicator(color: theme.primary));
              }
              final etapas = snap.data!;
              if (etapas.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Não há etapas nesta obra. Cadastre uma etapa antes.',
                    style: theme.bodyMedium,
                  ),
                );
              }
              final uuids = etapas.map((e) => e.uuid).toList();
              final labels = etapas
                  .map((e) => '${e.item ?? ''} · ${e.nome ?? ''}'.trim())
                  .toList();

              if (!_inicializou) {
                _inicializou = true;
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  if (!mounted) return;
                  final pre = widget.etapaUuidInicial;
                  final sel =
                      (pre != null && pre.isNotEmpty && uuids.contains(pre))
                          ? pre
                          : uuids.first;
                  safeSetState(() {
                    _model.dropDownEtapaUuidValue = sel;
                    _model.dropDownEtapaUuidValueController ??=
                        FormFieldController<String>(sel);
                    _model.dropDownEtapaUuidValueController?.value = sel;
                  });
                  await _carregarTarefasPai(sel);
                  await _atualizarItemInsumoEtapa(sel);
                });
              }

              return Form(
                key: _model.formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'Insumo, equipamento ou mão de obra vinculados a uma tarefa (mesmo endpoint do web).',
                      style: theme.bodySmall.override(
                        font: GoogleFonts.inter(),
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Etapa', style: theme.labelMedium),
                    const SizedBox(height: 6),
                    FlutterFlowDropDown<String>(
                      controller: _model.dropDownEtapaUuidValueController ??=
                          FormFieldController<String>(
                              _model.dropDownEtapaUuidValue),
                      options: uuids,
                      optionLabels: labels,
                      onChanged: (val) async {
                        await _onEtapaChanged(val);
                      },
                      width: double.infinity,
                      height: 56,
                      textStyle: theme.bodyMedium,
                      hintText: 'Selecione a etapa',
                      icon: Icon(Icons.keyboard_arrow_down_rounded,
                          color: theme.secondaryText),
                      fillColor: theme.primaryBackground,
                      elevation: 0,
                      borderColor: theme.alternate,
                      borderWidth: 1,
                      borderRadius: 12,
                      margin: EdgeInsets.zero,
                      hidesUnderline: true,
                      isSearchable: true,
                      isMultiSelect: false,
                    ),
                    const SizedBox(height: 16),
                    Text('Tarefa (pai)', style: theme.labelMedium),
                    const SizedBox(height: 6),
                    if (_carregandoPais)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: LinearProgressIndicator(color: theme.primary),
                      )
                    else
                      FlutterFlowDropDown<String>(
                        key: ValueKey<String>(
                          '${_model.dropDownEtapaUuidValue}_${_paiIds.join()}',
                        ),
                        controller:
                            _model.dropDownTarefaPaiIdValueController ??=
                                FormFieldController<String>(
                                    _model.dropDownTarefaPaiIdValue),
                        options: _paiIds,
                        optionLabels: _paiLabels,
                        onChanged: (val) async {
                          safeSetState(
                              () => _model.dropDownTarefaPaiIdValue = val);
                          if (val != null && val.trim().isNotEmpty) {
                            await _atualizarItemComposicao(val.trim());
                          }
                        },
                        width: double.infinity,
                        height: 56,
                        textStyle: theme.bodyMedium,
                        hintText: _paiIds.isEmpty
                            ? 'Nenhuma tarefa nesta etapa'
                            : 'Selecione a tarefa',
                        disabled: _paiIds.isEmpty,
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: theme.secondaryText),
                        fillColor: theme.primaryBackground,
                        elevation: 0,
                        borderColor: theme.alternate,
                        borderWidth: 1,
                        borderRadius: 12,
                        margin: EdgeInsets.zero,
                        hidesUnderline: true,
                        isSearchable: true,
                        isMultiSelect: false,
                      ),
                    const SizedBox(height: 16),
                    Text('Tipo', style: theme.labelMedium),
                    const SizedBox(height: 6),
                    FlutterFlowDropDown<String>(
                      controller: _model.dropDownTipoValueController ??=
                          FormFieldController<String>(_model.dropDownTipoValue),
                      options: _tipos,
                      optionLabels: _tipoLabels,
                      onChanged: (val) =>
                          safeSetState(() => _model.dropDownTipoValue = val),
                      width: double.infinity,
                      height: 56,
                      textStyle: theme.bodyMedium,
                      hintText: 'Selecione o tipo',
                      icon: Icon(Icons.keyboard_arrow_down_rounded,
                          color: theme.secondaryText),
                      fillColor: theme.primaryBackground,
                      elevation: 0,
                      borderColor: theme.alternate,
                      borderWidth: 1,
                      borderRadius: 12,
                      margin: EdgeInsets.zero,
                      hidesUnderline: true,
                      isSearchable: false,
                      isMultiSelect: false,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _model.itemTextController,
                      focusNode: _model.itemFocusNode,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Nº item (próximo sugerido)',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _model.descricaoTextController,
                      focusNode: _model.descricaoFocusNode,
                      decoration: InputDecoration(
                        labelText: 'Descrição',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe a descrição'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _model.qtdTextController,
                            focusNode: _model.qtdFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Quantidade',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _model.unidadeTextController,
                            focusNode: _model.unidadeFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Unidade',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _model.valorUnitTextController,
                      focusNode: _model.valorUnitFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_valorUnitarioMask],
                      decoration: InputDecoration(
                        labelText: 'Valor unitário',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Informe o valor unitário'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _model.metaTextController,
                            focusNode: _model.metaFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: 'Meta (opcional)',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _model.metaUnidadeTextController,
                            focusNode: _model.metaUnidadeFocusNode,
                            decoration: InputDecoration(
                              labelText: 'Meta unidade',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: FFButtonWidget(
                            onPressed: _model.salvando
                                ? null
                                : () => context.safePop(),
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
                            onPressed: (etapas.isEmpty || _model.salvando)
                                ? null
                                : _salvar,
                            text: _model.salvando ? 'Salvando…' : 'Salvar',
                            options: FFButtonOptions(
                              height: 48,
                              color: theme.primary,
                              textStyle: theme.titleSmall.override(
                                font:
                                    GoogleFonts.interTight(color: Colors.white),
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
              );
            },
          ),
        ),
      ),
    );
  }
}

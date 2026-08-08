import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/brazilian_currency_input_formatter.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../planejamento_api_rows.dart';
import 'obra_add_tarefa_model.dart';
export 'obra_add_tarefa_model.dart';

List<String> _parseLocaisNomesFromApi(dynamic body) {
  List? list;
  if (body is List) {
    list = body;
  } else if (body is Map) {
    final d = body['data'];
    if (d is List) {
      list = d;
    } else if (d is Map && d['data'] is List) {
      list = d['data'] as List;
    } else if (d is Map && d['value'] is List) {
      list = d['value'] as List;
    }
  }
  if (list == null) return [];
  final out = <String>[];
  for (final e in list) {
    if (e is Map) {
      final n = e['nome']?.toString().trim();
      if (n != null && n.isNotEmpty) out.add(n);
    }
  }
  return out;
}

/// Cadastro de tarefa na API (`POST .../add-tarefa`) e sync `obra_etapa_tarefas` (+ etapas).
class ObraAddTarefaWidget extends StatefulWidget {
  const ObraAddTarefaWidget({
    super.key,
    required this.obraUuid,
    this.obraId,
    this.etapaUuidInicial,
  });

  final String obraUuid;
  final int? obraId;
  final String? etapaUuidInicial;

  static String routeName = 'obraAddTarefa';
  static String routePath = '/obraAddTarefa';

  @override
  State<ObraAddTarefaWidget> createState() => _ObraAddTarefaWidgetState();
}

class _ObraAddTarefaWidgetState extends State<ObraAddTarefaWidget> {
  static final _valorUnitarioMask = BrazilianCurrencyInputFormatter();

  late ObraAddTarefaModel _model;
  late final Future<List<ListaEtapasObraRow>> _etapasFuture;
  late final Future<List<String>> _locaisFuture;
  bool _inicializouItem = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ObraAddTarefaModel());
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
    _locaisFuture = _carregarLocaisNomes();

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

  Future<List<String>> _carregarLocaisNomes() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return [];
    final r = await ObraLocaisPorObraCall.call(
      token: token,
      obraServidorId: widget.obraId,
      obraUuid: widget.obraUuid,
    );
    if (r.statusCode < 200 || r.statusCode >= 300) return [];
    return _parseLocaisNomesFromApi(r.jsonBody);
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

  Future<void> _atualizarItemParaEtapa(String etapaUuid) async {
    if (etapaUuid.isEmpty) {
      safeSetState(() => _model.itemTextController?.text = '1');
      return;
    }
    final token = FFAppState().UserToken;
    if (token.isEmpty) return;
    final resp = await UltimoItemTarefaObraCall.call(
      token: token,
      etapaUuid: etapaUuid,
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

  Future<void> _salvar() async {
    if (_model.salvando) return;
    if (_model.formKey.currentState?.validate() != true) return;
    final etapaUuid = _model.dropDownEtapaUuidValue;
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
    final locaisList = await _locaisFuture;
    final item = _model.itemTextController?.text.trim() ?? '';
    final descricao = _model.descricaoTextController?.text.trim() ?? '';
    final local = (_model.dropDownLocalNomeValueController?.value ??
                _model.dropDownLocalNomeValue)
            ?.trim() ??
        '';
    if (locaisList.isNotEmpty && local.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Selecione o local.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
    if (locaisList.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não há locais cadastrados nesta obra. Cadastre locais antes de criar a tarefa.',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
      return;
    }
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
            _model.metaTextController?.text.trim().replaceAll(',', '.') ??
                '') ??
        0;
    final metaUn = _model.metaUnidadeTextController?.text.trim() ?? '';

    safeSetState(() => _model.salvando = true);
    try {
      final resp = await AddObraTarefaCall.call(
        token: token,
        etapaUuid: etapaUuid,
        item: item.isEmpty ? '1' : item,
        tipo: 'tarefa',
        local: local,
        descricao: descricao,
        qtd: qtd,
        unidade: unidade,
        valorUnitario: vu,
        meta: meta,
        metaUnidade: metaUn.isEmpty ? null : metaUn,
      );
      if (!mounted) return;
      if (resp.statusCode != 200) {
        String msg = 'Não foi possível salvar a tarefa.';
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
            'Tarefa criada e sincronizada.',
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
        appBar: _buildAppBar(theme),
        body: SafeArea(
          child: FutureBuilder<List<ListaEtapasObraRow>>(
            future: _etapasFuture,
            builder: (context, snap) {
              if (!snap.hasData) {
                return Center(
                  child: CircularProgressIndicator(color: theme.primary),
                );
              }
              final etapas = snap.data!;
              if (etapas.isEmpty) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                  children: [
                    RdoSectionCard(
                      title: 'Vínculo',
                      icon: Icons.link_rounded,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Não há etapas nesta obra. Cadastre uma etapa antes de adicionar tarefas.',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: theme.secondaryText,
                        ),
                      ),
                    ),
                  ],
                );
              }
              final uuids = etapas.map((e) => e.uuid).toList();
              final labels = etapas
                  .map((e) => '${e.item ?? ''} · ${e.nome ?? ''}'.trim())
                  .toList();

              if (!_inicializouItem) {
                _inicializouItem = true;
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
                  await _atualizarItemParaEtapa(sel);
                });
              }

              return Form(
                key: _model.formKey,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                        children: [
                          RdoSectionCard(
                            title: 'Vínculo',
                            icon: Icons.link_rounded,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FlutterFlowDropDown<String>(
                                  controller:
                                      _model.dropDownEtapaUuidValueController ??=
                                          FormFieldController<String>(
                                              _model.dropDownEtapaUuidValue),
                                  options: uuids,
                                  optionLabels: labels,
                                  onChanged: (val) async {
                                    safeSetState(
                                        () => _model.dropDownEtapaUuidValue =
                                            val);
                                    if (val != null && val.isNotEmpty) {
                                      await _atualizarItemParaEtapa(val);
                                    }
                                  },
                                  width: double.infinity,
                                  height: 48,
                                  textStyle: rdoFormFieldTextStyle(context),
                                  hintText: 'Selecione a etapa',
                                  icon: Icon(Icons.keyboard_arrow_down_rounded,
                                      color: theme.secondaryText),
                                  fillColor: theme.secondaryBackground,
                                  elevation: 0,
                                  borderColor: theme.alternate,
                                  borderWidth: 1,
                                  borderRadius: 8,
                                  margin: EdgeInsets.zero,
                                  hidesUnderline: true,
                                  isSearchable: true,
                                  isMultiSelect: false,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _model.itemTextController,
                                  focusNode: _model.itemFocusNode,
                                  readOnly: true,
                                  style: rdoFormFieldTextStyle(context),
                                  decoration: rdoFormFieldDecoration(
                                    context,
                                    label: 'Nº item (próximo sugerido)',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                FutureBuilder<List<String>>(
                                  future: _locaisFuture,
                                  builder: (context, locSnap) {
                                    if (locSnap.connectionState !=
                                        ConnectionState.done) {
                                      return const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 12),
                                        child: Center(
                                          child: SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final locais = locSnap.data ?? [];
                                    if (locais.isEmpty) {
                                      return Text(
                                        'Nenhum local cadastrado nesta obra. Cadastre locais em Locais da obra.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: theme.secondaryText,
                                        ),
                                      );
                                    }
                                    return FlutterFlowDropDown<String>(
                                      key: ValueKey<String>(
                                          locais.join('\u0001')),
                                      controller: _model
                                              .dropDownLocalNomeValueController ??=
                                          FormFieldController<String>(
                                              _model.dropDownLocalNomeValue),
                                      options: locais,
                                      optionLabels: locais,
                                      onChanged: (val) => safeSetState(() =>
                                          _model.dropDownLocalNomeValue = val),
                                      width: double.infinity,
                                      height: 48,
                                      textStyle:
                                          rdoFormFieldTextStyle(context),
                                      hintText: 'Selecione o local',
                                      icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: theme.secondaryText),
                                      fillColor: theme.secondaryBackground,
                                      elevation: 0,
                                      borderColor: theme.alternate,
                                      borderWidth: 1,
                                      borderRadius: 8,
                                      margin: EdgeInsets.zero,
                                      hidesUnderline: true,
                                      isSearchable: true,
                                      isMultiSelect: false,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          RdoSectionCard(
                            title: 'Dados da tarefa',
                            icon: Icons.add_task_rounded,
                            subtitle:
                                'Criada no servidor e sincronizada para o app',
                            margin: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  controller: _model.descricaoTextController,
                                  focusNode: _model.descricaoFocusNode,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  style: rdoFormFieldTextStyle(context),
                                  decoration: rdoFormFieldDecoration(
                                    context,
                                    label: 'Descrição',
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                          ? 'Informe a descrição'
                                          : null,
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _model.qtdTextController,
                                        focusNode: _model.qtdFocusNode,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        style: rdoFormFieldTextStyle(context),
                                        decoration: rdoFormFieldDecoration(
                                          context,
                                          label: 'Quantidade',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller:
                                            _model.unidadeTextController,
                                        focusNode: _model.unidadeFocusNode,
                                        style: rdoFormFieldTextStyle(context),
                                        decoration: rdoFormFieldDecoration(
                                          context,
                                          label: 'Unidade',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _model.valorUnitTextController,
                                  focusNode: _model.valorUnitFocusNode,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [_valorUnitarioMask],
                                  style: rdoFormFieldTextStyle(context),
                                  decoration: rdoFormFieldDecoration(
                                    context,
                                    label: 'Valor unitário (opcional)',
                                    prefixText: 'R\$ ',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _model.metaTextController,
                                        focusNode: _model.metaFocusNode,
                                        keyboardType: const TextInputType
                                            .numberWithOptions(decimal: true),
                                        style: rdoFormFieldTextStyle(context),
                                        decoration: rdoFormFieldDecoration(
                                          context,
                                          label: 'Meta (opcional)',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: TextFormField(
                                        controller:
                                            _model.metaUnidadeTextController,
                                        focusNode: _model.metaUnidadeFocusNode,
                                        style: rdoFormFieldTextStyle(context),
                                        decoration: rdoFormFieldDecoration(
                                          context,
                                          label: 'Meta unidade',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildBarraAcoes(theme, etapasVazias: false),
                  ],
                ),
              );
            },
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
              'Nova tarefa',
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

  Widget _buildBarraAcoes(
    FlutterFlowTheme theme, {
    required bool etapasVazias,
  }) {
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
                onPressed: (etapasVazias || _model.salvando) ? null : _salvar,
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
                  _model.salvando ? 'Salvando…' : 'Salvar tarefa',
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

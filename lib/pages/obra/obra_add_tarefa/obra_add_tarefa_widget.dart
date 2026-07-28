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
            'Nova tarefa',
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
                    'Não há etapas nesta obra. Cadastre uma etapa antes de adicionar tarefas.',
                    style: theme.bodyMedium,
                  ),
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
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text(
                      'A tarefa é criada no servidor e depois baixada para o app.',
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
                        safeSetState(() => _model.dropDownEtapaUuidValue = val);
                        if (val != null && val.isNotEmpty) {
                          await _atualizarItemParaEtapa(val);
                        }
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
                    FutureBuilder<List<String>>(
                      future: _locaisFuture,
                      builder: (context, locSnap) {
                        if (locSnap.connectionState != ConnectionState.done) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child:
                                LinearProgressIndicator(color: theme.primary),
                          );
                        }
                        final locais = locSnap.data ?? [];
                        if (locais.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Nenhum local cadastrado nesta obra. Cadastre locais em Locais da obra.',
                              style: theme.bodySmall.override(
                                font: GoogleFonts.inter(),
                                color: theme.secondaryText,
                              ),
                            ),
                          );
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Local', style: theme.labelMedium),
                            const SizedBox(height: 6),
                            FlutterFlowDropDown<String>(
                              key: ValueKey<String>(locais.join('\u0001')),
                              controller:
                                  _model.dropDownLocalNomeValueController ??=
                                      FormFieldController<String>(
                                          _model.dropDownLocalNomeValue),
                              options: locais,
                              optionLabels: locais,
                              onChanged: (val) => safeSetState(
                                  () => _model.dropDownLocalNomeValue = val),
                              width: double.infinity,
                              height: 56,
                              textStyle: theme.bodyMedium,
                              hintText: 'Selecione o local',
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
                          ],
                        );
                      },
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
                        labelText: 'Valor unitário (opcional)',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
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

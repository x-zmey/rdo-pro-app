import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/equipamentos_atividade_relatorio/equipamentos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/fotos_atividade/fotos_atividade_widget.dart';
import '/componentes/atividades_relatorios/insumos_atividade_relatorio/insumos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/mao_obra_atividade_relatorio/mao_obra_atividade_relatorio_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'add_atividade_relatorio_etapa_model.dart';
export 'add_atividade_relatorio_etapa_model.dart';

/// Evita `null` / texto "null" nos campos; quantidade em branco até preencher.
String _textoAtividade(String? v) {
  if (v == null) return '';
  final t = v.trim();
  if (t == 'null') return '';
  return t;
}

String _qtdAtividadeTexto(num? q) {
  if (q == null) return '';
  return formatQuantidadeRelatorio(q);
}

/// Aceita vírgula e ponto (o teclado decimal do Android varia conforme o locale)
/// e limita a 2 casas, que é a precisão gravada no servidor.
final List<TextInputFormatter> _formattersQuantidade = [
  FilteringTextInputFormatter.allow(RegExp(r'^\d*[.,]?\d{0,2}')),
];

String _labelMaoObraRelatorioPresente(GetMaoObraRelatorioRow e) {
  final d = (e.descricao ?? '').trim();
  final c = (e.cargoFuncao ?? '').trim();
  if (d.isEmpty && c.isEmpty) return 'Mão de obra';
  if (c.isEmpty) return d;
  if (d.isEmpty) return c;
  return '$d — $c';
}

({List<String> options, List<String> labels}) _dropdownOpcoesUnicasEtapa(
  Iterable<String?> uuids,
  Iterable<String?> labels,
) {
  final uList = uuids.toList();
  final lList = labels.toList();
  final seen = <String>{};
  final options = <String>[];
  final optionLabels = <String>[];
  for (var i = 0; i < uList.length; i++) {
    final u = (uList[i] ?? '').trim();
    if (u.isEmpty || u == '0') continue;
    if (!seen.add(u)) continue;
    final label = i < lList.length ? (lList[i] ?? '').trim() : '';
    options.add(u);
    optionLabels.add(label.isEmpty ? u : label);
  }
  return (options: options, labels: optionLabels);
}

class AddAtividadeRelatorioEtapaWidget extends StatefulWidget {
  const AddAtividadeRelatorioEtapaWidget({
    super.key,
    required this.relatorioId,
    required this.obraId,
    required this.atividadeId,
    required this.atividadeUuid,
    required this.relatorioUuid,
    required this.obraUuid,
  });

  final int? relatorioId;
  final int? obraId;
  final int? atividadeId;
  final String? atividadeUuid;
  final String? relatorioUuid;
  final String? obraUuid;

  static String routeName = 'addAtividadeRelatorioEtapa';
  static String routePath = '/addAtividadeRelatorioEtapa';

  @override
  State<AddAtividadeRelatorioEtapaWidget> createState() =>
      _AddAtividadeRelatorioEtapaWidgetState();
}

class _AddAtividadeRelatorioEtapaWidgetState
    extends State<AddAtividadeRelatorioEtapaWidget> {
  late AddAtividadeRelatorioEtapaModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  int _listasItensAtividadeRefresh = 0;

  late final Future<List<dynamic>> _futureDadosPagina;
  late Future<List<GetitensdaobraRow>> _futureInsumosObra;
  late Future<List<CarregaItensObraRow>> _futureEquipamentosObra;
  late Future<List<GetMaoObraRelatorioRow>> _futureMaoObraRelatorio;

  Future<List<CarregaItensObraRow>> _loadEquipamentosObra() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) return <CarregaItensObraRow>[];
    try {
      await actions.refreshObraItensPorTipo(
        obraUuid: obraUuid,
        tipo: 'equipamento',
      );
    } catch (_) {}
    return SQLiteManager.instance.carregaItensObra(
      tipo: 'equipamento',
      obraId: widget.obraId,
      obraUuid: obraUuid,
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddAtividadeRelatorioEtapaModel());
    _futureDadosPagina = Future.wait<dynamic>([
      SQLiteManager.instance.getDadosAtividade(
        uuid: widget.atividadeUuid!,
      ),
      SQLiteManager.instance.obraLocais(
        obraUuid: widget.obraUuid!,
      ),
      () async {
        final obraUuid = (widget.obraUuid ?? '').trim();
        if (obraUuid.isEmpty) return <GetOrdensServicoRow>[];
        try {
          await actions.refreshOrdensPorObra(obraUuid: obraUuid);
        } catch (_) {}
        return SQLiteManager.instance.getOrdensServico(obraUuid: obraUuid);
      }(),
    ]);
    _futureInsumosObra = SQLiteManager.instance.getitensdaobra(
      relatorioUuid: widget.relatorioUuid!,
    );
    _futureEquipamentosObra = _loadEquipamentosObra();
    _futureMaoObraRelatorio =
        SQLiteManager.instance.getMaoObraRelatorio(
      relatorioUuid: widget.relatorioUuid!,
    ).then((rows) {
      final seen = <String>{};
      final out = <GetMaoObraRelatorioRow>[];
      for (final e in rows) {
        if (e.statusPresenca.trim().toLowerCase() != 'presente') continue;
        final u = (e.obraItemUuid ?? '').trim();
        if (u.isEmpty) continue;
        if (seen.add(u)) out.add(e);
      }
      return out;
    });

    _model.switchOrdemValue = false;
    _model.textFieldDescricaoFocusNode ??= FocusNode();
    _model.textFieldQtdRealizadaFocusNode ??= FocusNode();
    _model.textFieldQtdRealizadaFocusNode!
        .addListener(_onQtdRealizadaFocusChange);
    _model.textFieldUnidadeFocusNode ??= FocusNode();
  }

  void _atualizarListasItensAtividade() {
    if (!mounted) return;
    safeSetState(() => _listasItensAtividadeRefresh++);
  }

  Future<bool> _itemJaVinculadoNaAtividade({
    required String tipo,
    required String obraItemUuid,
  }) async {
    final u = obraItemUuid.trim();
    if (u.isEmpty || u == '0') return false;
    final itens = await SQLiteManager.instance.getItensAtividade(
      atividadeUuid: widget.atividadeUuid!,
      tipo: tipo,
    );
    return itens.any(
      (e) => (e.obraItemUuid ?? '').trim().toLowerCase() == u.toLowerCase(),
    );
  }

  Future<void> _vincularVariosItensAtividade({
    required String tipo,
    required Iterable<String> obraItemUuids,
  }) async {
    final candidatos = obraItemUuids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '0')
        .toSet()
        .toList();
    if (candidatos.isEmpty) return;

    var vinculados = 0;
    for (final obraItemUuid in candidatos) {
      if (await _itemJaVinculadoNaAtividade(
        tipo: tipo,
        obraItemUuid: obraItemUuid,
      )) {
        continue;
      }
      final itemUuid = await actions.generateUuid();
      await SQLiteManager.instance.setItemAtividade(
        relatorioAtividadeId: widget.atividadeId!,
        tipo: tipo,
        obraItemId: 0,
        relatorioAtividadeUuid: widget.atividadeUuid,
        obraItemUuid: obraItemUuid,
        uuid: itemUuid,
      );
      vinculados++;
    }
    if (vinculados > 0) {
      _atualizarListasItensAtividade();
    }
  }

  Future<void> _onMultiSelectItensAtividade({
    required String tipo,
    required List<String>? selecionados,
    required void Function(List<String>?) setDropDownValue,
  }) async {
    final lista = (selecionados ?? [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '0')
        .toList();
    setDropDownValue(lista);
    if (lista.isEmpty) return;
    await _vincularVariosItensAtividade(
      tipo: tipo,
      obraItemUuids: lista,
    );
  }

  @override
  void dispose() {
    _model.textFieldQtdRealizadaFocusNode
        ?.removeListener(_onQtdRealizadaFocusChange);
    _model.dispose();

    super.dispose();
  }

  num? _qtdRealizadaDoFormulario() {
    final txt =
        _model.textFieldQtdRealizadaTextController?.text.trim() ?? '';
    if (txt.isEmpty) return null;
    return tryParseQuantidadeRelatorio(txt);
  }

  void _onQtdRealizadaFocusChange() {
    final node = _model.textFieldQtdRealizadaFocusNode;
    if (node != null && !node.hasFocus) {
      _persistirQtdRealizadaParcial();
    }
  }

  Future<void> _persistirQtdRealizadaParcial() async {
    final uuid = widget.atividadeUuid;
    if (uuid == null || uuid.isEmpty) return;
    final qtd = _qtdRealizadaDoFormulario();
    if (qtd == null || qtd < 0) return;

    final rows = await SQLiteManager.instance.getDadosAtividade(uuid: uuid);
    final row = rows.firstOrNull;
    if (row == null) return;

    final localForm = (_model.dropDownLocalValue ?? '').trim();
    final descForm =
        (_model.textFieldDescricaoTextController?.text ?? '').trim();
    final unForm =
        (_model.textFieldUnidadeTextController?.text ?? '').trim();

    await SQLiteManager.instance.updateAtividade(
      uuid: uuid,
      local: localForm.isNotEmpty ? localForm : (row.local ?? ''),
      descricao: descForm.isNotEmpty ? descForm : (row.descricao ?? ''),
      qtdRealizada: qtd,
      unidade: unForm.isNotEmpty ? unForm : (row.unidade ?? ''),
      situacao: _model.statusSelected ?? row.situacao ?? 1,
    );
    if (!mounted) return;
    _atualizarListasItensAtividade();
  }

  /// Rótulo curto acima do campo, no padrão das tabelas do RDO.
  Widget _rotuloCampo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(texto.toUpperCase(), style: rdoColumnLabelStyle(context)),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _futureDadosPagina,
      builder: (context, snapshot) {
        // Customize what your widget looks like when it's loading.
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: Center(
              child: LinearProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
          );
        }
        final addAtividadeRelatorioEtapaGetDadosAtividadeRowList =
            snapshot.data![0] as List<GetDadosAtividadeRow>;
        final locaisObraList = snapshot.data![1] as List<ObraLocaisRow>;
        final ordensServicoList =
            snapshot.data!.length > 2 ? snapshot.data![2] as List<GetOrdensServicoRow> : <GetOrdensServicoRow>[];

        final locaisVinculados = locaisObraList
            .where((e) => (e.nome ?? '').trim().isNotEmpty)
            .toList();
        final locaisNomes = locaisVinculados
            .map((e) => (e.nome ?? '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
        const statusOptions = <int>[1, 0, 2];
        final situacaoDb = addAtividadeRelatorioEtapaGetDadosAtividadeRowList
            .firstOrNull
            ?.situacao;
        // Nova atividade ou status inválido: Em andamento (1), não -1/null.
        final situacaoInicial = (situacaoDb != null &&
                statusOptions.contains(situacaoDb))
            ? situacaoDb
            : 1;

        if (_model.dropDownStatusValueController == null) {
          _model.dropDownStatusValue ??= situacaoInicial;
          _model.statusSelected ??= situacaoInicial;
          _model.dropDownStatusValueController =
              FormFieldController<int>(_model.dropDownStatusValue);
        }

        if (_model.dropDownLocalValueController == null) {
          final rowAtividade =
              addAtividadeRelatorioEtapaGetDadosAtividadeRowList.firstOrNull;
          final rawLocal = _textoAtividade(rowAtividade?.local).trim();
          String? initialLocalNome;
          if (rawLocal.isNotEmpty) {
            final parsed = int.tryParse(rawLocal);
            if (parsed != null &&
                locaisObraList
                    .any((e) => e.localIdServidor == parsed)) {
              initialLocalNome = locaisObraList
                  .where((e) => e.localIdServidor == parsed)
                  .firstOrNull
                  ?.nome
                  ?.trim();
            } else {
              final byNome = locaisNomes.where((e) => e == rawLocal).firstOrNull;
              initialLocalNome = byNome;
            }
          }
          _model.dropDownLocalValue = initialLocalNome;
          _model.dropDownLocalValueController =
              FormFieldController<String>(initialLocalNome);
        }

        if (_model.dropDownOrdemUuidValueController == null) {
          final rowAtividadeOrdem =
              addAtividadeRelatorioEtapaGetDadosAtividadeRowList.firstOrNull;
          final savedOrdemUuid = rowAtividadeOrdem?.ordemUuid?.trim();
          final hasSavedOrdem = savedOrdemUuid != null &&
              savedOrdemUuid.isNotEmpty &&
              ordensServicoList.any((o) => o.uuid == savedOrdemUuid);
          _model.switchOrdemValue = hasSavedOrdem;
          _model.dropDownOrdemUuidValue =
              hasSavedOrdem ? savedOrdemUuid : null;
          _model.dropDownOrdemUuidValueController =
              FormFieldController<String>(_model.dropDownOrdemUuidValue);
        }

        void voltarParaRelatorio() {
          context.pushNamed(
            ObraAddRelatorioWidget.routeName,
            queryParameters: {
              'id': serializeParam(widget!.relatorioId, ParamType.int),
              'uuid': serializeParam(widget!.relatorioUuid, ParamType.String),
            }.withoutNulls,
          );
        }

        final theme = FlutterFlowTheme.of(context);
        final descricaoAtividade = _textoAtividade(
          addAtividadeRelatorioEtapaGetDadosAtividadeRowList.firstOrNull?.descricao,
        ).trim();

        Widget avisoCampo(String texto, Color cor) => Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                texto,
                style: GoogleFonts.inter(fontSize: 11.5, color: cor),
              ),
            );

        Widget localSelectorWidget() {
          if (locaisVinculados.isEmpty) {
            return avisoCampo(
              'Nenhum local vinculado a esta obra. '
              'Vincule locais na obra para selecionar aqui.',
              theme.error,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rotuloCampo('Local *'),
              FlutterFlowDropDown<String>(
                controller: _model.dropDownLocalValueController!,
                options: locaisNomes,
                optionLabels: locaisNomes,
                onChanged: (val) async {
                  safeSetState(() => _model.dropDownLocalValue = val);
                },
                width: double.infinity,
                height: 38.0,
                textStyle: rdoCompactFieldTextStyle(context),
                hintText: 'Selecione o local',
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.secondaryText,
                  size: 18.0,
                ),
                fillColor: theme.secondaryBackground,
                elevation: 0.0,
                borderColor: theme.alternate,
                borderWidth: 1.0,
                borderRadius: 8.0,
                margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                hidesUnderline: true,
                isSearchable: true,
                searchHintText: 'Buscar local...',
                isMultiSelect: false,
              ),
            ],
          );
        }

        Widget ordemSelectorWidget() {
          if (!_model.switchOrdemValue!) {
            return const SizedBox.shrink();
          }
          if (ordensServicoList.isEmpty) {
            return avisoCampo(
              'Nenhuma ordem de serviço encontrada para esta obra no app. '
              'Sincronize as ordens ou cadastre na web.',
              theme.warning,
            );
          }
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rotuloCampo('Ordem de serviço'),
              FlutterFlowDropDown<String>(
                controller: _model.dropDownOrdemUuidValueController ??=
                    FormFieldController<String>(_model.dropDownOrdemUuidValue),
                options: ordensServicoList.map((o) => o.uuid).toList(),
                optionLabels: ordensServicoList.map((o) {
                  final nome = (o.nome ?? '').trim();
                  return nome.isNotEmpty ? '${o.codigo} — $nome' : o.codigo;
                }).toList(),
                onChanged: (val) async {
                  safeSetState(() => _model.dropDownOrdemUuidValue = val);
                },
                width: double.infinity,
                height: 38.0,
                textStyle: rdoCompactFieldTextStyle(context),
                hintText: 'Referência no RDO',
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.secondaryText,
                  size: 18.0,
                ),
                fillColor: theme.secondaryBackground,
                elevation: 0.0,
                borderColor: theme.alternate,
                borderWidth: 1.0,
                borderRadius: 8.0,
                margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
                hidesUnderline: true,
                isSearchable: true,
                searchHintText: 'Buscar ordem...',
                isMultiSelect: false,
              ),
            ],
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
            appBar: AppBar(
              backgroundColor: theme.primary,
              automaticallyImplyLeading: false,
              elevation: 0.0,
              scrolledUnderElevation: 0.0,
              surfaceTintColor: Colors.transparent,
              centerTitle: false,
              titleSpacing: 0.0,
              toolbarHeight: 58.0,
              iconTheme: const IconThemeData(color: Colors.white),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                onPressed: voltarParaRelatorio,
              ),
              title: Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gerenciar Atividade',
                      style: GoogleFonts.interTight(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      descricaoAtividade.isEmpty
                          ? 'Atividade da etapa'
                          : descricaoAtividade,
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
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                  tooltip: 'Fechar sem salvar',
                  onPressed: voltarParaRelatorio,
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: SafeArea(
              top: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RdoSectionCard(
                      title: 'Dados da Atividade',
                      icon: Icons.assignment_outlined,
                      margin: EdgeInsets.zero,
                      contentPadding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
                            decoration: BoxDecoration(
                              color:
                                  theme.primaryBackground.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: theme.alternate),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.link_rounded,
                                  size: 15,
                                  color: theme.secondaryText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Vincular ordem de serviço',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ),
                                Transform.scale(
                                  scale: 0.75,
                                  child: Switch.adaptive(
                                    value: _model.switchOrdemValue!,
                                    onChanged: (newValue) async {
                                      safeSetState(() {
                                        _model.switchOrdemValue = newValue!;
                                        if (newValue == false) {
                                          _model.dropDownOrdemUuidValue = null;
                                          _model.dropDownOrdemUuidValueController
                                              ?.value = null;
                                        }
                                      });
                                    },
                                    activeColor: theme.primary,
                                    activeTrackColor:
                                        theme.primary.withValues(alpha: 0.35),
                                    inactiveTrackColor: theme.alternate,
                                    inactiveThumbColor:
                                        theme.secondaryBackground,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final estreito = constraints.maxWidth < 600;
                              final localW = localSelectorWidget();
                              if (!_model.switchOrdemValue!) {
                                return localW;
                              }
                              final ordemW = ordemSelectorWidget();
                              if (estreito) {
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    localW,
                                    const SizedBox(height: 10),
                                    ordemW,
                                  ],
                                );
                              }
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: localW),
                                  const SizedBox(width: 10),
                                  Expanded(child: ordemW),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _rotuloCampo('Descrição *'),
                          TextFormField(
                            controller:
                                _model.textFieldDescricaoTextController ??=
                                    TextEditingController(
                              text: _textoAtividade(
                                addAtividadeRelatorioEtapaGetDadosAtividadeRowList.firstOrNull?.descricao,
                              ),
                            ),
                            focusNode: _model.textFieldDescricaoFocusNode,
                            autofocus: false,
                            textInputAction: TextInputAction.next,
                            obscureText: false,
                            decoration: rdoCompactFieldDecoration(
                              context,
                              hint: 'Descreva a atividade realizada',
                            ).copyWith(
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                            ),
                            style: rdoCompactFieldTextStyle(context),
                            maxLines: 3,
                            minLines: 2,
                            cursorColor: theme.primary,
                            validator: _model
                                .textFieldDescricaoTextControllerValidator
                                .asValidator(context),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _rotuloCampo('Quantidade *'),
                                    TextFormField(
                                      controller: _model
                                              .textFieldQtdRealizadaTextController ??=
                                          TextEditingController(
                                        text: _qtdAtividadeTexto(
                                          addAtividadeRelatorioEtapaGetDadosAtividadeRowList.firstOrNull?.qtdRealizada,
                                        ),
                                      ),
                                      focusNode:
                                          _model.textFieldQtdRealizadaFocusNode,
                                      autofocus: false,
                                      textInputAction: TextInputAction.next,
                                      obscureText: false,
                                      decoration: rdoCompactFieldDecoration(
                                        context,
                                        hint: '0',
                                      ),
                                      style: rdoCompactFieldTextStyle(context),
                                      textAlign: TextAlign.center,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                              decimal: true),
                                      inputFormatters: _formattersQuantidade,
                                      cursorColor: theme.primary,
                                      onChanged: (_) => safeSetState(() {}),
                                      onFieldSubmitted: (_) =>
                                          _persistirQtdRealizadaParcial(),
                                      validator: _model
                                          .textFieldQtdRealizadaTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _rotuloCampo('Unidade *'),
                                    TextFormField(
                                      controller: _model
                                              .textFieldUnidadeTextController ??=
                                          TextEditingController(
                                        text: _textoAtividade(
                                          addAtividadeRelatorioEtapaGetDadosAtividadeRowList.firstOrNull?.unidade,
                                        ),
                                      ),
                                      focusNode:
                                          _model.textFieldUnidadeFocusNode,
                                      autofocus: false,
                                      textInputAction: TextInputAction.next,
                                      obscureText: false,
                                      decoration: rdoCompactFieldDecoration(
                                        context,
                                        hint: 'm², m³, kg...',
                                      ),
                                      style: rdoCompactFieldTextStyle(context),
                                      textAlign: TextAlign.center,
                                      cursorColor: theme.primary,
                                      validator: _model
                                          .textFieldUnidadeTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Builder(
                            builder: (context) {
                              final progRow =
                                  addAtividadeRelatorioEtapaGetDadosAtividadeRowList
                                      .firstOrNull;
                              final realizada =
                                  progRow?.qtdRealizada ?? 0;
                              final planejada = progRow?.quantidade;
                              final unidadeProg =
                                  valueOrDefault<String>(
                                progRow?.unidade,
                                '',
                              );
                              final unidadeSuf = unidadeProg.isNotEmpty
                                  ? ' $unidadeProg'
                                  : '';
                              final temPlanejado = planejada != null &&
                                  planejada > 0;
                              final fracaoPlanejado = temPlanejado
                                  ? (realizada / planejada!)
                                      .clamp(0.0, 1.0)
                                  : 0.0;
                              final realizadaFmt =
                                  formatQuantidadeRelatorio(realizada);
                              final progressText = temPlanejado
                                  ? '$realizadaFmt$unidadeSuf realizados de um total de $planejada$unidadeSuf planejados'
                                  : '$realizadaFmt$unidadeSuf realizados'
                                      '${planejada == null ? ' (quantidade planejada não informada)' : ''}';

                              return Container(
                                width: double.infinity,
                                height: 42.92,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Text(
                                      progressText,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.bold,
                                              fontStyle:
                                                  FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            fontSize: 12.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.bold,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                    ),
                                    Padding(
                                      padding:
                                          EdgeInsetsDirectional.fromSTEB(
                                              0.0, 4.0, 0.0, 0.0),
                                      child: LinearPercentIndicator(
                                        percent: fracaoPlanejado,
                                        width: MediaQuery.sizeOf(context)
                                                .width *
                                            0.85,
                                        lineHeight: 16.0,
                                        animation: true,
                                        animateFromLastPercent: true,
                                        progressColor:
                                            FlutterFlowTheme.of(context)
                                                .primary,
                                        backgroundColor:
                                            FlutterFlowTheme.of(context)
                                                .secondary,
                                        center: Text(
                                          temPlanejado
                                              ? '${(fracaoPlanejado * 100).round()}%'
                                              : '—',
                                          style: FlutterFlowTheme.of(
                                                  context)
                                              .headlineSmall
                                              .override(
                                                font: GoogleFonts.interTight(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .headlineSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .headlineSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                fontSize: 12.0,
                                                letterSpacing: 0.0,
                                                fontWeight:
                                                    FlutterFlowTheme.of(
                                                            context)
                                                        .headlineSmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(
                                                            context)
                                                        .headlineSmall
                                                        .fontStyle,
                                              ),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 10),
                          _rotuloCampo('Status'),
                          FlutterFlowDropDown<int>(
                            controller: _model.dropDownStatusValueController!,
                            options: List<int>.from([1, 0, 2]),
                            optionLabels: const [
                              'Em andamento',
                              'Paralizada',
                              'Concluída',
                            ],
                            onChanged: (val) async {
                              safeSetState(
                                  () => _model.dropDownStatusValue = val);
                              _model.statusSelected =
                                  _model.dropDownStatusValue;
                              safeSetState(() {});
                            },
                            width: double.infinity,
                            height: 38.0,
                            textStyle: rdoCompactFieldTextStyle(context),
                            hintText: 'Selecione o status',
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: theme.secondaryText,
                              size: 18.0,
                            ),
                            fillColor: theme.secondaryBackground,
                            elevation: 0.0,
                            borderColor: theme.alternate,
                            borderWidth: 1.0,
                            borderRadius: 8.0,
                            margin: const EdgeInsetsDirectional.fromSTEB(
                                10, 0, 6, 0),
                            hidesUnderline: true,
                            isSearchable: false,
                            isMultiSelect: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RdoSectionCard(
                      title: 'Insumos',
                      icon: Icons.inventory_2_outlined,
                      margin: EdgeInsets.zero,
                      contentPadding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FutureBuilder<List<GetitensdaobraRow>>(
                            future: _futureInsumosObra,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Text(
                                  'Não foi possível carregar insumos.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.error,
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return LinearProgressIndicator(
                                  color: theme.primary,
                                );
                              }
                              final itens = snapshot.data!;
                              final opcoes = _dropdownOpcoesUnicasEtapa(
                                itens.map((e) => e.uuid),
                                itens.map((e) => e.nome),
                              );

                              return FlutterFlowDropDown<String>(
                                multiSelectController:
                                    _model.dropDownInsumoValueController ??=
                                        FormFieldController<List<String>?>(
                                  _model.dropDownInsumoValue ??= <String>[],
                                ),
                                options: opcoes.options,
                                optionLabels: opcoes.labels,
                                onMultiSelectChanged: (vals) async {
                                  await _onMultiSelectItensAtividade(
                                    tipo: 'insumo',
                                    selecionados: vals,
                                    setDropDownValue: (v) =>
                                        _model.dropDownInsumoValue = v,
                                  );
                                  safeSetState(() {});
                                },
                                width: double.infinity,
                                height: 38.0,
                                textStyle: rdoCompactFieldTextStyle(context),
                                hintText: 'Selecione um ou mais insumos',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: theme.secondaryText,
                                  size: 18.0,
                                ),
                                fillColor: theme.secondaryBackground,
                                elevation: 0.0,
                                borderColor: theme.alternate,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: const EdgeInsetsDirectional.fromSTEB(
                                    10, 0, 6, 0),
                                hidesUnderline: true,
                                isSearchable: true,
                                searchHintText: 'Buscar insumo...',
                                isMultiSelect: true,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          wrapWithModel(
                            model: _model.insumosAtividadeRelatorioModel,
                            updateCallback: () => safeSetState(() {}),
                            child: InsumosAtividadeRelatorioWidget(
                              relatorioUuid: widget!.relatorioUuid!,
                              atividadeUuid: widget!.atividadeUuid!,
                              listRefreshToken: _listasItensAtividadeRefresh,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RdoSectionCard(
                      title: 'Equipamentos',
                      icon: Icons.construction_outlined,
                      margin: EdgeInsets.zero,
                      contentPadding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FutureBuilder<List<CarregaItensObraRow>>(
                            future: _futureEquipamentosObra,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Text(
                                  'Não foi possível carregar equipamentos.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.error,
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return LinearProgressIndicator(
                                  color: theme.primary,
                                );
                              }
                              final itens = snapshot.data!;
                              final opcoes = _dropdownOpcoesUnicasEtapa(
                                itens.map((e) => e.uuid),
                                itens.map((e) => e.descricao),
                              );

                              return FlutterFlowDropDown<String>(
                                multiSelectController: _model
                                        .dropDownEquipamentosValueController ??=
                                    FormFieldController<List<String>?>(
                                  _model.dropDownEquipamentosValue ??=
                                      <String>[],
                                ),
                                options: opcoes.options,
                                optionLabels: opcoes.labels,
                                onMultiSelectChanged: (vals) async {
                                  await _onMultiSelectItensAtividade(
                                    tipo: 'equipamento',
                                    selecionados: vals,
                                    setDropDownValue: (v) =>
                                        _model.dropDownEquipamentosValue = v,
                                  );
                                  safeSetState(() {});
                                },
                                width: double.infinity,
                                height: 38.0,
                                textStyle: rdoCompactFieldTextStyle(context),
                                hintText: 'Selecione um ou mais equipamentos',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: theme.secondaryText,
                                  size: 18.0,
                                ),
                                fillColor: theme.secondaryBackground,
                                elevation: 0.0,
                                borderColor: theme.alternate,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: const EdgeInsetsDirectional.fromSTEB(
                                    10, 0, 6, 0),
                                hidesUnderline: true,
                                isSearchable: true,
                                searchHintText: 'Buscar equipamento...',
                                isMultiSelect: true,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          wrapWithModel(
                            model: _model.equipamentosAtividadeRelatorioModel,
                            updateCallback: () => safeSetState(() {}),
                            child: EquipamentosAtividadeRelatorioWidget(
                              relatorioUuid: widget!.relatorioUuid!,
                              atividadeUuid: widget!.atividadeUuid!,
                              listRefreshToken: _listasItensAtividadeRefresh,
                              qtdRealizadaAtividade: _qtdRealizadaDoFormulario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    RdoSectionCard(
                      title: 'Mão de Obra',
                      icon: Icons.groups_2_outlined,
                      margin: EdgeInsets.zero,
                      contentPadding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FutureBuilder<List<GetMaoObraRelatorioRow>>(
                            future: _futureMaoObraRelatorio,
                            builder: (context, snapshot) {
                              if (snapshot.hasError) {
                                return Text(
                                  'Não foi possível carregar mão de obra.',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.error,
                                  ),
                                );
                              }
                              if (!snapshot.hasData) {
                                return LinearProgressIndicator(
                                  color: theme.primary,
                                );
                              }
                              final itensDropdown = snapshot.data!;

                              if (itensDropdown.isEmpty) {
                                return avisoCampo(
                                  'Nenhuma mão de obra marcada como presente neste relatório. '
                                  'Registre presença no relatório para vincular aqui.',
                                  theme.error,
                                );
                              }

                              final opcoes = _dropdownOpcoesUnicasEtapa(
                                itensDropdown
                                    .map((e) => (e.obraItemUuid ?? '').trim()),
                                itensDropdown
                                    .map(_labelMaoObraRelatorioPresente),
                              );

                              return FlutterFlowDropDown<String>(
                                multiSelectController:
                                    _model.dropDownMaoObraValueController ??=
                                        FormFieldController<List<String>?>(
                                  _model.dropDownMaoObraValue ??= <String>[],
                                ),
                                options: opcoes.options,
                                optionLabels: opcoes.labels,
                                onMultiSelectChanged: (vals) async {
                                  await _onMultiSelectItensAtividade(
                                    tipo: 'mao_obra',
                                    selecionados: vals,
                                    setDropDownValue: (v) =>
                                        _model.dropDownMaoObraValue = v,
                                  );
                                  safeSetState(() {});
                                },
                                width: double.infinity,
                                height: 38.0,
                                textStyle: rdoCompactFieldTextStyle(context),
                                hintText:
                                    'Selecione uma ou mais mãos de obra',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: theme.secondaryText,
                                  size: 18.0,
                                ),
                                fillColor: theme.secondaryBackground,
                                elevation: 0.0,
                                borderColor: theme.alternate,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: const EdgeInsetsDirectional.fromSTEB(
                                    10, 0, 6, 0),
                                hidesUnderline: true,
                                isSearchable: true,
                                searchHintText: 'Buscar mão de obra...',
                                isMultiSelect: true,
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          wrapWithModel(
                            model: _model.maoObraAtividadeRelatorioModel,
                            updateCallback: () => safeSetState(() {}),
                            child: MaoObraAtividadeRelatorioWidget(
                              relatorioUuid: widget!.relatorioUuid!,
                              atividadeUuid: widget!.atividadeUuid!,
                              listRefreshToken: _listasItensAtividadeRefresh,
                              qtdRealizadaAtividade: _qtdRealizadaDoFormulario,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    wrapWithModel(
                      model: _model.fotosAtividadeModel,
                      updateCallback: () => safeSetState(() {}),
                      child: FotosAtividadeWidget(
                        parameter1: widget!.atividadeId!,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: voltarParaRelatorio,
                            icon: const Icon(Icons.close_rounded, size: 16),
                            label: const Text('Cancelar'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.secondaryText,
                              minimumSize: const Size(0, 40),
                              side: BorderSide(color: theme.alternate),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: GoogleFonts.inter(
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
                            onPressed: () async {
                              final descricao = _model
                                  .textFieldDescricaoTextController.text
                                  .trim();
                              final unidade = _model
                                  .textFieldUnidadeTextController.text
                                  .trim();
                              final qtdTxt = _model
                                  .textFieldQtdRealizadaTextController.text
                                  .trim();
                              final qtdParsed = qtdTxt.isEmpty
                                  ? null
                                  : tryParseQuantidadeRelatorio(qtdTxt);
                              if (_model.dropDownLocalValue == null ||
                                  descricao.isEmpty ||
                                  unidade.isEmpty ||
                                  qtdParsed == null || qtdParsed < 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      _model.dropDownLocalValue == null
                                          ? 'Selecione o local da obra.'
                                          : 'Preencha descrição, quantidade e unidade da atividade.',
                                      style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                      ),
                                    ),
                                    backgroundColor:
                                        FlutterFlowTheme.of(context).error,
                                  ),
                                );
                                return;
                              }
                              if (_model.switchOrdemValue == true &&
                                  ordensServicoList.isNotEmpty &&
                                  (_model.dropDownOrdemUuidValue == null ||
                                      _model.dropDownOrdemUuidValue!
                                          .trim()
                                          .isEmpty)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Selecione a ordem de serviço ou desligue a opção.',
                                      style: TextStyle(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                      ),
                                    ),
                                    backgroundColor:
                                        FlutterFlowTheme.of(context).error,
                                  ),
                                );
                                return;
                              }

                              int? ordemIdSave;
                              String? ordemUuidSave;
                              if (_model.switchOrdemValue == true &&
                                  (_model.dropDownOrdemUuidValue != null &&
                                      _model.dropDownOrdemUuidValue!
                                          .trim()
                                          .isNotEmpty)) {
                                ordemUuidSave =
                                    _model.dropDownOrdemUuidValue!.trim();
                                ordemIdSave = ordensServicoList
                                    .where((o) => o.uuid == ordemUuidSave)
                                    .firstOrNull
                                    ?.id;
                              }

                              await SQLiteManager.instance.updateAtividade(
                                uuid: widget!.atividadeUuid!,
                                local: _model.dropDownLocalValue!.trim(),
                                descricao: descricao,
                                qtdRealizada: qtdParsed,
                                unidade: unidade,
                                situacao: _model.statusSelected ?? 1,
                                ordemId: ordemIdSave,
                                ordemUuid: ordemUuidSave,
                                updateOrdemVinculo: true,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Atividade atualizada!',
                                    style: TextStyle(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                    ),
                                  ),
                                  duration: Duration(milliseconds: 4000),
                                  backgroundColor:
                                      FlutterFlowTheme.of(context).secondary,
                                ),
                              );

                              context.pushNamed(
                                ObraAddRelatorioWidget.routeName,
                                queryParameters: {
                                  'id': serializeParam(
                                    widget!.relatorioId,
                                    ParamType.int,
                                  ),
                                  'uuid': serializeParam(
                                    widget!.relatorioUuid,
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                                extra: <String, dynamic>{
                                  '__transition_info__': TransitionInfo(
                                    hasTransition: true,
                                    transitionType:
                                        PageTransitionType.topToBottom,
                                  ),
                                },
                              );
                            },
                            icon: const Icon(Icons.check_rounded, size: 17),
                            label: const Text('Salvar atividade'),
                            style: FilledButton.styleFrom(
                              backgroundColor: theme.primary,
                              foregroundColor: theme.info,
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

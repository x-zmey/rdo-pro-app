import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/equipamentos_atividade_relatorio/equipamentos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/fotos_atividade/fotos_atividade_widget.dart';
import '/componentes/atividades_relatorios/insumos_atividade_relatorio/insumos_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/mao_obra_atividade_relatorio/mao_obra_atividade_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
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

String _qtdAtividadeTexto(int? q) {
  if (q == null) return '';
  return q.toString();
}

String _labelMaoObraRelatorioPresente(GetMaoObraRelatorioRow e) {
  final d = (e.descricao ?? '').trim();
  final c = (e.cargoFuncao ?? '').trim();
  if (d.isEmpty && c.isEmpty) return 'Mão de obra';
  if (c.isEmpty) return d;
  if (d.isEmpty) return c;
  return '$d — $c';
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

  void _atualizarListasItensAtividade() {
    if (!mounted) return;
    safeSetState(() => _listasItensAtividadeRefresh++);
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddAtividadeRelatorioEtapaModel());

    _model.switchOrdemValue = false;

    _model.textFieldDescricaoFocusNode ??= FocusNode();

    _model.textFieldQtdRealizadaFocusNode ??= FocusNode();

    _model.textFieldUnidadeFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        SQLiteManager.instance.getDadosAtividade(
          uuid: widget!.atividadeUuid!,
        ),
        SQLiteManager.instance.obraLocais(
          obraUuid: widget!.obraUuid!,
        ),
        (widget.obraUuid != null && widget.obraUuid!.trim().isNotEmpty)
            ? SQLiteManager.instance.getOrdensServico(
                obraUuid: widget.obraUuid,
              )
            : Future<List<GetOrdensServicoRow>>.value(const []),
      ]),
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

        Widget localSelectorWidget() {
          if (locaisVinculados.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                'Nenhum local vinculado a esta obra. '
                'Vincule locais na obra para selecionar aqui.',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).error,
                      letterSpacing: 0.0,
                    ),
              ),
            );
          }
          return FlutterFlowDropDown<String>(
            controller: _model.dropDownLocalValueController!,
            options: locaisNomes,
            optionLabels: locaisNomes,
            onChanged: (val) async {
              safeSetState(() => _model.dropDownLocalValue = val);
            },
            width: double.infinity,
            height: 46.0,
            textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  fontStyle:
                      FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
            hintText: 'Selecione o local',
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            fillColor: FlutterFlowTheme.of(context).primaryBackground,
            elevation: 0.0,
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderWidth: 1.0,
            borderRadius: 8.0,
            margin: EdgeInsetsDirectional.zero,
            hidesUnderline: true,
            isSearchable: true,
            isMultiSelect: false,
            labelText: 'Local *',
            labelTextStyle: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight:
                        FlutterFlowTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).labelMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).labelMedium.fontStyle,
                ),
          );
        }

        Widget ordemSelectorWidget() {
          if (!_model.switchOrdemValue!) {
            return const SizedBox.shrink();
          }
          if (ordensServicoList.isEmpty) {
            return Padding(
              padding: const EdgeInsets.only(top: 0.0),
              child: Text(
                'Nenhuma ordem de serviço encontrada para esta obra no app. Sincronize as ordens ou cadastre na web.',
                style: FlutterFlowTheme.of(context).bodySmall.override(
                      font: GoogleFonts.inter(
                        fontWeight:
                            FlutterFlowTheme.of(context).bodySmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodySmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).warning,
                      letterSpacing: 0.0,
                    ),
              ),
            );
          }
          return FlutterFlowDropDown<String>(
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
            height: 46.0,
            textStyle: FlutterFlowTheme.of(context).bodyMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight: FontWeight.w500,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  fontStyle:
                      FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                ),
            hintText: 'Referência no RDO',
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            fillColor: FlutterFlowTheme.of(context).primaryBackground,
            elevation: 0.0,
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderWidth: 1.0,
            borderRadius: 8.0,
            margin: EdgeInsetsDirectional.zero,
            hidesUnderline: true,
            isSearchable: true,
            isMultiSelect: false,
            labelText: 'Ordem de serviço',
            labelTextStyle: FlutterFlowTheme.of(context).labelMedium.override(
                  font: GoogleFonts.inter(
                    fontWeight:
                        FlutterFlowTheme.of(context).labelMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).labelMedium.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight:
                      FlutterFlowTheme.of(context).labelMedium.fontWeight,
                  fontStyle:
                      FlutterFlowTheme.of(context).labelMedium.fontStyle,
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
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            appBar: AppBar(
              backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
              automaticallyImplyLeading: false,
              leading: FlutterFlowIconButton(
                borderRadius: 20.0,
                buttonSize: 40.0,
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 24.0,
                ),
                onPressed: () async {
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
                  );
                },
              ),
              title: Text(
                'Gerenciar Atividade',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontStyle,
                      ),
                      fontSize: 20.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                      fontStyle:
                          FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                    ),
              ),
              actions: [
                FlutterFlowIconButton(
                  borderRadius: 20.0,
                  buttonSize: 40.0,
                  icon: Icon(
                    Icons.close_rounded,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0,
                  ),
                  onPressed: () async {
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
                    );
                  },
                ),
              ],
              centerTitle: true,
              elevation: 0.0,
            ),
            body: SafeArea(
              top: true,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(8.0, 0.0, 8.0, 0.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dados da Atividade',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                              Container(
                                width: MediaQuery.sizeOf(context).width * 1.0,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(0.0),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Switch.adaptive(
                                          value: _model.switchOrdemValue!,
                                          onChanged: (newValue) async {
                                            safeSetState(() {
                                              _model.switchOrdemValue =
                                                  newValue!;
                                              if (newValue == false) {
                                                _model.dropDownOrdemUuidValue =
                                                    null;
                                                _model
                                                    .dropDownOrdemUuidValueController
                                                    ?.value = null;
                                              }
                                            });
                                          },
                                          activeColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          activeTrackColor:
                                              FlutterFlowTheme.of(context)
                                                  .primary,
                                          inactiveTrackColor:
                                              FlutterFlowTheme.of(context)
                                                  .alternate,
                                          inactiveThumbColor:
                                              FlutterFlowTheme.of(context)
                                                  .secondaryBackground,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Vincular ordem de serviço',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight: FontWeight.w600,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  fontSize: 18.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w600,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    LayoutBuilder(
                                      builder: (context, constraints) {
                                        final narrow =
                                            constraints.maxWidth < 600;
                                        final localW = localSelectorWidget();
                                        if (!_model.switchOrdemValue!) {
                                          return localW;
                                        }
                                        final ordemW = ordemSelectorWidget();
                                        if (narrow) {
                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              localW,
                                              SizedBox(height: 8.0),
                                              ordemW,
                                            ],
                                          );
                                        }
                                        return Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(child: localW),
                                            SizedBox(width: 8.0),
                                            Expanded(child: ordemW),
                                          ],
                                        );
                                      },
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              ),
                              TextFormField(
                                controller:
                                    _model.textFieldDescricaoTextController ??=
                                        TextEditingController(
                                  text: _textoAtividade(
                                    addAtividadeRelatorioEtapaGetDadosAtividadeRowList
                                        .firstOrNull?.descricao,
                                  ),
                                ),
                                focusNode: _model.textFieldDescricaoFocusNode,
                                autofocus: false,
                                textInputAction: TextInputAction.next,
                                obscureText: false,
                                decoration: InputDecoration(
                                  labelText: 'Descrição *',
                                  labelStyle: FlutterFlowTheme.of(context)
                                      .labelMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                  hintText: 'Descreva a atividade realizada',
                                  hintStyle: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .fontStyle,
                                        ),
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                  filled: true,
                                  fillColor: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  contentPadding:
                                      EdgeInsetsDirectional.fromSTEB(
                                          12.0, 16.0, 12.0, 16.0),
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                maxLines: 3,
                                minLines: 2,
                                cursorColor:
                                    FlutterFlowTheme.of(context).primary,
                                validator: _model
                                    .textFieldDescricaoTextControllerValidator
                                    .asValidator(context),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _model
                                              .textFieldQtdRealizadaTextController ??=
                                          TextEditingController(
                                        text: _qtdAtividadeTexto(
                                          addAtividadeRelatorioEtapaGetDadosAtividadeRowList
                                              .firstOrNull?.qtdRealizada,
                                        ),
                                      ),
                                      focusNode:
                                          _model.textFieldQtdRealizadaFocusNode,
                                      autofocus: false,
                                      textInputAction: TextInputAction.next,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Quantidade *',
                                        labelStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                        hintText: '0',
                                        hintStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        filled: true,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        contentPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                12.0, 16.0, 12.0, 16.0),
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      keyboardType: TextInputType.number,
                                      cursorColor:
                                          FlutterFlowTheme.of(context).primary,
                                      validator: _model
                                          .textFieldQtdRealizadaTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _model
                                              .textFieldUnidadeTextController ??=
                                          TextEditingController(
                                        text: _textoAtividade(
                                          addAtividadeRelatorioEtapaGetDadosAtividadeRowList
                                              .firstOrNull?.unidade,
                                        ),
                                      ),
                                      focusNode:
                                          _model.textFieldUnidadeFocusNode,
                                      autofocus: false,
                                      textInputAction: TextInputAction.next,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        labelText: 'Unidade *',
                                        labelStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .fontStyle,
                                            ),
                                        hintText: 'm², m³, kg...',
                                        hintStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(8.0),
                                        ),
                                        filled: true,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        contentPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                12.0, 16.0, 12.0, 16.0),
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .fontStyle,
                                          ),
                                      cursorColor:
                                          FlutterFlowTheme.of(context).primary,
                                      validator: _model
                                          .textFieldUnidadeTextControllerValidator
                                          .asValidator(context),
                                    ),
                                  ),
                                ].divide(SizedBox(width: 12.0)),
                              ),
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
                                  final progressText = temPlanejado
                                      ? '$realizada$unidadeSuf realizados de um total de $planejada$unidadeSuf planejados'
                                      : '$realizada$unidadeSuf realizados'
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
                              FlutterFlowDropDown<int>(
                                controller:
                                    _model.dropDownStatusValueController!,
                                options: List<int>.from([1, 0, 2]),
                                optionLabels: [
                                  'Em andamento',
                                  'Paralizada',
                                  'Concluída'
                                ],
                                onChanged: (val) async {
                                  safeSetState(
                                      () => _model.dropDownStatusValue = val);
                                  _model.statusSelected =
                                      _model.dropDownStatusValue;
                                  safeSetState(() {});
                                },
                                width: double.infinity,
                                height: 56.0,
                                textStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .fontStyle,
                                    ),
                                hintText: 'Selecione o status',
                                icon: Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                                fillColor: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                elevation: 0.0,
                                borderColor:
                                    FlutterFlowTheme.of(context).alternate,
                                borderWidth: 1.0,
                                borderRadius: 8.0,
                                margin: EdgeInsetsDirectional.fromSTEB(
                                    12.0, 0.0, 12.0, 0.0),
                                hidesUnderline: true,
                                isSearchable: false,
                                isMultiSelect: false,
                                labelText: 'Status',
                                labelTextStyle: FlutterFlowTheme.of(context)
                                    .labelMedium
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .labelMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .fontStyle,
                                    ),
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(
                            color: FlutterFlowTheme.of(context).alternate,
                            width: 1.0,
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recursos Utilizados',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w600,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w600,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Insumos',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                        ),
                                  ),
                                  FutureBuilder<List<GetitensdaobraRow>>(
                                    future:
                                        SQLiteManager.instance.getitensdaobra(
                                      relatorioUuid: widget!.relatorioUuid!,
                                    ),
                                    builder: (context, snapshot) {
                                      // Customize what your widget looks like when it's loading.
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: LinearProgressIndicator(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        );
                                      }
                                      final dropDownInsumoGetitensdaobraRowList =
                                          snapshot.data!;

                                      return FlutterFlowDropDown<String>(
                                        controller: _model
                                                .dropDownInsumoValueController ??=
                                            FormFieldController<String>(
                                          _model.dropDownInsumoValue ??= '0',
                                        ),
                                        options: List<String>.from(
                                            dropDownInsumoGetitensdaobraRowList
                                                .map((e) => e.uuid)
                                                .withoutNulls
                                                .toList()),
                                        optionLabels:
                                            dropDownInsumoGetitensdaobraRowList
                                                .map((e) => e.nome)
                                                .withoutNulls
                                                .toList(),
                                        onChanged: (val) async {
                                          safeSetState(() =>
                                              _model.dropDownInsumoValue = val);
                                          _model.insumoSelected =
                                              _model.dropDownInsumoValue;
                                          safeSetState(() {});
                                          _model.uuidResultInsumos =
                                              await actions.generateUuid();
                                          await SQLiteManager.instance
                                              .setItemAtividade(
                                            relatorioAtividadeId:
                                                widget!.atividadeId!,
                                            tipo: 'insumo',
                                            obraItemId: 0,
                                            relatorioAtividadeUuid:
                                                widget!.atividadeUuid,
                                            uuid: _model.uuidResultInsumos,
                                            obraItemUuid: _model.insumoSelected,
                                          );
                                          _atualizarListasItensAtividade();
                                          safeSetState(() {});
                                        },
                                        width: double.infinity,
                                        height: 56.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText: 'Selecione um insumo',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        elevation: 0.0,
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderWidth: 1.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        isSearchable: false,
                                        isMultiSelect: false,
                                      );
                                    },
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      wrapWithModel(
                                        model: _model
                                            .insumosAtividadeRelatorioModel,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: InsumosAtividadeRelatorioWidget(
                                          relatorioUuid: widget!.relatorioUuid!,
                                          atividadeUuid: widget!.atividadeUuid!,
                                          listRefreshToken:
                                              _listasItensAtividadeRefresh,
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 12.0)),
                              ),
                              Divider(
                                thickness: 1.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Equipamentos',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                        ),
                                  ),
                                  FutureBuilder<List<CarregaItensObraRow>>(
                                    future:
                                        SQLiteManager.instance.carregaItensObra(
                                      tipo: 'equipamento',
                                      obraId: widget!.obraId,
                                      obraUuid: widget!.obraUuid!,
                                    ),
                                    builder: (context, snapshot) {
                                      // Customize what your widget looks like when it's loading.
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: LinearProgressIndicator(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        );
                                      }
                                      final dropDownEquipamentosCarregaItensObraRowList =
                                          snapshot.data!;

                                      return FlutterFlowDropDown<String>(
                                        controller: _model
                                                .dropDownEquipamentosValueController ??=
                                            FormFieldController<String>(
                                          _model.dropDownEquipamentosValue ??=
                                              '0',
                                        ),
                                        options: List<String>.from(
                                            dropDownEquipamentosCarregaItensObraRowList
                                                .map((e) => e.uuid)
                                                .toList()),
                                        optionLabels:
                                            dropDownEquipamentosCarregaItensObraRowList
                                                .map((e) => e.descricao)
                                                .toList(),
                                        onChanged: (val) async {
                                          safeSetState(() => _model
                                              .dropDownEquipamentosValue = val);
                                          _model.equipamentoSelected =
                                              _model.dropDownEquipamentosValue;
                                          safeSetState(() {});
                                          _model.uuidResultEquipamentos =
                                              await actions.generateUuid();
                                          await SQLiteManager.instance
                                              .setItemAtividade(
                                            relatorioAtividadeId:
                                                widget!.atividadeId!,
                                            tipo: 'equipamento',
                                            obraItemId: 0,
                                            relatorioAtividadeUuid:
                                                widget!.atividadeUuid,
                                            uuid: _model.uuidResultEquipamentos,
                                            obraItemUuid:
                                                _model.equipamentoSelected,
                                          );
                                          _atualizarListasItensAtividade();
                                          safeSetState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Item cadastrado!',
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                ),
                                              ),
                                              duration:
                                                  Duration(milliseconds: 4000),
                                              backgroundColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                            ),
                                          );
                                        },
                                        width: double.infinity,
                                        height: 56.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText: 'Selecione um equipamento',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        elevation: 0.0,
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderWidth: 1.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        isSearchable: false,
                                        isMultiSelect: false,
                                      );
                                    },
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      wrapWithModel(
                                        model: _model
                                            .equipamentosAtividadeRelatorioModel,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child:
                                            EquipamentosAtividadeRelatorioWidget(
                                          relatorioUuid: widget!.relatorioUuid!,
                                          atividadeUuid: widget!.atividadeUuid!,
                                          listRefreshToken:
                                              _listasItensAtividadeRefresh,
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 12.0)),
                              ),
                              Divider(
                                thickness: 1.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Mão de Obra',
                                    style: FlutterFlowTheme.of(context)
                                        .labelLarge
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelLarge
                                                    .fontStyle,
                                          ),
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .labelLarge
                                                  .fontStyle,
                                        ),
                                  ),
                                  FutureBuilder<List<GetMaoObraRelatorioRow>>(
                                    future: SQLiteManager.instance
                                        .getMaoObraRelatorio(
                                      relatorioUuid: widget!.relatorioUuid!,
                                    ).then((rows) {
                                      final seen = <String>{};
                                      final out = <GetMaoObraRelatorioRow>[];
                                      for (final e in rows) {
                                        if (e.statusPresenca
                                                .trim()
                                                .toLowerCase() !=
                                            'presente') {
                                          continue;
                                        }
                                        final u =
                                            (e.obraItemUuid ?? '').trim();
                                        if (u.isEmpty) continue;
                                        if (seen.add(u)) out.add(e);
                                      }
                                      return out;
                                    }),
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: LinearProgressIndicator(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                          ),
                                        );
                                      }
                                      final maoObraPresenteNoRelatorio =
                                          snapshot.data!;
                                      final itensDropdown =
                                          maoObraPresenteNoRelatorio
                                              .where(
                                                (e) => (e.obraItemUuid ?? '')
                                                    .trim()
                                                    .isNotEmpty,
                                              )
                                              .toList();

                                      if (itensDropdown.isEmpty) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 8.0),
                                          child: Text(
                                            'Nenhuma mão de obra marcada como presente neste relatório. '
                                            'Registre presença no relatório para vincular aqui.',
                                            style: FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodySmall
                                                            .fontStyle,
                                                  ),
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                ),
                                          ),
                                        );
                                      }

                                      return FlutterFlowDropDown<String>(
                                        controller: _model
                                                .dropDownMaoObraValueController ??=
                                            FormFieldController<String>(
                                          _model.dropDownMaoObraValue,
                                        ),
                                        options: itensDropdown
                                            .map((e) =>
                                                (e.obraItemUuid ?? '').trim())
                                            .toList(),
                                        optionLabels: itensDropdown
                                            .map(_labelMaoObraRelatorioPresente)
                                            .toList(),
                                        onChanged: (val) async {
                                          safeSetState(() => _model
                                              .dropDownMaoObraValue = val);
                                          _model.maoObraSelected =
                                              _model.dropDownMaoObraValue;
                                          safeSetState(() {});
                                          _model.uuidResultMo =
                                              await actions.generateUuid();
                                          await SQLiteManager.instance
                                              .setItemAtividade(
                                            relatorioAtividadeId:
                                                widget!.atividadeId!,
                                            tipo: 'mao_obra',
                                            obraItemId: 0,
                                            relatorioAtividadeUuid:
                                                widget!.atividadeUuid,
                                            uuid: _model.uuidResultMo,
                                            obraItemUuid:
                                                _model.maoObraSelected,
                                          );
                                          _atualizarListasItensAtividade();
                                          safeSetState(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Item cadastrado!',
                                                style: TextStyle(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                ),
                                              ),
                                              duration:
                                                  Duration(milliseconds: 4000),
                                              backgroundColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                            ),
                                          );
                                        },
                                        width: double.infinity,
                                        height: 56.0,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight: FontWeight.w500,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .fontStyle,
                                              ),
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .fontStyle,
                                            ),
                                        hintText:
                                            'Selecione mão de obra (presente no relatório)',
                                        icon: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 24.0,
                                        ),
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        elevation: 0.0,
                                        borderColor:
                                            FlutterFlowTheme.of(context)
                                                .alternate,
                                        borderWidth: 1.0,
                                        borderRadius: 8.0,
                                        margin: EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 12.0, 0.0),
                                        hidesUnderline: true,
                                        isSearchable: true,
                                        isMultiSelect: false,
                                      );
                                    },
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      wrapWithModel(
                                        model: _model
                                            .maoObraAtividadeRelatorioModel,
                                        updateCallback: () =>
                                            safeSetState(() {}),
                                        child: MaoObraAtividadeRelatorioWidget(
                                          relatorioUuid: widget!.relatorioUuid!,
                                          atividadeUuid: widget!.atividadeUuid!,
                                          listRefreshToken:
                                              _listasItensAtividadeRefresh,
                                        ),
                                      ),
                                    ].divide(SizedBox(height: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 12.0)),
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          ),
                        ),
                      ),
                      wrapWithModel(
                        model: _model.fotosAtividadeModel,
                        updateCallback: () => safeSetState(() {}),
                        child: FotosAtividadeWidget(
                          parameter1: widget!.atividadeId!,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          FFButtonWidget(
                            onPressed: () async {
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
                              );
                            },
                            text: 'Cancelar',
                            options: FFButtonOptions(
                              width: 120.0,
                              height: 48.0,
                              padding: EdgeInsets.all(8.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                          FFButtonWidget(
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
                              final qtdParsed =
                                  qtdTxt.isEmpty ? null : int.tryParse(qtdTxt);
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
                            text: 'Salvar',
                            options: FFButtonOptions(
                              width: 120.0,
                              height: 48.0,
                              padding: EdgeInsets.all(8.0),
                              iconPadding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 0.0),
                              color: FlutterFlowTheme.of(context).primary,
                              textStyle: FlutterFlowTheme.of(context)
                                  .titleSmall
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontWeight,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleSmall
                                          .fontStyle,
                                    ),
                                    color: FlutterFlowTheme.of(context).info,
                                    letterSpacing: 0.0,
                                    fontWeight: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontWeight,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .fontStyle,
                                  ),
                              elevation: 0.0,
                              borderSide: BorderSide(
                                color: Colors.transparent,
                                width: 1.0,
                              ),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                          ),
                        ].divide(SizedBox(width: 12.0)),
                      ),
                    ]
                        .divide(SizedBox(height: 24.0))
                        .addToStart(SizedBox(height: 16.0))
                        .addToEnd(SizedBox(height: 32.0)),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

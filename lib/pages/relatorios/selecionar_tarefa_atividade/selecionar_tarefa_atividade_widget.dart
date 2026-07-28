import '/backend/sqlite/sqlite_manager.dart';
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
import 'package:provider/provider.dart';
import 'selecionar_tarefa_atividade_model.dart';
export 'selecionar_tarefa_atividade_model.dart';

String _statusTarefaLabel(int? status) {
  switch (status) {
    case 1:
      return 'Em andamento';
    case 0:
      return 'Pendente';
    case 2:
      return 'Concluída';
    default:
      return 'Não informado';
  }
}

String _prioridadeTarefaLabel(double? porcentagem) {
  if (porcentagem == null) return 'Não informada';
  if (porcentagem >= 75) return 'Alta';
  if (porcentagem >= 40) return 'Média';
  return 'Baixa';
}

Color _prioridadeTarefaColor(BuildContext context, double? porcentagem) {
  if (porcentagem == null) {
    return FlutterFlowTheme.of(context).secondaryText;
  }
  if (porcentagem >= 75) return FlutterFlowTheme.of(context).error;
  if (porcentagem >= 40) return FlutterFlowTheme.of(context).warning;
  return FlutterFlowTheme.of(context).success;
}

/// crie uma página que onde vai ter um dropdown de seleciona etapa e abaixo
/// outro que vai listar a tarefa de acordo com a etapa marcada mas acima de
/// tudo tem que ter uma opção de seleção que se for marcada que vai buscar as
/// tarefas de uma ordem de serviço ele abre abaixo a opção de seleciona qual
/// ordem de serviço e quando a pessao seleciona a ordem de serviço aí vai
/// abrir as tarefas que tem nela para seleciona a tarefa especifica e depois
/// abaixo um botão de voltar e outro de avançar
///
class SelecionarTarefaAtividadeWidget extends StatefulWidget {
  const SelecionarTarefaAtividadeWidget({
    super.key,
    required this.relatorioID,
    required this.obraId,
    required this.relatorioUuid,
    required this.obraUuid,
  });

  final int? relatorioID;
  final int? obraId;
  final String? relatorioUuid;
  final String? obraUuid;

  static String routeName = 'SelecionarTarefaAtividade';
  static String routePath = '/selecionarTarefaAtividade';

  @override
  State<SelecionarTarefaAtividadeWidget> createState() =>
      _SelecionarTarefaAtividadeWidgetState();
}

class _SelecionarTarefaAtividadeWidgetState
    extends State<SelecionarTarefaAtividadeWidget> {
  late SelecionarTarefaAtividadeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SelecionarTarefaAtividadeModel());

    _model.switchOrdemValue = false;
    _model.usarTarefaListaOrdem = true;
  }

  void _limparSelecaoTarefa() {
    _model.tarefaSelected = null;
    _model.dropDownTarefasOrdemValue = null;
    _model.dropDownTarefasOrdemValueController?.value = null;
    _model.dropDownTarefasValue = null;
    _model.dropDownTarefasValueController?.value = null;
  }

  /// Etapa + tarefa (sem OS ou com OS em modo «Por etapa»).
  Widget _buildSelecaoPorEtapa(BuildContext context) {
                          return Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Text(
                                'Selecionar Etapa',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                              FutureBuilder<List<ListaEtapasObraRow>>(
                                future: SQLiteManager.instance.listaEtapasObra(
                                  obraUuid: widget!.obraUuid!,
                                ),
                                builder: (context, snapshot) {
                                  // Customize what your widget looks like when it's loading.
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: LinearProgressIndicator(
                                        color:
                                            FlutterFlowTheme.of(context).primary,
                                      ),
                                    );
                                  }
                                  final dropDownEtapaListaEtapasObraRowList =
                                      snapshot.data!;
  
                                  return FlutterFlowDropDown<String>(
                                    controller:
                                        _model.dropDownEtapaValueController ??=
                                            FormFieldController<String>(
                                      _model.dropDownEtapaValue ??= '0',
                                    ),
                                    options: List<String>.from(
                                        dropDownEtapaListaEtapasObraRowList
                                            .map((e) => e.uuid)
                                            .toList()),
                                    optionLabels:
                                        dropDownEtapaListaEtapasObraRowList
                                            .map((e) => valueOrDefault<String>(
                                                  e.nome,
                                                  'Nd',
                                                ))
                                            .toList(),
                                    onChanged: (val) async {
                                      safeSetState(
                                          () => _model.dropDownEtapaValue = val);
                                      _model.etapaSelected =
                                          _model.dropDownEtapaValue;
                                      safeSetState(() {});
                                    },
                                    width: double.infinity,
                                    height: 50.0,
                                    searchHintTextStyle:
                                        FlutterFlowTheme.of(context)
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
                                    searchTextStyle: FlutterFlowTheme.of(context)
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
                                    textStyle: FlutterFlowTheme.of(context)
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
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .fontWeight,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .fontStyle,
                                        ),
                                    hintText: 'Escolha uma etapa...',
                                    searchHintText: 'Buscar etapa...',
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: true,
                                    isMultiSelect: false,
                                  );
                                },
                              ),
                              Text(
                                'Tarefas da Etapa',
                                style: FlutterFlowTheme.of(context)
                                    .titleMedium
                                    .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w500,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .titleMedium
                                            .fontStyle,
                                      ),
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                              ),
                              FutureBuilder<List<ListaTarefasEtapasObraRow>>(
                                future:
                                    SQLiteManager.instance.listaTarefasEtapasObra(
                                  etapaUuid: _model.etapaSelected != null &&
                                          _model.etapaSelected != ''
                                      ? _model.etapaSelected!
                                      : '0',
                                ),
                                builder: (context, snapshot) {
                                  // Customize what your widget looks like when it's loading.
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: LinearProgressIndicator(
                                        color:
                                            FlutterFlowTheme.of(context).primary,
                                      ),
                                    );
                                  }
                                  final dropDownTarefasListaTarefasEtapasObraRowList =
                                      snapshot.data!;
  
                                  return FlutterFlowDropDown<String>(
                                    controller:
                                        _model.dropDownTarefasValueController ??=
                                            FormFieldController<String>(
                                      _model.dropDownTarefasValue ??= '0',
                                    ),
                                    options: List<String>.from(
                                        dropDownTarefasListaTarefasEtapasObraRowList
                                            .map((e) => e.uuid)
                                            .toList()),
                                    optionLabels:
                                        dropDownTarefasListaTarefasEtapasObraRowList
                                            .map((e) => e.descricao)
                                            .withoutNulls
                                            .toList(),
                                    onChanged: (val) async {
                                      safeSetState(() =>
                                          _model.dropDownTarefasValue = val);
                                      _model.tarefaSelected =
                                          _model.dropDownTarefasValue;
                                      safeSetState(() {});
                                    },
                                    width: double.infinity,
                                    height: 50.0,
                                    searchHintTextStyle:
                                        FlutterFlowTheme.of(context)
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
                                    searchTextStyle: FlutterFlowTheme.of(context)
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
                                    textStyle: FlutterFlowTheme.of(context)
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
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          letterSpacing: 0.0,
                                          fontWeight: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .fontWeight,
                                          fontStyle: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .fontStyle,
                                        ),
                                    hintText: 'Selecione uma tarefa...',
                                    searchHintText: 'Buscar tarefa...',
                                    icon: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 24.0,
                                    ),
                                    fillColor: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    elevation: 2.0,
                                    borderColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    borderWidth: 1.0,
                                    borderRadius: 8.0,
                                    margin: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    hidesUnderline: true,
                                    isOverButton: false,
                                    isSearchable: true,
                                    isMultiSelect: false,
                                  );
                                },
                              ),
                            ].divide(SizedBox(height: 16.0)),
                          );
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: FlutterFlowTheme.of(context).alternate,
            borderRadius: 20.0,
            borderWidth: 1.0,
            buttonSize: 40.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () {
              print('IconButton pressed ...');
            },
          ),
          title: Text(
            'Gerenciador de Tarefas',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).titleLarge.fontStyle,
                  ),
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle: FlutterFlowTheme.of(context).titleLarge.fontStyle,
                ),
          ),
          actions: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
              child: FlutterFlowIconButton(
                borderColor: FlutterFlowTheme.of(context).alternate,
                borderRadius: 20.0,
                borderWidth: 1.0,
                buttonSize: 40.0,
                icon: Icon(
                  Icons.settings_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 24.0,
                ),
                onPressed: () {
                  print('IconButton pressed ...');
                },
              ),
            ),
          ],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(12.0),
                        border: Border.all(
                          color: FlutterFlowTheme.of(context).alternate,
                          width: 1.0,
                        ),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              'Tipo de Busca',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Switch(
                                  value: _model.switchOrdemValue!,
                                  onChanged: (newValue) async {
                                    safeSetState(() {
                                      _model.switchOrdemValue = newValue!;
                                      if (!newValue) {
                                        _model.dropDownOrdemValue = null;
                                        _model.ordemSelected = null;
                                        _model.dropDownOrdemValueController
                                            ?.value = null;
                                        _model.usarTarefaListaOrdem = true;
                                        _model.dropDownEtapaValue = null;
                                        _model.etapaSelected = null;
                                        _model.dropDownEtapaValueController
                                            ?.value = null;
                                      } else {
                                        _model.usarTarefaListaOrdem = true;
                                      }
                                      _limparSelecaoTarefa();
                                    });
                                  },
                                  activeColor:
                                      FlutterFlowTheme.of(context).primary,
                                  activeTrackColor:
                                      FlutterFlowTheme.of(context).accent1,
                                  inactiveTrackColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  inactiveThumbColor:
                                      FlutterFlowTheme.of(context)
                                          .secondaryText,
                                ),
                                Expanded(
                                  child: Text(
                                    'Vincular ordem de serviço',
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
                                  ),
                                ),
                              ].divide(SizedBox(width: 12.0)),
                            ),
                          ].divide(SizedBox(height: 16.0)),
                        ),
                      ),
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      if (_model.switchOrdemValue ?? false) {
                        return Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              'Ordem de serviço (vínculo no RDO)',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                            ),
                            FutureBuilder<List<GetOrdensServicoRow>>(
                              future: SQLiteManager.instance.getOrdensServico(
                                obraUuid: widget!.obraUuid!,
                                userId: FFAppState().creatorId,
                              ),
                              builder: (context, snapshot) {
                                // Customize what your widget looks like when it's loading.
                                if (!snapshot.hasData) {
                                  return Center(
                                    child: LinearProgressIndicator(
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                    ),
                                  );
                                }
                                final dropDownOrdemGetOrdensServicoRowList =
                                    snapshot.data!;

                                return FlutterFlowDropDown<String>(
                                  controller:
                                      _model.dropDownOrdemValueController ??=
                                          FormFieldController<String>(
                                    _model.dropDownOrdemValue ??= '0',
                                  ),
                                  options: List<String>.from(
                                      dropDownOrdemGetOrdensServicoRowList
                                          .map((e) => e.uuid)
                                          .toList()),
                                  optionLabels:
                                      dropDownOrdemGetOrdensServicoRowList
                                          .map((e) => e.codigo)
                                          .toList(),
                                  onChanged: (val) async {
                                    safeSetState(
                                        () => _model.dropDownOrdemValue = val);
                                    _model.ordemSelected =
                                        valueOrDefault<String>(
                                      _model.dropDownOrdemValue,
                                      '0',
                                    );
                                    _limparSelecaoTarefa();
                                    safeSetState(() {});
                                  },
                                  width: double.infinity,
                                  height: 50.0,
                                  searchHintTextStyle:
                                      FlutterFlowTheme.of(context)
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
                                  searchTextStyle: FlutterFlowTheme.of(context)
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
                                  textStyle: FlutterFlowTheme.of(context)
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
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  hintText: 'Escolha uma ordem de serviço...',
                                  searchHintText: 'Buscar ordem...',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  elevation: 2.0,
                                  borderColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: true,
                                  isMultiSelect: false,
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  0.0, 0.0, 0.0, 4.0),
                              child: Text(
                                'Com a ordem acima como vínculo no RDO, escolha como localizar a tarefa: pela lista desta OS ou por etapa.',
                                style: FlutterFlowTheme.of(context)
                                    .bodySmall
                                    .override(
                                      font: GoogleFonts.inter(
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .fontWeight,
                                        fontStyle:
                                            FlutterFlowTheme.of(context)
                                                .bodySmall
                                                .fontStyle,
                                      ),
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                            Center(
                              child: SegmentedButton<bool>(
                                segments: const [
                                  ButtonSegment<bool>(
                                    value: true,
                                    label: Text('Lista da ordem'),
                                    icon: Icon(
                                      Icons.playlist_add_check_rounded,
                                      size: 18,
                                    ),
                                  ),
                                  ButtonSegment<bool>(
                                    value: false,
                                    label: Text('Por etapa'),
                                    icon: Icon(
                                      Icons.stairs_rounded,
                                      size: 18,
                                    ),
                                  ),
                                ],
                                emptySelectionAllowed: false,
                                selected: {_model.usarTarefaListaOrdem ?? true},
                                onSelectionChanged: (Set<bool> newSelection) {
                                  final next = newSelection.first;
                                  safeSetState(() {
                                    if ((_model.usarTarefaListaOrdem ?? true) ==
                                        next) {
                                      return;
                                    }
                                    _model.usarTarefaListaOrdem = next;
                                    _limparSelecaoTarefa();
                                    _model.dropDownEtapaValue = null;
                                    _model.etapaSelected = null;
                                    _model.dropDownEtapaValueController?.value =
                                        null;
                                  });
                                },
                              ),
                            ),
                            if (_model.usarTarefaListaOrdem ?? true) ...[
                            Text(
                              'Tarefas da Ordem de Serviço',
                              style: FlutterFlowTheme.of(context)
                                  .titleMedium
                                  .override(
                                    font: GoogleFonts.interTight(
                                      fontWeight: FontWeight.w500,
                                      fontStyle: FlutterFlowTheme.of(context)
                                          .titleMedium
                                          .fontStyle,
                                    ),
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                    fontStyle: FlutterFlowTheme.of(context)
                                        .titleMedium
                                        .fontStyle,
                                  ),
                            ),
                            FutureBuilder<List<GetTarefasOrdemRow>>(
                              future: SQLiteManager.instance.getTarefasOrdem(
                                ordemUuid: valueOrDefault<String>(
                                  _model.ordemSelected != null &&
                                          _model.ordemSelected != ''
                                      ? _model.ordemSelected
                                      : '0',
                                  '0',
                                ),
                              ),
                              builder: (context, snapshot) {
                                // Customize what your widget looks like when it's loading.
                                if (!snapshot.hasData) {
                                  return Center(
                                    child: LinearProgressIndicator(
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                    ),
                                  );
                                }
                                final dropDownTarefasOrdemGetTarefasOrdemRowList =
                                    snapshot.data!;

                                return FlutterFlowDropDown<String>(
                                  controller: _model
                                          .dropDownTarefasOrdemValueController ??=
                                      FormFieldController<String>(
                                    _model.dropDownTarefasOrdemValue ??= '0',
                                  ),
                                  options: List<String>.from(
                                      dropDownTarefasOrdemGetTarefasOrdemRowList
                                          .map((e) => valueOrDefault<String>(
                                                e.uuid,
                                                '0',
                                              ))
                                          .toList()),
                                  optionLabels:
                                      dropDownTarefasOrdemGetTarefasOrdemRowList
                                          .map((e) => e.nome)
                                          .withoutNulls
                                          .toList(),
                                  onChanged: (val) async {
                                    safeSetState(() =>
                                        _model.dropDownTarefasOrdemValue = val);
                                    _model.tarefaSelected =
                                        _model.dropDownTarefasOrdemValue;
                                    safeSetState(() {});
                                  },
                                  width: double.infinity,
                                  height: 50.0,
                                  searchHintTextStyle:
                                      FlutterFlowTheme.of(context)
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
                                  searchTextStyle: FlutterFlowTheme.of(context)
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
                                  textStyle: FlutterFlowTheme.of(context)
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
                                        color: FlutterFlowTheme.of(context)
                                            .primaryText,
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  hintText:
                                      'Selecione uma tarefa específica...',
                                  searchHintText: 'Buscar tarefa...',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  elevation: 2.0,
                                  borderColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  borderWidth: 1.0,
                                  borderRadius: 8.0,
                                  margin: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 0.0, 0.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: true,
                                  isMultiSelect: false,
                                );
                              },
                            ),
                            ],
                            if (!(_model.usarTarefaListaOrdem ?? true))
                              _buildSelecaoPorEtapa(context),
                          ].divide(SizedBox(height: 16.0)),
                        );
                      } else {
                        return _buildSelecaoPorEtapa(context);
                      }
                    },
                  ),
                  if (_model.tarefaSelected != null &&
                          _model.tarefaSelected != ''
                      ? true
                      : false)
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: FutureBuilder<List<GetDetalhesTarefaRow>>(
                        future: SQLiteManager.instance.getDetalhesTarefa(
                          uuid: _model.tarefaSelected != null &&
                                  _model.tarefaSelected != ''
                              ? _model.tarefaSelected!
                              : '0',
                        ),
                        builder: (context, snapshot) {
                          // Customize what your widget looks like when it's loading.
                          if (!snapshot.hasData) {
                            return Center(
                              child: LinearProgressIndicator(
                                color: FlutterFlowTheme.of(context).primary,
                              ),
                            );
                          }
                          final containerGetDetalhesTarefaRowList =
                              snapshot.data!;
                          final tarefa =
                              containerGetDetalhesTarefaRowList.firstOrNull;

                          return Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
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
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Icon(
                                        Icons.check_circle_rounded,
                                        color: FlutterFlowTheme.of(context)
                                            .success,
                                        size: 20.0,
                                      ),
                                      Text(
                                        'Tarefa Selecionada:',
                                        style: FlutterFlowTheme.of(context)
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
                                      ),
                                    ].divide(SizedBox(width: 8.0)),
                                  ),
                                  Text(
                                    valueOrDefault<String>(
                                      containerGetDetalhesTarefaRowList
                                          .firstOrNull?.descricao,
                                      'ND',
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                          font: GoogleFonts.interTight(
                                            fontWeight: FontWeight.w600,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .titleSmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                  ),
                                  Text(
                                    'Local: ${valueOrDefault<String>(tarefa?.local, 'Não informado')}',
                                    style: FlutterFlowTheme.of(context)
                                        .bodySmall
                                        .override(
                                          font: GoogleFonts.inter(
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .bodySmall
                                                    .fontStyle,
                                          ),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .bodySmall
                                                  .fontStyle,
                                        ),
                                  ),
                                  Divider(
                                    height: 1.0,
                                    thickness: 1.0,
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 12.0,
                                        height: 12.0,
                                        decoration: BoxDecoration(
                                          color: (tarefa?.status == 2)
                                              ? FlutterFlowTheme.of(context)
                                                  .success
                                              : (tarefa?.status == 1)
                                                  ? FlutterFlowTheme.of(context)
                                                      .warning
                                                  : FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        'Status: ${_statusTarefaLabel(tarefa?.status)}',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                      ),
                                    ].divide(SizedBox(width: 12.0)),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 12.0,
                                        height: 12.0,
                                        decoration: BoxDecoration(
                                          color: _prioridadeTarefaColor(
                                            context,
                                            tarefa?.porcentagem,
                                          ),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        'Prioridade: ${_prioridadeTarefaLabel(tarefa?.porcentagem)}',
                                        style: FlutterFlowTheme.of(context)
                                            .bodySmall
                                            .override(
                                              font: GoogleFonts.inter(
                                                fontWeight:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontWeight,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .bodySmall
                                                      .fontStyle,
                                            ),
                                      ),
                                    ].divide(SizedBox(width: 12.0)),
                                  ),
                                ].divide(SizedBox(height: 12.0)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: FFButtonWidget(
                          onPressed: () async {
                            context.pushNamed(
                              ObraAddRelatorioWidget.routeName,
                              queryParameters: {
                                'id': serializeParam(
                                  widget!.relatorioID,
                                  ParamType.int,
                                ),
                                'uuid': serializeParam(
                                  '',
                                  ParamType.String,
                                ),
                              }.withoutNulls,
                            );
                          },
                          text: 'Voltar',
                          icon: Icon(
                            Icons.arrow_back_rounded,
                            size: 20.0,
                          ),
                          options: FFButtonOptions(
                            height: 48.0,
                            padding: EdgeInsetsDirectional.fromSTEB(
                                20.0, 0.0, 20.0, 0.0),
                            iconPadding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 8.0, 0.0),
                            iconColor: FlutterFlowTheme.of(context).primaryText,
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
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
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
                      ),
                      if (_model.tarefaSelected != null &&
                          _model.tarefaSelected != '')
                        Expanded(
                          child: FutureBuilder<List<GetDetalhesTarefaRow>>(
                            future: SQLiteManager.instance.getDetalhesTarefa(
                              uuid: _model.tarefaSelected != null &&
                                      _model.tarefaSelected != ''
                                  ? _model.tarefaSelected!
                                  : '0',
                            ),
                            builder: (context, snapshot) {
                              // Customize what your widget looks like when it's loading.
                              if (!snapshot.hasData) {
                                return Center(
                                  child: LinearProgressIndicator(
                                    color: FlutterFlowTheme.of(context).primary,
                                  ),
                                );
                              }
                              final buttonGetDetalhesTarefaRowList =
                                  snapshot.data!;

                              return FFButtonWidget(
                                onPressed: () async {
                                  _model.relatorioDetalhes = await SQLiteManager
                                      .instance
                                      .relatorioDetalhes(
                                    uuid: widget!.relatorioUuid!,
                                    userUuid: FFAppState().creatorUuid,
                                    accountOwnerUuid: FFAppState().creatorUuid,
                                  );
                                  _model.uuid = await actions.generateUuid();

                                  int? ordemIdInsert;
                                  String? ordemUuidInsert;
                                  if (_model.switchOrdemValue == true) {
                                    final sel = (_model.dropDownOrdemValue ??
                                            _model.ordemSelected ??
                                            '')
                                        .trim();
                                    if (sel.isNotEmpty && sel != '0') {
                                      ordemUuidInsert = sel;
                                      final obraUuid = widget.obraUuid;
                                      if (obraUuid != null &&
                                          obraUuid.isNotEmpty) {
                                        final ordensRows =
                                            await SQLiteManager.instance
                                                .getOrdensServico(
                                          obraUuid: obraUuid,
                                          userId: FFAppState().creatorId,
                                        );
                                        ordemIdInsert = ordensRows
                                            .where(
                                                (o) => o.uuid == ordemUuidInsert)
                                            .firstOrNull
                                            ?.id;
                                      }
                                    }
                                  }

                                  await SQLiteManager.instance
                                      .insertAtividadeRelatorio(
                                    userId: FFAppState().UserID,
                                    relatorioId: widget!.relatorioID!,
                                    createdBy: FFAppState().UserID.toString(),
                                    local: buttonGetDetalhesTarefaRowList
                                        .firstOrNull?.local,
                                    descricao: buttonGetDetalhesTarefaRowList
                                        .firstOrNull?.descricao,
                                    quantidade: 0,
                                    unidade: buttonGetDetalhesTarefaRowList
                                        .firstOrNull?.unidade,
                                    item: buttonGetDetalhesTarefaRowList
                                        .firstOrNull?.item,
                                    tarefaId: buttonGetDetalhesTarefaRowList
                                        .firstOrNull?.id,
                                    ordemId: ordemIdInsert,
                                    ordemUuid: ordemUuidInsert,
                                    relatorioUuid: _model
                                        .relatorioDetalhes?.firstOrNull?.uuid,
                                    uuid: _model.uuid!,
                                    userUuid: FFAppState().creatorUuid,
                                    tarefaUuid: buttonGetDetalhesTarefaRowList
                                        .firstOrNull?.uuid,
                                  );
                                  _model.atividadeResult = await SQLiteManager
                                      .instance
                                      .carregaUltimaAtividadeRelatorio();

                                  context.pushNamed(
                                    AddAtividadeRelatorioWidget.routeName,
                                    queryParameters: {
                                      'relatorioId': serializeParam(
                                        widget!.relatorioID,
                                        ParamType.int,
                                      ),
                                      'obraId': serializeParam(
                                        widget!.obraId,
                                        ParamType.int,
                                      ),
                                      'atividadeId': serializeParam(
                                        _model.atividadeResult?.firstOrNull?.id,
                                        ParamType.int,
                                      ),
                                      'atividadeUuid': serializeParam(
                                        _model
                                            .atividadeResult?.firstOrNull?.uuid,
                                        ParamType.String,
                                      ),
                                      'relatorioUuid': serializeParam(
                                        widget!.relatorioUuid,
                                        ParamType.String,
                                      ),
                                      'obraUuid': serializeParam(
                                        widget!.obraUuid,
                                        ParamType.String,
                                      ),
                                    }.withoutNulls,
                                  );

                                  safeSetState(() {});
                                },
                                text: 'Avançar',
                                icon: Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20.0,
                                ),
                                options: FFButtonOptions(
                                  height: 48.0,
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      20.0, 0.0, 20.0, 0.0),
                                  iconPadding: EdgeInsetsDirectional.fromSTEB(
                                      8.0, 0.0, 0.0, 0.0),
                                  iconColor: Colors.white,
                                  color: FlutterFlowTheme.of(context).primary,
                                  textStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .override(
                                        font: GoogleFonts.interTight(
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                        color: Colors.white,
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
                              );
                            },
                          ),
                        ),
                    ].divide(SizedBox(width: 16.0)),
                  ),
                ]
                    .divide(SizedBox(height: 20.0))
                    .addToStart(SizedBox(height: 24.0))
                    .addToEnd(SizedBox(height: 24.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cadastrar_insumo_obra/cadastrar_insumo_obra_dialog.dart';
import '/componentes/relatorios/includes/botao_cadastro_obra_atalho/botao_cadastro_obra_atalho_widget.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:math';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'add_materiais_recebidos_relatorio_modal_copy_model.dart';
export 'add_materiais_recebidos_relatorio_modal_copy_model.dart';

class AddMateriaisRecebidosRelatorioModalCopyWidget extends StatefulWidget {
  const AddMateriaisRecebidosRelatorioModalCopyWidget({
    super.key,
    required this.uuid,
    required this.relatorioUuid,
    required this.obraUuid,
  });

  final String? uuid;
  final String? relatorioUuid;
  final String? obraUuid;

  @override
  State<AddMateriaisRecebidosRelatorioModalCopyWidget> createState() =>
      _AddMateriaisRecebidosRelatorioModalCopyWidgetState();
}

class _AddMateriaisRecebidosRelatorioModalCopyWidgetState
    extends State<AddMateriaisRecebidosRelatorioModalCopyWidget>
    with TickerProviderStateMixin {
  late AddMateriaisRecebidosRelatorioModalCopyModel _model;
  late Future<List<CarregaItensObraRow>> _itensObraFuture;
  int _itensObraReloadToken = 0;

  Future<List<CarregaItensObraRow>> _loadItensObra() {
    return SQLiteManager.instance.carregaItensObra(
      tipo: 'insumo',
      obraUuid: widget.obraUuid!,
      obraId: 0,
    );
  }

  void _reloadItensObra() {
    setState(() {
      _itensObraReloadToken++;
      _itensObraFuture = _loadItensObra();
    });
  }

  double _quantidadeRecebida() {
    final qtd = parseQuantidadeRelatorio(_model.qtdTextController.text);
    return qtd > 0 ? qtd : 1;
  }

  Future<bool> _inserirMaterialNoRelatorio(
    String obraItemUuid, {
    bool mostrarFeedback = true,
  }) async {
    if (obraItemUuid.trim().isEmpty || obraItemUuid == '0') return false;
    _model.uuidResult = await actions.generateUuid();
    await SQLiteManager.instance.cadastraEquipamentoRecebidoRelatorio(
      relatorioId: 0,
      equipamentoId: 0,
      quantidade: _quantidadeRecebida(),
      createdBy: FFAppState().creatorUuid,
      relatorioUuid: widget.relatorioUuid,
      equipamentoUuid: obraItemUuid,
      uuid: _model.uuidResult!,
    );
    if (!mounted) return false;
    if (mostrarFeedback) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Material incluído no relatório!',
            style: TextStyle(color: FlutterFlowTheme.of(context).primaryText),
          ),
          duration: const Duration(milliseconds: 4000),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    }
    return true;
  }

  Future<int> _inserirVariosMateriais(Iterable<String> obraItemUuids) async {
    final candidatos = obraItemUuids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e != '0')
        .toSet()
        .toList();
    var count = 0;
    for (final uuid in candidatos) {
      final ok = await _inserirMaterialNoRelatorio(
        uuid,
        mostrarFeedback: false,
      );
      if (ok) count++;
    }
    return count;
  }

  Future<void> _abrirCadastroInsumoNaObra() async {
    final novoUuid = await showCadastrarInsumoObraDialog(
      context: context,
      obraUuid: widget.obraUuid!,
    );
    if (!mounted || novoUuid == null || novoUuid.trim().isEmpty) return;

    _reloadItensObra();
    final selecionados = List<String>.from(_model.dropDownValue ?? const []);
    if (!selecionados.contains(novoUuid)) {
      selecionados.add(novoUuid);
    }
    safeSetState(() {
      _model.dropDownValue = selecionados;
      _model.materiaisSelecionados = selecionados;
      _model.dropDownValueController =
          FormFieldController<List<String>?>(selecionados);
    });

    final inseriu = await _inserirMaterialNoRelatorio(
      novoUuid,
      mostrarFeedback: true,
    );
    if (!mounted) return;
    if (inseriu) {
      FFAppState().update(() {});
      Navigator.pop(context);
    }
  }

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(
        context, () => AddMateriaisRecebidosRelatorioModalCopyModel());

    _model.qtdTextController ??= TextEditingController();
    _model.qtdFocusNode ??= FocusNode();
    _itensObraFuture = _loadItensObra();

    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 300.ms),
          MoveEffect(
            curve: Curves.bounceOut,
            delay: 300.0.ms,
            duration: 400.0.ms,
            begin: Offset(0.0, 100.0),
            end: Offset(0.0, 0.0),
          ),
          FadeEffect(
            curve: Curves.easeInOut,
            delay: 300.0.ms,
            duration: 400.0.ms,
            begin: 0.0,
            end: 1.0,
          ),
        ],
      ),
    });
    setupAnimations(
      animationsMap.values.where((anim) =>
          anim.trigger == AnimationTrigger.onActionTrigger ||
          !anim.applyInitialState),
      this,
    );
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16.0, 2.0, 16.0, 16.0),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(
              maxWidth: 900.0,
            ),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              boxShadow: [
                BoxShadow(
                  blurRadius: 12.0,
                  color: Color(0x1E000000),
                  offset: Offset(
                    0.0,
                    5.0,
                  ),
                )
              ],
              borderRadius: BorderRadius.circular(16.0),
            ),
            child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(24.0, 16.0, 0.0, 0.0),
                    child: Text(
                      'Adicionar materiais recebidos',
                      style:
                          FlutterFlowTheme.of(context).headlineMedium.override(
                                font: GoogleFonts.interTight(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .headlineMedium
                                      .fontStyle,
                                ),
                                fontSize: 16.0,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .headlineMedium
                                    .fontStyle,
                              ),
                    ),
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 32.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                24.0, 24.0, 24.0, 24.0),
                            child: FutureBuilder<List<CarregaItensObraRow>>(
                              key: ValueKey(
                                  'insumo_itens_$_itensObraReloadToken'),
                              future: _itensObraFuture,
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
                                final dropDownCarregaItensObraRowList =
                                    snapshot.data!;

                                return FlutterFlowDropDown<String>(
                                  multiSelectController:
                                      _model.dropDownValueController ??=
                                          FormFieldController<List<String>?>(
                                    _model.dropDownValue ??= <String>[],
                                  ),
                                  options: List<String>.from(
                                      dropDownCarregaItensObraRowList
                                          .map((e) => valueOrDefault<String>(
                                                e.uuid,
                                                'sem nome',
                                              ))
                                          .toList()),
                                  optionLabels: dropDownCarregaItensObraRowList
                                      .map((e) {
                                        final nome = e.descricao.trim();
                                        final um = e.unidade?.trim();
                                        if (um != null && um.isNotEmpty) {
                                          return nome.isEmpty
                                              ? um
                                              : '$nome ($um)';
                                        }
                                        return nome.isEmpty ? 'sem nome' : nome;
                                      })
                                      .toList(),
                                  onMultiSelectChanged: (vals) {
                                    final lista = (vals ?? [])
                                        .map((e) => e.trim())
                                        .where((e) =>
                                            e.isNotEmpty && e != '0')
                                        .toList();
                                    safeSetState(() {
                                      _model.dropDownValue = lista;
                                      _model.materiaisSelecionados = lista;
                                    });
                                  },
                                  width: MediaQuery.sizeOf(context).width * 1.0,
                                  height: 52.48,
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
                                        letterSpacing: 0.0,
                                        fontWeight: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontWeight,
                                        fontStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .fontStyle,
                                      ),
                                  hintText: 'Selecione um ou mais materiais',
                                  icon: Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    size: 24.0,
                                  ),
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  elevation: 2.0,
                                  borderColor:
                                      FlutterFlowTheme.of(context).alternate,
                                  borderWidth: 0.0,
                                  borderRadius: 8.0,
                                  margin: EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: true,
                                  searchHintText: 'Buscar material...',
                                  isMultiSelect: true,
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            24.0, 0.0, 24.0, 0.0,
                          ),
                          child: BotaoCadastroObraAtalhoWidget(
                            titulo: 'Novo material',
                            subtitulo:
                                'Cadastra na obra e adiciona ao relatório do dia',
                            icon: Icons.inventory_2_outlined,
                            onPressed: _abrirCadastroInsumoNaObra,
                            margin: EdgeInsets.zero,
                          ),
                        ),
                        Align(
                          alignment: AlignmentDirectional(-1.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                24.0, 16.0, 24.0, 16.0),
                            child: Container(
                              width: 200.0,
                              child: TextFormField(
                                controller: _model.qtdTextController,
                                focusNode: _model.qtdFocusNode,
                                autofocus: true,
                                obscureText: false,
                                decoration: InputDecoration(
                                  labelText: 'Quantidade (para cada material)',
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
                                  hintStyle: FlutterFlowTheme.of(context)
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
                                  enabledBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  errorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context).error,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                  ),
                                  filled: true,
                                  fillColor: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  contentPadding:
                                      EdgeInsetsDirectional.fromSTEB(
                                          20.0, 24.0, 20.0, 24.0),
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
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                cursorColor:
                                    FlutterFlowTheme.of(context).primary,
                                validator: _model.qtdTextControllerValidator
                                    .asValidator(context),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              24.0, 0.0, 24.0, 0.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Align(
                                alignment: AlignmentDirectional(0.0, 0.05),
                                child: FFButtonWidget(
                                  onPressed: () async {
                                    Navigator.pop(context);
                                  },
                                  text: 'Cancelar',
                                  options: FFButtonOptions(
                                    height: 44.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        24.0, 0.0, 24.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
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
                                    elevation: 0.0,
                                    borderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 2.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                    hoverColor:
                                        FlutterFlowTheme.of(context).alternate,
                                    hoverBorderSide: BorderSide(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 2.0,
                                    ),
                                    hoverTextColor: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    hoverElevation: 3.0,
                                  ),
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional(0.0, 0.05),
                                child: FFButtonWidget(
                                  onPressed: () async {
                                    final selecionados =
                                        (_model.materiaisSelecionados ??
                                                _model.dropDownValue ??
                                                const <String>[])
                                            .map((e) => e.trim())
                                            .where((e) =>
                                                e.isNotEmpty && e != '0')
                                            .toSet()
                                            .toList();
                                    if (selecionados.isEmpty) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Selecione um ou mais materiais ou cadastre um novo.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    final count = await _inserirVariosMateriais(
                                      selecionados,
                                    );
                                    if (!mounted || count == 0) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          count == 1
                                              ? '1 material incluído no relatório!'
                                              : '$count materiais incluídos no relatório!',
                                          style: TextStyle(
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                          ),
                                        ),
                                        duration:
                                            const Duration(milliseconds: 4000),
                                        backgroundColor:
                                            FlutterFlowTheme.of(context)
                                                .secondary,
                                      ),
                                    );
                                    FFAppState().update(() {});
                                    Navigator.pop(context);
                                    safeSetState(() {});
                                  },
                                  text: 'Salvar',
                                  options: FFButtonOptions(
                                    height: 44.0,
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        24.0, 0.0, 24.0, 0.0),
                                    iconPadding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 0.0, 0.0),
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
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          letterSpacing: 0.0,
                                          fontWeight:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontWeight,
                                          fontStyle:
                                              FlutterFlowTheme.of(context)
                                                  .titleSmall
                                                  .fontStyle,
                                        ),
                                    elevation: 3.0,
                                    borderSide: BorderSide(
                                      color: Colors.transparent,
                                      width: 1.0,
                                    ),
                                    borderRadius: BorderRadius.circular(12.0),
                                    hoverColor:
                                        FlutterFlowTheme.of(context).accent1,
                                    hoverBorderSide: BorderSide(
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      width: 1.0,
                                    ),
                                    hoverTextColor: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    hoverElevation: 0.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animateOnPageLoad(animationsMap['containerOnPageLoadAnimation']!),
        ),
      ),
    );
  }
}

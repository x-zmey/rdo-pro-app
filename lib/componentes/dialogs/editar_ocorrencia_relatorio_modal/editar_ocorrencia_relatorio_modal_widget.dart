import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/hh_mm_24h_input_formatter.dart';
import '/flutter_flow/relatorio_horarios_validation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'editar_ocorrencia_relatorio_modal_model.dart';
export 'editar_ocorrencia_relatorio_modal_model.dart';

class EditarOcorrenciaRelatorioModalWidget extends StatefulWidget {
  const EditarOcorrenciaRelatorioModalWidget({
    super.key,
    required this.relatorioId,
    required this.id,
    required this.relatorioUuid,
    required this.uuid,
  });

  final int? relatorioId;
  final int? id;
  final String? relatorioUuid;
  final String? uuid;

  @override
  State<EditarOcorrenciaRelatorioModalWidget> createState() =>
      _EditarOcorrenciaRelatorioModalWidgetState();
}

class _EditarOcorrenciaRelatorioModalWidgetState
    extends State<EditarOcorrenciaRelatorioModalWidget>
    with TickerProviderStateMixin {
  late EditarOcorrenciaRelatorioModalModel _model;

  final _formKey = GlobalKey<FormState>();
  int? _situacaoInicial;

  final animationsMap = <String, AnimationInfo>{};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditarOcorrenciaRelatorioModalModel());

    _model.textoOcorrenciaTextController = TextEditingController();
    _model.textoOcorrenciaFocusNode ??= FocusNode();

    _model.textController2 = TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();
    _model.textFieldMask1 = HhMm24hInputFormatter();

    _model.textController3 = TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();
    _model.textFieldMask2 = HhMm24hInputFormatter();

    _model.situacaoDropDownValueController =
        FormFieldController<String>(_model.situacaoDropDownValue ??= '1');

    _model.textoOcorrenciaTextControllerValidator = (context, val) {
      if (val == null || val.trim().isEmpty) {
        return 'Descreva a ocorrência';
      }
      return null;
    };

    _model.textController2Validator = (context, val) {
      final base = validateSingleHhMm(val);
      if (base != null) return base;
      final fim = _model.textController3?.text.trim() ?? '';
      if (fim.length == 5) {
        final mi = parseHhMmToMinutes(val!.trim());
        final mf = parseHhMmToMinutes(fim);
        if (mi != null && mf != null && mi > mf) {
          return 'Início não pode ser depois do término';
        }
      }
      return null;
    };

    _model.textController3Validator = (context, val) {
      final s = val?.trim() ?? '';
      if (s.isEmpty) return null;
      if (s.length < 5) {
        return 'Horário incompleto (use HH:mm)';
      }
      if (parseHhMmToMinutes(s) == null) {
        return 'Horário inválido (use 00:00 a 23:59)';
      }
      final ini = _model.textController2?.text.trim() ?? '';
      if (ini.length == 5) {
        final mi = parseHhMmToMinutes(ini);
        final mf = parseHhMmToMinutes(s);
        if (mi != null && mf != null && mf < mi) {
          return 'Término não pode ser antes do início';
        }
      }
      return null;
    };

    _model.textController2!.addListener(() => safeSetState(() {}));
    _model.textController3!.addListener(() => safeSetState(() {}));

    animationsMap.addAll({
      'containerOnPageLoadAnimation': AnimationInfo(
        trigger: AnimationTrigger.onPageLoad,
        effectsBuilder: () => [
          VisibilityEffect(duration: 300.ms),
          MoveEffect(
            curve: Curves.bounceOut,
            delay: 300.0.ms,
            duration: 400.0.ms,
            begin: const Offset(0.0, 100.0),
            end: const Offset(0.0, 0.0),
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

  bool get _horaInicioCompletaValida {
    final t = (_model.textController2?.text ?? '').trim();
    return t.length == 5 && parseHhMmToMinutes(t) != null;
  }

  String _duracaoOcorrenciaLabel() {
    final i = (_model.textController2?.text ?? '').trim();
    final f = (_model.textController3?.text ?? '').trim();
    if (i.length != 5 || f.length != 5) return '';
    final mi = parseHhMmToMinutes(i);
    final mf = parseHhMmToMinutes(f);
    if (mi == null || mf == null || mf <= mi) return '';
    final d = mf - mi;
    final h = d ~/ 60;
    final m = d % 60;
    if (h > 0) {
      return 'Duração: ${h}h ${m.toString().padLeft(2, '0')}min';
    }
    return 'Duração: $m min';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(16.0, 2.0, 16.0, 16.0),
          child: FutureBuilder<List<DetalhesOcorrenciaRow>>(
              future: SQLiteManager.instance.detalhesOcorrencia(
                uuid: widget.uuid!,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: LinearProgressIndicator(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  );
                }
                final rows = snapshot.data!;
                final row = rows.firstOrNull;
                if (row != null && !_model.detalhesPopulated) {
                  _model.detalhesPopulated = true;
                  final desc = row.descricao ?? '';
                  final hi = (row.horaInicio ?? '').trim();
                  final hf = (row.horaSaida ?? '').trim();
                  final sitStr =
                      row.situacao != null ? '${row.situacao}' : '1';
                  _situacaoInicial = int.tryParse(sitStr) ?? 1;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!context.mounted) return;
                    _model.textoOcorrenciaTextController!.text = desc;
                    _model.textController2!.text = hi;
                    _model.textController3!.text = hf;
                    _model.situacaoDropDownValue = sitStr;
                    _model.situacaoDropDownValueController?.value = sitStr;
                    safeSetState(() {});
                  });
                }

                return Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    maxWidth: 900.0,
                  ),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    boxShadow: const [
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
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            24.0, 16.0, 0.0, 0.0),
                        child: Text(
                          'Editar ocorrência',
                          style: FlutterFlowTheme.of(context)
                              .headlineMedium
                              .override(
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
                        padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0, 16.0, 0.0, 32.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Align(
                                alignment: const AlignmentDirectional(0.0, -1.0),
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      24.0, 16.0, 24.0, 16.0),
                                  child: TextFormField(
                                    controller:
                                        _model.textoOcorrenciaTextController,
                                    focusNode: _model.textoOcorrenciaFocusNode,
                                    autofocus: true,
                                    obscureText: false,
                                    decoration: InputDecoration(
                                      labelText: 'Escreva a ocorrência',
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
                                      alignLabelWithHint: true,
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
                                            fontWeight:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontWeight,
                                            fontStyle:
                                                FlutterFlowTheme.of(context)
                                                    .labelMedium
                                                    .fontStyle,
                                          ),
                                      enabledBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .alternate,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderSide: BorderSide(
                                          color: FlutterFlowTheme.of(context)
                                              .error,
                                          width: 2.0,
                                        ),
                                        borderRadius:
                                            BorderRadius.circular(12.0),
                                      ),
                                      filled: true,
                                      fillColor: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      contentPadding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              20.0, 24.0, 20.0, 24.0),
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
                                    maxLines: 5,
                                    minLines: 3,
                                    cursorColor:
                                        FlutterFlowTheme.of(context).primary,
                                    validator: _model
                                        .textoOcorrenciaTextControllerValidator
                                        .asValidator(context),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    24.0, 8.0, 24.0, 0.0),
                                child: FlutterFlowDropDown<String>(
                                  controller:
                                      _model.situacaoDropDownValueController ??=
                                          FormFieldController<String>(
                                    _model.situacaoDropDownValue ??= '1',
                                  ),
                                  options: MembershipAccess.canPermission(
                                              'resolve_ocorrencias') ||
                                          (_model.situacaoDropDownValue == '3')
                                      ? const ['1', '2', '3', '4']
                                      : const ['1', '2', '4'],
                                  optionLabels: MembershipAccess.canPermission(
                                              'resolve_ocorrencias') ||
                                          (_model.situacaoDropDownValue == '3')
                                      ? const [
                                          'Em andamento',
                                          'Em análise',
                                          'Resolvida',
                                          'Não resolvida',
                                        ]
                                      : const [
                                          'Em andamento',
                                          'Em análise',
                                          'Não resolvida',
                                        ],
                                  onChanged: (val) => safeSetState(
                                      () => _model.situacaoDropDownValue = val),
                                  width: MediaQuery.sizeOf(context).width * 0.9,
                                  height: 40.0,
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
                                  hintText: 'Situação',
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
                                  margin: const EdgeInsetsDirectional.fromSTEB(
                                      12.0, 0.0, 12.0, 0.0),
                                  hidesUnderline: true,
                                  isOverButton: false,
                                  isSearchable: false,
                                  isMultiSelect: false,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    24.0, 0.0, 24.0, 12.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Align(
                                            alignment:
                                                const AlignmentDirectional(
                                                    1.0, 0.0),
                                            child: TextButton(
                                              onPressed: () {
                                                _model.textController2?.text =
                                                    dateTimeFormat(
                                                        'HH:mm',
                                                        getCurrentTimestamp);
                                                safeSetState(() {});
                                              },
                                              child: Text(
                                                'Agora',
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium,
                                              ),
                                            ),
                                          ),
                                          TextFormField(
                                            controller: _model.textController2,
                                            focusNode:
                                                _model.textFieldFocusNode1,
                                            autofocus: false,
                                            enabled: true,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText: 'Hora início',
                                              labelStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                              hintText: '00:00',
                                              hintStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontStyle,
                                                  ),
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                            cursorColor:
                                                FlutterFlowTheme.of(context)
                                                    .primaryText,
                                            enableInteractiveSelection: true,
                                            validator: _model
                                                .textController2Validator
                                                .asValidator(context),
                                            inputFormatters: [
                                              _model.textFieldMask1
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Align(
                                            alignment:
                                                const AlignmentDirectional(
                                                    1.0, 0.0),
                                            child: TextButton(
                                              onPressed:
                                                  _horaInicioCompletaValida
                                                      ? () {
                                                          _model.textController3
                                                              ?.text = dateTimeFormat(
                                                              'HH:mm',
                                                              getCurrentTimestamp);
                                                          safeSetState(() {});
                                                        }
                                                      : null,
                                              child: Text(
                                                'Agora',
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .labelMedium,
                                              ),
                                            ),
                                          ),
                                          TextFormField(
                                            controller: _model.textController3,
                                            focusNode:
                                                _model.textFieldFocusNode2,
                                            autofocus: false,
                                            enabled: _horaInicioCompletaValida,
                                            obscureText: false,
                                            decoration: InputDecoration(
                                              isDense: true,
                                              labelText:
                                                  'Hora fim (opcional)',
                                              labelStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                              hintText: '00:00',
                                              hintStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelMedium
                                                      .override(
                                                        font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .labelMedium
                                                                  .fontStyle,
                                                        ),
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelMedium
                                                                .fontStyle,
                                                      ),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderSide: const BorderSide(
                                                  color: Color(0x00000000),
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              errorBorder: OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              focusedErrorBorder:
                                                  OutlineInputBorder(
                                                borderSide: BorderSide(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .error,
                                                  width: 1.0,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(8.0),
                                              ),
                                              filled: true,
                                              fillColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  font: GoogleFonts.inter(
                                                    fontWeight:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                            .fontWeight,
                                                    fontStyle:
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .bodyMedium
                                                          .fontStyle,
                                                  ),
                                                  letterSpacing: 0.0,
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontStyle,
                                                ),
                                            cursorColor:
                                                FlutterFlowTheme.of(context)
                                                    .primaryText,
                                            enableInteractiveSelection: true,
                                            validator: _model
                                                .textController3Validator
                                                .asValidator(context),
                                            inputFormatters: [
                                              _model.textFieldMask2
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ].divide(const SizedBox(width: 36.0)),
                                ),
                              ),
                              if (_duracaoOcorrenciaLabel().isNotEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsetsDirectional.fromSTEB(
                                          24.0, 4.0, 24.0, 0.0),
                                  child: Align(
                                    alignment:
                                        const AlignmentDirectional(-1.0, 0.0),
                                    child: Text(
                                      _duracaoOcorrenciaLabel(),
                                      style: FlutterFlowTheme.of(context)
                                          .labelSmall
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontWeight,
                                              fontStyle:
                                                  FlutterFlowTheme.of(context)
                                                      .labelSmall
                                                      .fontStyle,
                                            ),
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsetsDirectional.fromSTEB(
                                    24.0, 0.0, 24.0, 0.0),
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Align(
                                      alignment:
                                          const AlignmentDirectional(0.0, 0.05),
                                      child: FFButtonWidget(
                                        onPressed: () async {
                                          Navigator.of(context,
                                                  rootNavigator: true)
                                              .maybePop();
                                        },
                                        text: 'Cancelar',
                                        options: FFButtonOptions(
                                          height: 44.0,
                                          padding:
                                              const EdgeInsetsDirectional.fromSTEB(
                                                  24.0, 0.0, 24.0, 0.0),
                                          iconPadding:
                                              const EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 0.0),
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          textStyle: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
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
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          hoverColor:
                                              FlutterFlowTheme.of(context)
                                                  .alternate,
                                          hoverBorderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .alternate,
                                            width: 2.0,
                                          ),
                                          hoverTextColor:
                                              FlutterFlowTheme.of(context)
                                                  .primaryText,
                                          hoverElevation: 3.0,
                                        ),
                                      ),
                                    ),
                                    Align(
                                      alignment:
                                          const AlignmentDirectional(0.0, 0.05),
                                      child: FFButtonWidget(
                                        onPressed: () async {
                                          if (!MembershipAccess.canPermission(
                                              'edit_ocorrencias')) {
                                            MembershipAccess.showDenied(
                                              context,
                                              'Sem permissão para editar ocorrências.',
                                            );
                                            return;
                                          }
                                          if (_formKey.currentState
                                                  ?.validate() !=
                                              true) {
                                            return;
                                          }
                                          final situacaoStr = _model
                                                  .situacaoDropDownValue ??
                                              _model
                                                  .situacaoDropDownValueController
                                                  ?.value ??
                                              '1';
                                          final situacao =
                                              int.tryParse(situacaoStr) ?? 1;
                                          if (situacao == 3 &&
                                              (_situacaoInicial ?? 1) != 3 &&
                                              !MembershipAccess.canPermission(
                                                  'resolve_ocorrencias')) {
                                            MembershipAccess.showDenied(
                                              context,
                                              'Sem permissão para resolver ocorrências.',
                                            );
                                            return;
                                          }

                                          await SQLiteManager.instance
                                              .updateOcorrencia(
                                            uuid: widget.uuid!,
                                            descricao: _model
                                                .textoOcorrenciaTextController!
                                                .text,
                                            horaInicio:
                                                _model.textController2!.text,
                                            horaFim: _model
                                                .textController3!.text
                                                .trim(),
                                            situacao: situacao,
                                          );

                                          if (!context.mounted) return;
                                          FFAppState().update(() {});
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Ocorrência editada!',
                                                style: TextStyle(
                                                  color:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground,
                                                ),
                                              ),
                                              duration: const Duration(
                                                  milliseconds: 4000),
                                              backgroundColor:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                            ),
                                          );
                                          if (!context.mounted) return;
                                          Navigator.of(context,
                                                  rootNavigator: true)
                                              .maybePop();
                                        },
                                        text: 'Salvar',
                                        options: FFButtonOptions(
                                          height: 44.0,
                                          padding:
                                              const EdgeInsetsDirectional.fromSTEB(
                                                  24.0, 0.0, 24.0, 0.0),
                                          iconPadding:
                                              const EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 0.0, 0.0, 0.0),
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
                                          textStyle: FlutterFlowTheme.of(context)
                                              .titleSmall
                                              .override(
                                                font: GoogleFonts.interTight(
                                                  fontWeight:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleSmall
                                                          .fontWeight,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .titleSmall
                                                          .fontStyle,
                                                ),
                                                color:
                                                    FlutterFlowTheme.of(context)
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
                                          borderSide: const BorderSide(
                                            color: Colors.transparent,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                          hoverColor:
                                              FlutterFlowTheme.of(context)
                                                  .accent1,
                                          hoverBorderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .primary,
                                            width: 1.0,
                                          ),
                                          hoverTextColor:
                                              FlutterFlowTheme.of(context)
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
                      ),
                    ],
                  ),
                ).animateOnPageLoad(
                    animationsMap['containerOnPageLoadAnimation']!);
              },
            ),
        ),
      ),
    );
  }
}

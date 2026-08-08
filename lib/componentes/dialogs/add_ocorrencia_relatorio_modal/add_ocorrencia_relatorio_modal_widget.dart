import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import '/flutter_flow/hh_mm_24h_input_formatter.dart';
import '/flutter_flow/relatorio_horarios_validation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'add_ocorrencia_relatorio_modal_model.dart';
export 'add_ocorrencia_relatorio_modal_model.dart';

class AddOcorrenciaRelatorioModalWidget extends StatefulWidget {
  const AddOcorrenciaRelatorioModalWidget({
    super.key,
    required this.relatorioId,
    required this.uuid,
  });

  final int? relatorioId;
  final String? uuid;

  @override
  State<AddOcorrenciaRelatorioModalWidget> createState() =>
      _AddOcorrenciaRelatorioModalWidgetState();
}

class _AddOcorrenciaRelatorioModalWidgetState
    extends State<AddOcorrenciaRelatorioModalWidget> {
  late AddOcorrenciaRelatorioModalModel _model;
  final _formKey = GlobalKey<FormState>();
  bool _salvando = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddOcorrenciaRelatorioModalModel());

    _model.textoOcorrenciaTextController ??= TextEditingController();
    _model.textoOcorrenciaFocusNode ??= FocusNode();

    _model.textController2 ??= TextEditingController();
    _model.textFieldFocusNode1 ??= FocusNode();
    _model.textFieldMask1 = HhMm24hInputFormatter();

    _model.textController3 ??= TextEditingController();
    _model.textFieldFocusNode2 ??= FocusNode();
    _model.textFieldMask2 = HhMm24hInputFormatter();

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
      if (s.length < 5) return 'Horário incompleto (use HH:mm)';
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

  bool get _podeResolver =>
      MembershipAccess.canPermission('resolve_ocorrencias');

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

  void _snack(String msg, {bool erro = false}) {
    final theme = FlutterFlowTheme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: erro ? theme.error : theme.secondary,
      ),
    );
  }

  Future<void> _salvar() async {
    if (_salvando) return;
    if (!MembershipAccess.canPermission('create_ocorrencias')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para registrar ocorrências.',
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;

    final tipo = _model.tipoSelecionado ?? _model.dropDownValue;
    if (tipo == null || tipo.isEmpty || tipo == '0') {
      _snack('Selecione o tipo da ocorrência.', erro: true);
      return;
    }

    final situacaoStr = _model.situacaoDropDownValue ??
        _model.situacaoDropDownValueController?.value ??
        '1';
    final situacao = int.tryParse(situacaoStr) ?? 1;
    if (situacao == 3 && !_podeResolver) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para resolver ocorrências.',
      );
      return;
    }

    setState(() => _salvando = true);
    try {
      _model.resultUuid = await actions.generateUuid();
      if (!mounted) return;
      await SQLiteManager.instance.addOcorrenciaRelatorio(
        userId: FFAppState().UserID,
        relatorioId: widget.relatorioId!,
        descricao: _model.textoOcorrenciaTextController!.text.trim(),
        horaInicio: _model.textController2!.text.trim(),
        horaFim: _model.textController3!.text.trim(),
        relatorioUuid: widget.uuid!,
        uuid: _model.resultUuid!,
        creatorUuid: FFAppState().creatorUuid,
        userUuid: FFAppState().UserUuid,
        tipoUuid: tipo,
        situacao: situacao,
      );
      if (!mounted) return;
      FFAppState().update(() {});
      _snack('Ocorrência cadastrada!');
      Navigator.of(context, rootNavigator: true).maybePop();
    } catch (e) {
      if (mounted) {
        _snack('Não foi possível salvar: $e', erro: true);
        setState(() => _salvando = false);
      }
    }
  }

  Widget _rotulo(String texto, {IconData? icon}) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, left: 2),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: theme.primary),
            const SizedBox(width: 4),
          ],
          Text(texto.toUpperCase(), style: rdoColumnLabelStyle(context)),
        ],
      ),
    );
  }

  Widget _dropIcon(FlutterFlowTheme theme) => Icon(
        Icons.keyboard_arrow_down_rounded,
        color: theme.secondaryText,
        size: 18,
      );

  Widget _chipAgora({
    required VoidCallback? onPressed,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: const Size(0, 28),
        foregroundColor: theme.primary,
        disabledForegroundColor: theme.secondaryText.withValues(alpha: 0.4),
      ),
      icon: const Icon(Icons.schedule, size: 14),
      label: Text(
        'Agora',
        style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _campoHorario({
    required String titulo,
    required TextEditingController controller,
    required FocusNode focus,
    required HhMm24hInputFormatter mask,
    required String? Function(BuildContext, String?)? validator,
    required bool enabled,
    required VoidCallback? onAgora,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  titulo,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              _chipAgora(onPressed: onAgora),
            ],
          ),
          TextFormField(
            controller: controller,
            focusNode: focus,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [mask],
            style: rdoCompactFieldTextStyle(context),
            cursorColor: theme.primary,
            decoration: rdoCompactFieldDecoration(
              context,
              hint: 'HH:mm',
              fillColor: theme.secondaryBackground,
            ),
            validator: validator.asValidator(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final duracao = _duracaoOcorrenciaLabel();
    final situacaoOpts = _podeResolver
        ? const ['1', '2', '3', '4']
        : const ['1', '2', '4'];
    final situacaoLabels = _podeResolver
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
          ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(maxWidth: 560),
            decoration: rdoCardDecoration(context),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                  decoration: BoxDecoration(
                    color: theme.secondaryBackground,
                    border: Border(
                      bottom: BorderSide(color: theme.alternate),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: theme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: theme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Nova ocorrência',
                              style: GoogleFonts.interTight(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText,
                              ),
                            ),
                            Text(
                              'Registre uma ocorrência no relatório',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _salvando
                            ? null
                            : () => Navigator.of(context, rootNavigator: true)
                                .maybePop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final ladoALado = constraints.maxWidth >= 420;
                            final tipo = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _rotulo('Tipo *', icon: Icons.category_outlined),
                                FutureBuilder<List<GetTipoOcorrenciasRow>>(
                                  future:
                                      SQLiteManager.instance.getTipoOcorrencias(
                                    userUuid: FFAppState().creatorUuid,
                                  ),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 10),
                                        child: Center(
                                          child: SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                    final tipos = snapshot.data!;
                                    if (tipos.isEmpty) {
                                      return Text(
                                        'Nenhum tipo cadastrado. Sincronize e tente novamente.',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          color: theme.error,
                                        ),
                                      );
                                    }
                                    return FlutterFlowDropDown<String>(
                                      controller: _model
                                              .dropDownValueController ??=
                                          FormFieldController<String>(
                                        _model.dropDownValue,
                                      ),
                                      options: tipos
                                          .map((e) => e.uuid)
                                          .withoutNulls
                                          .toList(),
                                      optionLabels: tipos
                                          .map((e) => e.nome)
                                          .withoutNulls
                                          .toList(),
                                      onChanged: (val) {
                                        safeSetState(() {
                                          _model.dropDownValue = val;
                                          _model.tipoSelecionado = val;
                                        });
                                      },
                                      width: double.infinity,
                                      height: 38,
                                      textStyle:
                                          rdoCompactFieldTextStyle(context),
                                      hintText: 'Selecione o tipo',
                                      icon: _dropIcon(theme),
                                      fillColor: theme.secondaryBackground,
                                      elevation: 0,
                                      borderColor: theme.alternate,
                                      borderWidth: 1,
                                      borderRadius: 8,
                                      margin:
                                          const EdgeInsetsDirectional.fromSTEB(
                                              10, 0, 6, 0),
                                      hidesUnderline: true,
                                      isSearchable: false,
                                      isMultiSelect: false,
                                    );
                                  },
                                ),
                              ],
                            );
                            final situacao = Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _rotulo('Situação',
                                    icon: Icons.flag_outlined),
                                FlutterFlowDropDown<String>(
                                  controller: _model
                                          .situacaoDropDownValueController ??=
                                      FormFieldController<String>(
                                    _model.situacaoDropDownValue ??= '1',
                                  ),
                                  options: situacaoOpts,
                                  optionLabels: situacaoLabels,
                                  onChanged: (val) => safeSetState(
                                      () => _model.situacaoDropDownValue = val),
                                  width: double.infinity,
                                  height: 38,
                                  textStyle: rdoCompactFieldTextStyle(context),
                                  hintText: 'Situação',
                                  icon: _dropIcon(theme),
                                  fillColor: theme.secondaryBackground,
                                  elevation: 0,
                                  borderColor: theme.alternate,
                                  borderWidth: 1,
                                  borderRadius: 8,
                                  margin:
                                      const EdgeInsetsDirectional.fromSTEB(
                                          10, 0, 6, 0),
                                  hidesUnderline: true,
                                  isSearchable: false,
                                  isMultiSelect: false,
                                ),
                              ],
                            );
                            if (ladoALado) {
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: tipo),
                                  const SizedBox(width: 10),
                                  Expanded(child: situacao),
                                ],
                              );
                            }
                            return Column(
                              children: [
                                tipo,
                                const SizedBox(height: 10),
                                situacao,
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        _rotulo('Descrição *',
                            icon: Icons.notes_outlined),
                        TextFormField(
                          controller: _model.textoOcorrenciaTextController,
                          focusNode: _model.textoOcorrenciaFocusNode,
                          autofocus: true,
                          maxLines: 4,
                          minLines: 3,
                          maxLength: 500,
                          style: rdoCompactFieldTextStyle(context),
                          cursorColor: theme.primary,
                          decoration: rdoFormFieldDecoration(
                            context,
                            hint: 'Descreva a ocorrência...',
                          ).copyWith(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          validator: _model
                              .textoOcorrenciaTextControllerValidator
                              .asValidator(context),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _rotulo('Horário',
                                  icon: Icons.schedule_outlined),
                            ),
                            if (duracao.isNotEmpty)
                              Text(
                                duracao,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primary,
                                ),
                              ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: _campoHorario(
                                titulo: 'Início',
                                controller: _model.textController2!,
                                focus: _model.textFieldFocusNode1!,
                                mask: _model.textFieldMask1,
                                validator: _model.textController2Validator,
                                enabled: true,
                                onAgora: () {
                                  _model.textController2?.text = dateTimeFormat(
                                    'HH:mm',
                                    getCurrentTimestamp,
                                  );
                                  safeSetState(() {});
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _campoHorario(
                                titulo: 'Término (opcional)',
                                controller: _model.textController3!,
                                focus: _model.textFieldFocusNode2!,
                                mask: _model.textFieldMask2,
                                validator: _model.textController3Validator,
                                enabled: _horaInicioCompletaValida,
                                onAgora: _horaInicioCompletaValida
                                    ? () {
                                        _model.textController3?.text =
                                            dateTimeFormat(
                                          'HH:mm',
                                          getCurrentTimestamp,
                                        );
                                        safeSetState(() {});
                                      }
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 13,
                              color: theme.secondaryText,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                'Término opcional para ocorrências em aberto',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: theme.alternate),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _salvando
                              ? null
                              : () => Navigator.of(context, rootNavigator: true)
                                  .maybePop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            foregroundColor: theme.primaryText,
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
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _salvando ? null : _salvar,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 44),
                            backgroundColor: theme.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                theme.primary.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: _salvando
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
                            _salvando ? 'Salvando…' : 'Salvar',
                            style: GoogleFonts.inter(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
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
      ),
    );
  }
}

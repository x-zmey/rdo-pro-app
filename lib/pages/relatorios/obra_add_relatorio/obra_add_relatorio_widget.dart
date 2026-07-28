import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/add_anexo_relatorio/add_anexo_relatorio_widget.dart';
import '/componentes/dialogs/add_comentario_relatorio_modal/add_comentario_relatorio_modal_widget.dart';
import '/componentes/dialogs/add_mao_obra_vinculada/add_mao_obra_vinculada_widget.dart';
import '/componentes/dialogs/add_materiais_recebidos_relatorio_modal_copy/add_materiais_recebidos_relatorio_modal_copy_widget.dart';
import '/componentes/dialogs/add_ocorrencia_relatorio_modal/add_ocorrencia_relatorio_modal_widget.dart';
import '/componentes/dialogs/add_ordens_custo_relatorio/add_ordens_custo_relatorio_widget.dart';
import '/componentes/dialogs/add_relatorio_tipo_dialog/add_relatorio_tipo_dialog_widget.dart';
import '/componentes/dialogs/cofirma_exclusao_mao_obra_relatorio/cofirma_exclusao_mao_obra_relatorio_widget.dart';
import '/componentes/dialogs/concluir_relatorio_dialog/concluir_relatorio_dialog_widget.dart';
import '/componentes/forms/mao_obra_horarios_form/mao_obra_horarios_form_widget.dart';
import '/componentes/forms/mao_obra_presenca_controls/mao_obra_presenca_controls_widget.dart';
import '/componentes/relatorios/anexos_relatorios/anexos_relatorios_widget.dart';
import '/componentes/relatorios/atividades_relatorio/atividades_relatorio_widget.dart';
import '/componentes/relatorios/comentarios_relatorio/comentarios_relatorio_widget.dart';
import '/componentes/relatorios/materiais_recebidos_relatorio/materiais_recebidos_relatorio_widget.dart';
import '/componentes/relatorios/ocorrencias_relatorio/ocorrencias_relatorio_widget.dart';
import '/componentes/relatorios/ordens_custo_relatorio/ordens_custo_relatorio_widget.dart';
import '/componentes/relatorios/includes/botao_adicionar_secao_relatorio/botao_adicionar_secao_relatorio_widget.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/hh_mm_24h_input_formatter.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:math';
import 'dart:ui';
import '/index.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:provider/provider.dart';
import 'obra_add_relatorio_horarios.dart';
import 'obra_add_relatorio_model.dart';
export 'obra_add_relatorio_model.dart';

bool _statusImpedeEdicaoRelatorio(int statusId) =>
    statusId == 2 || statusId == 3;

/// Diálogo mais estreito nas laterais, sem o limite padrão ~90% de largura
/// inútil em tablets.
Widget _rdoDialogWide(Widget child) {
  return Dialog(
    clipBehavior: Clip.antiAlias,
    elevation: 0,
    backgroundColor: Colors.transparent,
    insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 20),
    child: Builder(
      builder: (context) {
        final w = MediaQuery.sizeOf(context).width;
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: min(w * 0.98, 960.0),
          ),
          child: child,
        );
      },
    ),
  );
}

/// Exibe data do relatório (SQLite pode vir como yyyy-MM-dd).
String _dataExecutadoParaExibicao(String? raw) {
  if (raw == null) return '---';
  final s = raw.trim();
  if (s.isEmpty) return '---';
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
    final p = s.substring(0, 10).split('-');
    if (p.length == 3) return '${p[2]}/${p[1]}/${p[0]}';
  }
  if (s.contains('/')) return s.split(' ').first;
  return s;
}

class ObraAddRelatorioWidget extends StatefulWidget {
  const ObraAddRelatorioWidget({
    super.key,
    required this.id,
    required this.uuid,
  });

  final int? id;
  final String? uuid;

  static String routeName = 'obraAddRelatorio';
  static String routePath = '/obraAddRelatorio';

  @override
  State<ObraAddRelatorioWidget> createState() => _ObraAddRelatorioWidgetState();
}

class _ObraAddRelatorioWidgetState extends State<ObraAddRelatorioWidget>
    with TickerProviderStateMixin {
  late ObraAddRelatorioModel _model;
  late AnimationController _animationController;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// Seções abaixo de "Horários de Trabalho": `true` = expandida.
  static const _secMaoObra = 'maoObra';
  static const _secMateriais = 'materiais';
  static const _secAtividades = 'atividades';
  static const _secCustos = 'custos';
  static const _secComentarios = 'comentarios';
  static const _secOcorrencias = 'ocorrencias';
  static const _secAnexos = 'anexos';

  final Map<String, bool> _relatorioSecaoExpandida = {
    _secMaoObra: false,
    _secMateriais: false,
    _secAtividades: false,
    _secCustos: false,
    _secComentarios: false,
    _secOcorrencias: false,
    _secAnexos: false,
  };

  void _toggleRelatorioSecao(String chave) {
    setState(() {
      _relatorioSecaoExpandida[chave] =
          !(_relatorioSecaoExpandida[chave] ?? false);
    });
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ObraAddRelatorioModel());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _model.textFieldNumeroFocusNode1 ??= FocusNode();
    _model.textFieldDataFocusNode ??= FocusNode();
    _model.textFieldDataMask = MaskTextInputFormatter(mask: '##/##/####');
    _model.textFieldNumeroFocusNode2 ??= FocusNode();
    _model.textFieldNumeroMask2 = HhMm24hInputFormatter();
    _model.textFieldHorasFocusNode1 ??= FocusNode();
    _model.textFieldHorasMask1 = HhMm24hInputFormatter();
    _model.textFieldHorasFocusNode2 ??= FocusNode();
    _model.textFieldHorasMask2 = HhMm24hInputFormatter();
    _model.textFieldHorasFocusNode3 ??= FocusNode();
    _model.textFieldHorasMask3 = HhMm24hInputFormatter();

    _model.textFieldNumeroTextController2Validator =
        (c, v) => validateEntradaField(_model, v);
    _model.textFieldHorasTextController1Validator =
        (c, v) => validateInicioIntervaloField(_model, v);
    _model.textFieldHorasTextController2Validator =
        (c, v) => validateFimIntervaloField(_model, v);
    _model.textFieldHorasTextController3Validator =
        (c, v) => validateSaidaField(_model, v);

    _animationController.forward();
  }

  Future<void> _updateRelatorioDebounced(
    BuildContext context, {
    required String dataExecutadoSql,
    required String successMessage,
  }) async {
    final err = validateHorariosSequence(_model);
    if (err != null) {
      if (context.mounted) {
        showHorarioErroSnackBar(context, err);
      }
      return;
    }
    await SQLiteManager.instance.updateRelatorio(
      dataExecutado: dataExecutadoSql,
      horas: '',
      id: widget.id!.toString(),
      entradaManha: _model.textFieldNumeroTextController2!.text,
      inicioIntervalo: _model.textFieldHorasTextController1!.text,
      fimIntervalo: _model.textFieldHorasTextController2!.text,
      saidaTarde: _model.textFieldHorasTextController3!.text,
    );
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          successMessage,
          style:
              TextStyle(color: FlutterFlowTheme.of(context).primaryBackground),
        ),
        duration: const Duration(milliseconds: 2000),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _abrirVoltarParaObra(
    BuildContext context, {
    required int? obraId,
    required String? obraUuid,
  }) {
    context.pushNamed(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(obraId, ParamType.int),
        'obraUuid': serializeParam(obraUuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.topToBottom,
        ),
      },
    );
  }

  /// Sai da edição sem alterar status (dados já persistem automaticamente).
  void _irParaDetalhesObra({
    required int? obraId,
    required String? obraUuid,
  }) {
    final router = GoRouter.of(context);
    final destino = router.namedLocation(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(obraId, ParamType.int),
        'obraUuid': serializeParam(obraUuid, ParamType.String),
      }.withoutNulls,
    );
    router.go(destino);
  }

  Widget _buildTelaEdicaoBloqueada(
    BuildContext context, {
    required int? obraId,
    required String? obraUuid,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: Container(
          margin: const EdgeInsets.only(left: 8),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.primary),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                _abrirVoltarParaObra(
                  context,
                  obraId: obraId,
                  obraUuid: obraUuid,
                );
              }
            },
          ),
        ),
        title: Text(
          'Edição de Relatório',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.primaryText,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _animationController,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: kBarraNavegacaoPrincipalReservaScroll,
                ),
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: theme.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Icon(
                            Icons.lock_outline,
                            size: 40,
                            color: theme.warning,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Edição Bloqueada',
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Não é possível editar este relatório. Ele está aguardando aprovação ou já foi aprovado.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: theme.secondaryText,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),
                        FilledButton(
                          onPressed: () {
                            if (context.canPop()) {
                              context.pop();
                            } else {
                              _abrirVoltarParaObra(
                                context,
                                obraId: obraId,
                                obraUuid: obraUuid,
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Voltar'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BarraNavegacaoPrincipal(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _model.dispose();
    super.dispose();
  }

  BoxDecoration _decoBlocoAdicionar(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return BoxDecoration(
      color: theme.secondaryBackground,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    return FutureBuilder<List<RelatorioDetalhesRow>>(
      future: SQLiteManager.instance.relatorioDetalhes(
        uuid: widget!.uuid!,
        userUuid: FFAppState().creatorUuid,
        accountOwnerUuid: FFAppState().creatorUuid,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: theme.primaryBackground,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: theme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Carregando...',
                    style: GoogleFonts.inter(
                        fontSize: 14, color: theme.secondaryText),
                  ),
                ],
              ),
            ),
          );
        }

        final obraAddRelatorioRelatorioDetalhesRowList = snapshot.data!;
        if (obraAddRelatorioRelatorioDetalhesRowList.isNotEmpty) {
          final st =
              obraAddRelatorioRelatorioDetalhesRowList.firstOrNull?.statusId;
          if (st != null && _statusImpedeEdicaoRelatorio(st)) {
            return _buildTelaEdicaoBloqueada(
              context,
              obraId:
                  obraAddRelatorioRelatorioDetalhesRowList.firstOrNull?.obraId,
              obraUuid: obraAddRelatorioRelatorioDetalhesRowList
                  .firstOrNull?.obraUuid,
            );
          }
        }

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: theme.primaryBackground,
            appBar: _buildAppBar(theme, obraAddRelatorioRelatorioDetalhesRowList),
            body: FadeTransition(
              opacity: _animationController,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: AlignmentDirectional(0.0, 1.0),
                children: [
                  Align(
                    alignment: AlignmentDirectional(0.0, -1.0),
                    child: Padding(
                      padding: const EdgeInsets.only(
                        bottom: kBarraNavegacaoPrincipalReservaScroll,
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildHeaderCard(theme,
                                obraAddRelatorioRelatorioDetalhesRowList),
                            const SizedBox(height: 12),
                            _buildInfoCard(theme,
                                obraAddRelatorioRelatorioDetalhesRowList),
                            const SizedBox(height: 12),
                            _buildHorariosCard(theme,
                                obraAddRelatorioRelatorioDetalhesRowList),
                            const SizedBox(height: 12),
                            _buildMaoObraCard(theme,
                                obraAddRelatorioRelatorioDetalhesRowList),
                            const SizedBox(height: 12),
                            _buildMateriaisCard(theme,
                                obraAddRelatorioRelatorioDetalhesRowList),
                            const SizedBox(height: 12),
                            _buildAtividadesCard(
                                theme, obraAddRelatorioRelatorioDetalhesRowList),
                            const SizedBox(height: 12),
                            _buildCustosCard(
                                theme, obraAddRelatorioRelatorioDetalhesRowList),
                            const SizedBox(height: 12),
                            _buildComentariosCard(theme),
                            const SizedBox(height: 12),
                            _buildOcorrenciasCard(theme),
                            const SizedBox(height: 12),
                            _buildAnexosCard(theme),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: BarraNavegacaoPrincipal(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: Container(
        margin: const EdgeInsets.only(left: 8),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.primary),
          onPressed: () => context.pop(),
        ),
      ),
      title: Text(
        'Edição de Relatório',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: theme.primaryText,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => _irParaDetalhesObra(
            obraId: data.firstOrNull?.obraId,
            obraUuid: data.firstOrNull?.obraUuid,
          ),
          style: TextButton.styleFrom(
            foregroundColor: theme.secondaryText,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            minimumSize: const Size(0, 36),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Salvar',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: FilledButton(
            onPressed: () async {
              await showDialog(
                context: context,
                builder: (dialogContext) => _rdoDialogWide(
                  ConcluirRelatorioDialogWidget(
                    relatorioId: widget.id!,
                    obraId: data.firstOrNull?.obraId,
                    relatorioUuid: widget.uuid!,
                    obraUuid: data.firstOrNull?.obraUuid,
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: theme.primary,
              foregroundColor: theme.info,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'Enviar para aprovação',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderCard(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Preenchendo',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          Text(
            'RDO #${data.firstOrNull?.numero ?? '---'}',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _decoBlocoAdicionar(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildReadOnlyField(
                    theme,
                    label: 'Nº',
                    value: data.firstOrNull?.numero?.toString() ?? '---',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildReadOnlyField(
                    theme,
                    label: 'Data',
                    value: _dataExecutadoParaExibicao(
                        data.firstOrNull?.dataExecutado),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FutureBuilder<List<ObraDetalhesRow>>(
              future: SQLiteManager.instance.obraDetalhes(
                uuid: data.firstOrNull?.obraUuid,
                userId: FFAppState().creatorId,
                accountOwnerUuid: FFAppState().creatorUuid,
              ),
              builder: (context, snapshot) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.alternate.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    snapshot.data?.firstOrNull?.nome ?? 'Carregando...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorariosCard(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _decoBlocoAdicionar(context),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Horários de Trabalho',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTimeField(
                  theme,
                  controlName: 'entrada',
                  ensure: (t) => _model.textFieldNumeroTextController2 ??=
                      TextEditingController(text: t),
                  focusNode: _model.textFieldNumeroFocusNode2,
                  label: 'Entrada',
                  value: data.firstOrNull?.entradaManha ?? '',
                  onSaved: () => _updateRelatorioDebounced(
                    context,
                    dataExecutadoSql: data.firstOrNull?.dataExecutado ?? '',
                    successMessage: 'Horário atualizado!',
                  ),
                  validator: _model.textFieldNumeroTextController2Validator
                      .asValidator(context),
                ),
                const SizedBox(width: 8),
                _buildTimeField(
                  theme,
                  controlName: 'inicio',
                  ensure: (t) => _model.textFieldHorasTextController1 ??=
                      TextEditingController(text: t),
                  focusNode: _model.textFieldHorasFocusNode1,
                  label: 'Início int.',
                  value: data.firstOrNull?.inicioIntervalo ?? '',
                  onSaved: () => _updateRelatorioDebounced(
                    context,
                    dataExecutadoSql: data.firstOrNull?.dataExecutado ?? '',
                    successMessage: 'Horário atualizado!',
                  ),
                  validator: _model.textFieldHorasTextController1Validator
                      .asValidator(context),
                ),
                const SizedBox(width: 8),
                _buildTimeField(
                  theme,
                  controlName: 'fim',
                  ensure: (t) => _model.textFieldHorasTextController2 ??=
                      TextEditingController(text: t),
                  focusNode: _model.textFieldHorasFocusNode2,
                  label: 'Fim int.',
                  value: data.firstOrNull?.fimIntervalo ?? '',
                  onSaved: () => _updateRelatorioDebounced(
                    context,
                    dataExecutadoSql: data.firstOrNull?.dataExecutado ?? '',
                    successMessage: 'Horário atualizado!',
                  ),
                  validator: _model.textFieldHorasTextController2Validator
                      .asValidator(context),
                ),
                const SizedBox(width: 8),
                _buildTimeField(
                  theme,
                  controlName: 'saida',
                  ensure: (t) => _model.textFieldHorasTextController3 ??=
                      TextEditingController(text: t),
                  focusNode: _model.textFieldHorasFocusNode3,
                  label: 'Saída',
                  value: data.firstOrNull?.saidaTarde ?? '',
                  onSaved: () => _updateRelatorioDebounced(
                    context,
                    dataExecutadoSql: data.firstOrNull?.dataExecutado ?? '',
                    successMessage: 'Horário atualizado!',
                  ),
                  validator: _model.textFieldHorasTextController3Validator
                      .asValidator(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// [ensure] cria o controller com o texto vindo do SQLite (só na 1.ª atribuição, como no FF antigo).
  Widget _buildTimeField(
    FlutterFlowTheme theme, {
    required String controlName,
    required TextEditingController Function(String initial) ensure,
    required FocusNode? focusNode,
    required String label,
    required String value,
    required Future<void> Function() onSaved,
    String? Function(String?)? validator,
  }) {
    return Expanded(
      child: TextFormField(
        controller: ensure(value),
        focusNode: focusNode,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        validator: validator,
        onChanged: (_) => EasyDebounce.debounce(
          'time_hr_$controlName',
          const Duration(milliseconds: 2000),
          () async {
            await onSaved();
          },
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(fontSize: 11),
          filled: true,
          fillColor: theme.secondaryBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.alternate),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.error),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: theme.error, width: 1.5),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          counterText: '',
        ),
        style: GoogleFonts.inter(fontSize: 13),
        textAlign: TextAlign.center,
        maxLength: 5,
        maxLengthEnforcement: MaxLengthEnforcement.enforced,
        keyboardType: TextInputType.number,
        inputFormatters: [HhMm24hInputFormatter()],
      ),
    );
  }

  Widget _buildReadOnlyField(
    FlutterFlowTheme theme, {
    required String label,
    required String value,
  }) {
    return TextFormField(
      initialValue: value,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.inter(fontSize: 12),
        filled: true,
        fillColor: theme.alternate.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildSectionCard({
    required FlutterFlowTheme theme,
    required String title,
    required Widget child,
    required VoidCallback onAdd,
    String addTooltip = 'Adicionar',
    bool showAdd = true,
    String? secaoRecolherChave,
    EdgeInsetsGeometry sectionMargin =
        const EdgeInsets.symmetric(horizontal: 16),
    EdgeInsetsGeometry contentPadding = const EdgeInsets.all(12),
  }) {
    final expandida = secaoRecolherChave == null
        ? true
        : (_relatorioSecaoExpandida[secaoRecolherChave] ?? false);

    return Container(
      margin: sectionMargin,
      decoration: _decoBlocoAdicionar(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 4),
            child: Row(
              children: [
                if (secaoRecolherChave != null)
                  IconButton(
                    onPressed: () => _toggleRelatorioSecao(secaoRecolherChave),
                    tooltip: expandida ? 'Recolher' : 'Expandir',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.transparent,
                      foregroundColor: theme.secondaryText,
                    ),
                    icon: Icon(
                      expandida
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: 22,
                    ),
                  )
                else
                  const SizedBox(width: 4),
                Expanded(
                  child: secaoRecolherChave != null
                      ? InkWell(
                          onTap: () =>
                              _toggleRelatorioSecao(secaoRecolherChave),
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 6,
                              horizontal: 2,
                            ),
                            child: Text(
                              title,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText,
                              ),
                            ),
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 4,
                          ),
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: theme.primaryText,
                            ),
                          ),
                        ),
                ),
                if (showAdd)
                  BotaoAdicionarSecaoRelatorioWidget(
                    onPressed: onAdd,
                    tooltip: addTooltip,
                  ),
              ],
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: expandida
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      Padding(
                        padding: contentPadding,
                        child: child,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildMaoObraCard(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return _buildSectionCard(
      theme: theme,
      title: 'Gestão de Mão de Obra',
      secaoRecolherChave: _secMaoObra,
      addTooltip: 'Adicionar mão de obra',
      onAdd: () async {
        await showDialog(
          context: context,
          builder: (dialogContext) => _rdoDialogWide(
            AddMaoObraVinculadaWidget(
              obraUuid: data.firstOrNull!.obraUuid,
              relatorioUuid: widget!.uuid!,
              relatorioEntradaManha:
                  _model.textFieldNumeroTextController2?.text,
              relatorioInicioIntervalo:
                  _model.textFieldHorasTextController1?.text,
              relatorioFimIntervalo:
                  _model.textFieldHorasTextController2?.text,
              relatorioSaidaTarde:
                  _model.textFieldHorasTextController3?.text,
            ),
          ),
        );
      },
      child: FutureBuilder<List<GetMaoObraRelatorioRow>>(
        future: SQLiteManager.instance.getMaoObraRelatorio(
          relatorioUuid: widget!.uuid!,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Text(
                'Não foi possível carregar a mão de obra. Feche e abra o relatório ou sincronize a obra.\n'
                '(${snapshot.error})',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: theme.error,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snapshot.data!;
          if (list.isEmpty) {
            return _buildEmptyState(theme, 'Nenhum trabalhador adicionado');
          }
          return ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = list[index];
              return Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.alternate.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.descricao ?? 'N/A',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if ((item.cargoFuncao ?? '').trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    (item.cargoFuncao ?? '').trim(),
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: theme.secondaryText,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: FaIcon(FontAwesomeIcons.trashAlt,
                              size: 14, color: theme.error),
                          tooltip: 'Excluir',
                          onPressed: () async {
                            await showDialog(
                              context: context,
                              builder: (ctx) => _rdoDialogWide(
                                CofirmaExclusaoMaoObraRelatorioWidget(
                                  uuid: item.uuid!,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    MaoObraPresencaControlsWidget(
                      key: Key('presenca_${item.uuid}'),
                      uuid: item.uuid!,
                      statusPresenca: item.statusPresenca,
                      motivoAusencia: item.motivoAusencia,
                      onSaved: () => safeSetState(() {}),
                    ),
                    const SizedBox(height: 8),
                    MaoObraHorariosFormWidget(
                      key: Key('mao_hor_${item.id}_${item.uuid}'),
                      uuid: item.uuid!,
                      horaEntrada: item.horaEntrada ?? '08:00',
                      intervaloInicio: item.intervaloInicio ?? '11:00',
                      intervaloFim: item.intervaloFim ?? '13:00',
                      horaSaida: item.horaSaida ?? '17:00',
                      relatorioEntradaManha:
                          data.firstOrNull?.entradaManha ?? '08:00',
                      relatorioSaidaTarde:
                          data.firstOrNull?.saidaTarde ?? '17:00',
                      motivoAtrasoColumn: item.motivoAtraso,
                      motivoSaidaCedo: item.motivoSaidaCedo,
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMateriaisCard(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return _buildSectionCard(
      theme: theme,
      title: 'Materiais Recebidos',
      secaoRecolherChave: _secMateriais,
      addTooltip: 'Adicionar material recebido',
      onAdd: () async {
        await showDialog(
          context: context,
          builder: (dialogContext) => _rdoDialogWide(
            AddMateriaisRecebidosRelatorioModalCopyWidget(
              uuid: widget!.uuid!,
              relatorioUuid: widget!.uuid!,
              obraUuid: data.firstOrNull!.obraUuid,
            ),
          ),
        );
      },
      child: MateriaisRecebidosRelatorioWidget(
        relatorioId: widget!.id ?? 1,
        relatorioUuid: widget!.uuid ?? '0',
      ),
    );
  }

  Widget _buildAtividadesCard(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return _buildSectionCard(
      theme: theme,
      title: 'Atividades Realizadas',
      secaoRecolherChave: _secAtividades,
      addTooltip: 'Adicionar atividade',
      onAdd: () async {
        if (data.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Dados do relatório não carregaram. Tente abrir a tela novamente.',
              ),
            ),
          );
          return;
        }
        final det = data.first;
        await showDialog(
          context: context,
          builder: (dialogContext) => Dialog(
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: AddRelatorioTipoDialogWidget(
              relatorioID: widget!.id!,
              obraId: det.obraId,
              relatorioUuid: det.uuid ?? widget!.uuid!,
              obraUuid: det.obraUuid,
            ),
          ),
        );
      },
      child: AtividadesRelatorioWidget(
        relatorioId: widget!.id!,
        relatorioUuid: widget!.uuid!,
        obraUuid: data.isNotEmpty ? data.first.obraUuid : null,
      ),
    );
  }

  Widget _buildCustosCard(
    FlutterFlowTheme theme,
    List<RelatorioDetalhesRow> data,
  ) {
    return _buildSectionCard(
      theme: theme,
      title: 'Ordens de Custo',
      secaoRecolherChave: _secCustos,
      addTooltip: 'Vincular ordem de serviço',
      onAdd: () async {
        await showDialog(
          context: context,
          builder: (dialogContext) => _rdoDialogWide(
            AddOrdensCustoRelatorioWidget(
              obraUuid: data.firstOrNull?.obraUuid,
              userUuid: FFAppState().creatorUuid,
              relatorioUuid: widget!.uuid!,
              uuid: data.firstOrNull?.uuid ?? widget!.uuid!,
            ),
          ),
        );
      },
      child: OrdensCustoRelatorioWidget(
        relatorioId: widget!.id!,
        relatorioUuid: widget!.uuid!,
      ),
    );
  }

  Widget _buildComentariosCard(FlutterFlowTheme theme) {
    final canCreate =
        MembershipAccess.canPermission('create_comentarios');
    return _buildSectionCard(
      theme: theme,
      title: 'Comentários',
      secaoRecolherChave: _secComentarios,
      addTooltip: 'Adicionar comentário',
      showAdd: canCreate,
      onAdd: () async {
        if (!MembershipAccess.canPermission('create_comentarios')) {
          MembershipAccess.showDenied(
            context,
            'Sem permissão para criar comentários.',
          );
          return;
        }
        await showDialog(
          context: context,
          builder: (dialogContext) => _rdoDialogWide(
            AddComentarioRelatorioModalWidget(
              relatorioId: widget!.id!,
              uuid: widget!.uuid!,
            ),
          ),
        );
      },
      child: ComentariosRelatorioWidget(
        relatorioId: widget!.id!,
        relatorioUuid: widget!.uuid!,
      ),
    );
  }

  Widget _buildOcorrenciasCard(FlutterFlowTheme theme) {
    final canCreate =
        MembershipAccess.canPermission('create_ocorrencias');
    return _buildSectionCard(
      theme: theme,
      title: 'Ocorrências',
      secaoRecolherChave: _secOcorrencias,
      addTooltip: 'Adicionar ocorrência',
      showAdd: canCreate,
      onAdd: () async {
        if (!MembershipAccess.canPermission('create_ocorrencias')) {
          MembershipAccess.showDenied(
            context,
            'Sem permissão para registrar ocorrências.',
          );
          return;
        }
        await showDialog(
          context: context,
          builder: (dialogContext) => _rdoDialogWide(
            AddOcorrenciaRelatorioModalWidget(
              relatorioId: widget!.id!,
              uuid: widget!.uuid!,
            ),
          ),
        );
      },
      child: OcorrenciasRelatorioWidget(
        relatoioId: widget!.id!,
        relatorioUuid: widget!.uuid!,
      ),
    );
  }

  Widget _buildAnexosCard(FlutterFlowTheme theme) {
    return _buildSectionCard(
      theme: theme,
      title: 'Anexos',
      secaoRecolherChave: _secAnexos,
      addTooltip: 'Adicionar anexo',
      onAdd: () async {
        await showDialog(
          context: context,
          builder: (dialogContext) => _rdoDialogWide(
            AddAnexoRelatorioWidget(
              relatorioId: widget!.id,
              relatorioUuid: widget!.uuid!,
            ),
          ),
        );
      },
      child: AnexosRelatoriosWidget(
        relatorioUuid: widget!.uuid!,
      ),
    );
  }

  Widget _buildEmptyState(FlutterFlowTheme theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: theme.secondaryText.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              message,
              style:
                  GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
            ),
          ],
        ),
      ),
    );
  }
}

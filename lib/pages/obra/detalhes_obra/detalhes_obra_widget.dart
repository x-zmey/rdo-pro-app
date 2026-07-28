import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/permission/permission_gate.dart';
import '/componentes/relatorios/relatorio_list_item_widget.dart';
import '/custom_code/actions/sync_push_runner.dart';
import '/flutter_flow/flutter_flow_animations.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'detalhes_obra_model.dart';
export 'detalhes_obra_model.dart';

/// Prazos do contrato (espelha `ObrasController::calcularPrazosObra`).
class _ObraHeaderExtras {
  const _ObraHeaderExtras({
    this.clienteNome,
    this.situacaoNome,
  });

  final String? clienteNome;
  final String? situacaoNome;
}

class _ObraPrazosInfo {
  const _ObraPrazosInfo({
    required this.valido,
    this.prazoContratual,
    this.prazoDecorrido = 0,
    this.prazoAVencer = 0,
    this.porcentagemDecorrida,
  });

  final bool valido;
  final int? prazoContratual;
  final int prazoDecorrido;
  final int prazoAVencer;
  final double? porcentagemDecorrida;
}

DateTime? _parseObraDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final s = raw.trim();
  var dt = DateTime.tryParse(s);
  if (dt != null) return DateTime(dt.year, dt.month, dt.day);
  if (s.length >= 10 && s[4] == '-' && s[7] == '-') {
    final p = s.substring(0, 10).split('-');
    if (p.length == 3) {
      final y = int.tryParse(p[0]);
      final m = int.tryParse(p[1]);
      final d = int.tryParse(p[2]);
      if (y != null && m != null && d != null) {
        return DateTime(y, m, d);
      }
    }
  }
  final br = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})');
  final match = br.firstMatch(s);
  if (match != null) {
    return DateTime(
      int.parse(match.group(3)!),
      int.parse(match.group(2)!),
      int.parse(match.group(1)!),
    );
  }
  return null;
}

_ObraPrazosInfo _calcularPrazosObra(String? dataInicioRaw, String? dataFinalRaw) {
  final inicio = _parseObraDate(dataInicioRaw);
  final fim = _parseObraDate(dataFinalRaw);
  if (inicio == null || fim == null) {
    return const _ObraPrazosInfo(valido: false);
  }
  final hoje = DateTime.now();
  final today = DateTime(hoje.year, hoje.month, hoje.day);
  final prazoContratual = fim.difference(inicio).inDays;
  var decorrido = today.difference(inicio).inDays;
  if (decorrido < 0) decorrido = 0;
  var aVencer = fim.difference(today).inDays;
  if (today.isAfter(fim)) {
    aVencer = -today.difference(fim).inDays;
  }
  final pct = prazoContratual > 0
      ? ((decorrido / prazoContratual) * 100).clamp(0.0, 100.0)
      : 100.0;
  return _ObraPrazosInfo(
    valido: true,
    prazoContratual: prazoContratual,
    prazoDecorrido: decorrido,
    prazoAVencer: aVencer,
    porcentagemDecorrida: pct,
  );
}

String _labelPrazoAVencer(int dias) {
  if (dias < 0) return '${dias.abs()} d de atraso';
  if (dias == 0) return 'Vence hoje';
  if (dias == 1) return '1 d restante';
  return '$dias d restantes';
}

/// crie para mim uma pagina de detalhes de obra, essa pagina é para vai
/// aparecer todas informações de uma obra, tipo nome, uma listagem de
/// relatorio rdo essa listagem vai aparecer os ultimos 10, cada item da
/// listagem vai ter um numero, uma data, um status se é aprovado, preenchendo
/// ou aguardando aprovação, quero um contador tbm para qts atividades tem
/// nele, qts insumos, equipamentos e mão de obra utilizados tbm o nome de
/// quem preencheu o relatorio e botões de visualizar, editar e apagar
/// relatorio, alem da listagem no topo da página preciso de alguns botoes de
/// atalho com icones, sendo eles: equipamentos, tarefas, ocorrencias,
/// comentários, anexos, insumos, mão de obra e locais, tbm preciso no rodapé
/// um menu flutuante para colocar um botão destacado de adicionar relatório,
/// esse aplicativo que estou fazendo é para um sistema de rdo de obras, tbm
/// pode colocar contadores de quantidade de relatórios, tarefas, ocorrencias
/// e comentarios.
class DetalhesObraWidget extends StatefulWidget {
  const DetalhesObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'detalhesObra';
  static String routePath = '/detalhesObra';

  @override
  State<DetalhesObraWidget> createState() => _DetalhesObraWidgetState();
}

class _DetalhesObraWidgetState extends State<DetalhesObraWidget>
    with TickerProviderStateMixin {
  late DetalhesObraModel _model;
  late final AnimationController _shimmerController;
  Future<List<RelatoriosObraUltimosRow>>? _ultimosRelatoriosFuture;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<List<RelatoriosObraUltimosRow>> _relatoriosFutureOrFetch() {
    return _ultimosRelatoriosFuture ??= _fetchUltimosRelatorios();
  }

  Future<List<RelatoriosObraUltimosRow>> _fetchUltimosRelatorios() {
    return SQLiteManager.instance.relatoriosObraUltimos(
      obraUuid: widget.obraUuid!,
      accountOwnerUuid: FFAppState().creatorUuid,
    );
  }

  Future<void> _reloadObraFromSqlite() async {
    _model.obraDetalhes = await SQLiteManager.instance.obraDetalhes(
      uuid: widget.obraUuid!,
      userId: FFAppState().creatorId,
      accountOwnerUuid: FFAppState().creatorUuid,
    );
    _model.idServidorResult = await SQLiteManager.instance.getIdServidor(
      tabela: 'obras',
      uuid: _model.obraDetalhes?.firstOrNull?.uuid,
    );
    _model.idServe = _model.idServidorResult?.firstOrNull?.idServidor;
    _ultimosRelatoriosFuture = _fetchUltimosRelatorios();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DetalhesObraModel());
    _ultimosRelatoriosFuture = _fetchUltimosRelatorios();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();

    // On page load: dados locais primeiro; depois sync completo (igual ao início) e recarga.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _reloadObraFromSqlite();
      if (!mounted) return;
      safeSetState(() {});

      try {
        await runFullSyncPipelineFromPush();
      } catch (e) {
        debugPrint('Erro no sync (detalhes obra): $e');
      }
      if (!mounted) return;
      await _reloadObraFromSqlite();
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _model.dispose();

    super.dispose();
  }

  Widget _buildUltimosRelatoriosShimmer(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(top: index == 0 ? 0 : 6),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).secondaryBackground,
              borderRadius: BorderRadius.circular(14.0),
              border: Border.all(
                color: FlutterFlowTheme.of(context)
                    .primaryText
                    .withValues(alpha: 0.06),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _shimmerBox(context, width: 110, height: 12),
                  const SizedBox(height: 6),
                  _shimmerBox(context, width: 80, height: 9),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: _shimmerBox(context, width: 88, height: 18, radius: 10),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildUltimosRelatoriosColumn(
    BuildContext context,
    List<RelatoriosObraUltimosRow> rows,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 5),
          Builder(
            builder: (ctx) {
              final row = rows[i];
              final dataExec =
                  formatDataResumoRelatorio(row.dataExecutado);
              final dataLabel =
                  dataExec.isNotEmpty ? dataExec : row.dataExecutado;
              final criador =
                  (row.criadorNome ?? row.criador ?? '').trim();

              return RelatorioListItemWidget(
                numero: row.numero,
                dataLabel: dataLabel,
                statusId: row.statusId,
                statusLabel: labelRelatorioStatus(
                  statusId: row.statusId,
                  statusNome: row.statusNome,
                ),
                criador: criador.isNotEmpty ? criador : null,
                onTap: () {
                  ctx.pushNamed(
                    RelatorioDetalhesWidget.routeName,
                    queryParameters: {
                      'id': serializeParam(row.id, ParamType.int),
                      'uuid': serializeParam(row.uuid, ParamType.String),
                    }.withoutNulls,
                  );
                },
                onVisualizar: () {
                  ctx.pushNamed(
                    RelatorioDetalhesWidget.routeName,
                    queryParameters: {
                      'id': serializeParam(row.id, ParamType.int),
                      'uuid': serializeParam(row.uuid, ParamType.String),
                    }.withoutNulls,
                  );
                },
                onEditar: () {
                  runWithPermission(
                    ctx,
                    permission: 'generate_rdo',
                    onAllowed: () {
                      ctx.pushNamed(
                        ObraAddRelatorioWidget.routeName,
                        queryParameters: {
                          'id': serializeParam(row.id, ParamType.int),
                          'uuid': serializeParam(row.uuid, ParamType.String),
                        }.withoutNulls,
                        extra: <String, dynamic>{
                          '__transition_info__': TransitionInfo(
                            hasTransition: true,
                            transitionType: PageTransitionType.rightToLeft,
                          ),
                        },
                      );
                    },
                  );
                },
                onApagar: () async {
                  final theme = FlutterFlowTheme.of(ctx);
                  final confirmar = await showDialog<bool>(
                    context: ctx,
                    builder: (dialogCtx) => AlertDialog(
                      title: const Text('Apagar relatório'),
                      content: const Text(
                        'Deseja apagar este relatório? Esta ação será um soft delete.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(dialogCtx).pop(true),
                          child: const Text('Apagar'),
                        ),
                      ],
                    ),
                  );

                  if (confirmar != true) return;

                  await SQLiteManager.instance.softDeleteRelatorio(
                    uuid: row.uuid,
                  );
                  if (!mounted) return;

                  _ultimosRelatoriosFuture = _fetchUltimosRelatorios();
                  setState(() {});

                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Relatório apagado.',
                        style: TextStyle(color: theme.alternate),
                      ),
                      duration: const Duration(milliseconds: 3000),
                      backgroundColor: theme.secondary,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ],
    );
  }

  /// Atalhos: mesma paleta do card de detalhes da obra (gradiente primary).
  Widget _buildAtalhoCelula(
    BuildContext context, {
    required VoidCallback onTap,
    required IconData icon,
    required String label,
    String? permission,
    List<String>? permissions,
  }) {
    final t = FlutterFlowTheme.of(context);
    final allowed = MembershipAccess.canShowMenuItem(
      permission: permission,
      permissions: permissions,
    );
    final gradientEnd =
        Color.lerp(t.primary, Colors.black, 0.2) ?? t.primary;
    final cell = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => runWithPermission(
          context,
          permission: permission,
          permissions: permissions,
          onAllowed: onTap,
        ),
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [t.primary, gradientEnd],
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  allowed ? icon : Icons.lock_outline,
                  color: t.info,
                  size: 17,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSmall.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    color: t.info,
                    fontSize: 9,
                    lineHeight: 1.05,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (allowed) return cell;
    return Opacity(opacity: 0.45, child: cell);
  }

  Widget _shimmerBox(
    BuildContext context, {
    double? width,
    required double height,
    double radius = 6.0,
  }) {
    final t = FlutterFlowTheme.of(context);
    final base = t.alternate.withValues(alpha: 0.34);
    final highlight = t.alternate.withValues(alpha: 0.22);
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, _) {
        final v = _shimmerController.value;
        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(-1.1 + (2.2 * v), -0.10),
              end: Alignment(1.1 + (2.2 * v), 0.10),
              colors: [base, highlight, base],
              stops: const [0.18, 0.5, 0.82],
            ),
          ),
        );
      },
    );
  }

  String _formatDataResumo(String? raw) => formatDataResumoRelatorio(raw);

  String _obraCidadeUf(ObraDetalhesRow? o) {
    if (o == null) return '';
    final c = o.cidade?.trim();
    final e = (o.estado ?? '').trim();
    final uf = e.length >= 2 ? e.substring(0, 2).toUpperCase() : e;
    if ((c ?? '').isNotEmpty && uf.isNotEmpty) return '$c · $uf';
    if ((c ?? '').isNotEmpty) return c!;
    if (uf.isNotEmpty) return uf;
    return '';
  }

  String _obraEnderecoLinha(ObraDetalhesRow? o) {
    if (o == null) return '';
    final parts = <String>[];
    final rua = o.rua?.trim();
    final num = o.numero?.trim();
    if (rua != null && rua.isNotEmpty) {
      parts.add(num != null && num.isNotEmpty ? '$rua, $num' : rua);
    }
    final b = o.bairro?.trim();
    if (b != null && b.isNotEmpty) parts.add(b);
    return parts.join(' · ');
  }

  Future<void> _abrirEditarObra() async {
    if (!MembershipAccess.canPermission('edit_obras')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar obras.',
      );
      return;
    }
    await context.pushNamed(
      EditarObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(
          widget.obraId,
          ParamType.int,
        ),
        'obraUuid': serializeParam(
          widget.obraUuid,
          ParamType.String,
        ),
      }.withoutNulls,
    );
    if (mounted) safeSetState(() {});
  }

  Future<String?> _nomeClienteObra(ObraDetalhesRow? obra) async {
    final uuid = obra?.clienteUuid?.trim() ?? '';
    if (uuid.isEmpty) return null;
    final owner = FFAppState().creatorUuid.trim();
    if (owner.isEmpty) return null;
    final list = await SQLiteManager.instance.getClientes(userUuid: owner);
    for (final c in list) {
      if (c.uuid == uuid) return c.nome.trim();
    }
    return null;
  }

  Future<_ObraHeaderExtras> _loadHeaderExtras(ObraDetalhesRow? obra) async {
    final cliente = await _nomeClienteObra(obra);
    String? situacao;
    final sitId = obra?.situacaoId;
    if (sitId != null && sitId > 0) {
      final rows = await SQLiteManager.instance.situacaoObra(id: sitId);
      final n = rows.firstOrNull?.nome?.trim();
      if (n != null && n.isNotEmpty) situacao = n;
    }
    return _ObraHeaderExtras(clienteNome: cliente, situacaoNome: situacao);
  }

  Widget _headerMetricBox(
    BuildContext context, {
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.labelSmall.override(
                font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                color: theme.info.withValues(alpha: 0.85),
                fontSize: 10,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.labelMedium.override(
                font: GoogleFonts.interTight(fontWeight: FontWeight.w800),
                color: valueColor ?? theme.info,
                fontSize: 13,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _headerDetailLine(
    BuildContext context, {
    required IconData icon,
    required String text,
    bool expanded = false,
  }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);
    final line = Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              icon,
              size: 13,
              color: theme.info.withValues(alpha: 0.88),
            ),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall.override(
                font: GoogleFonts.inter(),
                color: theme.info.withValues(alpha: 0.92),
                fontSize: 11,
                lineHeight: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
    return expanded ? Expanded(child: line) : line;
  }

  Widget _headerContratoPeriodoLine(
    BuildContext context, {
    required String contrato,
    required String textoPeriodo,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final parts = <String>[];
    if (contrato.trim().isNotEmpty) {
      parts.add('Contrato: ${contrato.trim()}');
    }
    if (textoPeriodo.trim().isNotEmpty) {
      parts.add(textoPeriodo.trim());
    }
    if (parts.isEmpty) return const SizedBox.shrink();

    final icon = contrato.trim().isNotEmpty
        ? Icons.description_outlined
        : Icons.date_range_outlined;

    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 13, color: theme.info.withValues(alpha: 0.88)),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              parts.join(' · '),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: theme.bodySmall.override(
                font: GoogleFonts.inter(),
                color: theme.info.withValues(alpha: 0.92),
                fontSize: 11,
                lineHeight: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return FutureBuilder<List<ObraDetalhesRow>>(
      future: SQLiteManager.instance.obraDetalhes(
        uuid: widget.obraUuid!,
        userId: FFAppState().creatorId,
        accountOwnerUuid: FFAppState().creatorUuid,
      ),
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
        final detalhesObraObraDetalhesRowList = snapshot.data!;
        final bottomInset = MediaQuery.paddingOf(context).bottom;

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      bottom:
                          kBarraNavegacaoPrincipalReservaScroll + bottomInset,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Builder(
                          builder: (context) {
                            final obra =
                                detalhesObraObraDetalhesRowList.firstOrNull;
                            final theme = FlutterFlowTheme.of(context);
                            final topPad = MediaQuery.paddingOf(context).top;
                            final cidadeUf = _obraCidadeUf(obra);
                            final endereco = _obraEnderecoLinha(obra);
                            final localLinha = [
                              if (cidadeUf.isNotEmpty) cidadeUf,
                              if (endereco.isNotEmpty) endereco,
                            ].join(' · ');
                            final di = _formatDataResumo(obra?.dataInicio);
                            final df = _formatDataResumo(obra?.dataFinal);
                            final contrato = (obra?.contrato ?? '').trim();
                            final prazos = _calcularPrazosObra(
                              obra?.dataInicio,
                              obra?.dataFinal,
                            );
                            final corPrazo = prazos.valido
                                ? (prazos.prazoAVencer < 0
                                    ? theme.error
                                    : prazos.prazoAVencer < 7
                                        ? theme.warning
                                        : theme.success)
                                : theme.info;

                            return FutureBuilder<_ObraHeaderExtras>(
                              future: _loadHeaderExtras(obra),
                              builder: (context, snapExtras) {
                                final extras = snapExtras.data;
                                final nomeCliente =
                                    extras?.clienteNome?.trim() ?? '';
                                final nomeSit =
                                    extras?.situacaoNome?.trim() ?? '';
                                final showMetricRow = prazos.valido ||
                                    nomeSit.isNotEmpty;
                                final temPeriodo =
                                    di.isNotEmpty || df.isNotEmpty;
                                final textoPeriodo = di.isNotEmpty &&
                                        df.isNotEmpty
                                    ? 'Período: $di — $df'
                                    : (di.isNotEmpty
                                        ? 'Início: $di'
                                        : 'Fim: $df');

                                return Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    16,
                                    topPad + 8,
                                    16,
                                    8,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            theme.primary,
                                            Color.lerp(
                                                  theme.primary,
                                                  Colors.black,
                                                  0.2,
                                                ) ??
                                                theme.primary,
                                          ],
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          11,
                                          9,
                                          9,
                                          10,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    valueOrDefault<String>(
                                                      obra?.nome,
                                                      'Obra',
                                                    ),
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: theme.titleLarge
                                                        .override(
                                                      font: GoogleFonts
                                                          .interTight(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                      ),
                                                      color: theme.info,
                                                      fontSize: (theme
                                                                  .titleLarge
                                                                  .fontSize ??
                                                              22) *
                                                          0.88,
                                                      lineHeight: 1.15,
                                                      letterSpacing: -0.2,
                                                    ),
                                                  ),
                                                ),
                                                if (MembershipAccess
                                                    .canPermission(
                                                        'edit_obras'))
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      onTap: _abrirEditarObra,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5),
                                                        child: Icon(
                                                          Icons.edit_outlined,
                                                          size: 17,
                                                          color: theme.info,
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                else
                                                  Material(
                                                    color: Colors.transparent,
                                                    child: InkWell(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      onTap: _abrirEditarObra,
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets
                                                                .all(5),
                                                        child: Icon(
                                                          Icons.lock_outline,
                                                          size: 17,
                                                          color: theme.info
                                                              .withValues(
                                                                  alpha: 0.55),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                            if (showMetricRow) ...[
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  if (prazos.valido) ...[
                                                    _headerMetricBox(
                                                      context,
                                                      label: 'Prazo decorrido',
                                                      value:
                                                          '${prazos.prazoDecorrido} d',
                                                    ),
                                                    const SizedBox(width: 5),
                                                    _headerMetricBox(
                                                      context,
                                                      label: 'Dias restantes',
                                                      value: _labelPrazoAVencer(
                                                        prazos.prazoAVencer,
                                                      ),
                                                      valueColor: corPrazo,
                                                    ),
                                                  ],
                                                  if (nomeSit.isNotEmpty) ...[
                                                    if (prazos.valido)
                                                      const SizedBox(width: 5),
                                                    _headerMetricBox(
                                                      context,
                                                      label: 'Situação',
                                                      value: nomeSit,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                            if (prazos.valido &&
                                                prazos.porcentagemDecorrida !=
                                                    null) ...[
                                              const SizedBox(height: 5),
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                child: LinearProgressIndicator(
                                                  value: (prazos
                                                              .porcentagemDecorrida! /
                                                          100)
                                                      .clamp(0.0, 1.0),
                                                  minHeight: 3,
                                                  backgroundColor: Colors.white
                                                      .withValues(alpha: 0.2),
                                                  color: theme.info,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${prazos.porcentagemDecorrida!.toStringAsFixed(0)}% do prazo contratual'
                                                '${prazos.prazoContratual != null ? ' (${prazos.prazoContratual} d)' : ''}',
                                                style:
                                                    theme.labelSmall.override(
                                                  font: GoogleFonts.inter(),
                                                  color: theme.info
                                                      .withValues(alpha: 0.8),
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                            ],
                                            if (nomeCliente.isNotEmpty ||
                                                localLinha.isNotEmpty ||
                                                contrato.isNotEmpty ||
                                                temPeriodo) ...[
                                              const SizedBox(height: 7),
                                              if (nomeCliente.isNotEmpty)
                                                _headerDetailLine(
                                                  context,
                                                  icon: Icons.business_outlined,
                                                  text:
                                                      'Cliente: $nomeCliente',
                                                ),
                                              if (localLinha.isNotEmpty)
                                                _headerDetailLine(
                                                  context,
                                                  icon: Icons.place_outlined,
                                                  text: localLinha,
                                                ),
                                              if (contrato.isNotEmpty ||
                                                  temPeriodo)
                                                _headerContratoPeriodoLine(
                                                  context,
                                                  contrato: contrato,
                                                  textoPeriodo: textoPeriodo,
                                                ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                        FutureBuilder<List<GetIdServidorRow>>(
                          future: SQLiteManager.instance.getIdServidor(
                            tabela: 'obras',
                            uuid: detalhesObraObraDetalhesRowList
                                .firstOrNull?.uuid,
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
                            final containerGetIdServidorRowList =
                                snapshot.data!;

                            return Container(
                              width: double.infinity,
                              decoration: const BoxDecoration(),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    16, 6, 16, 0),
                                child: GridView(
                                  padding: EdgeInsets.zero,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    crossAxisSpacing: 6,
                                    mainAxisSpacing: 6,
                                    childAspectRatio: 1.42,
                                  ),
                                  primary: false,
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  children: [
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.construction,
                                      label: "Equipamentos",
                                      permission: 'view_equipamentos',
                                      onTap: () async {
                                        context.pushNamed(
                                          EquipamentosObraWidget.routeName,
                                          queryParameters: {
                                            "obraId": serializeParam(
                                              containerGetIdServidorRowList
                                                  .firstOrNull?.idServidor,
                                              ParamType.int,
                                            ),
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                          extra: <String, dynamic>{
                                            "__transition_info__":
                                                TransitionInfo(
                                              hasTransition: true,
                                              transitionType: PageTransitionType
                                                  .bottomToTop,
                                            ),
                                          },
                                        );
                                      },
                                    ),
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.assignment,
                                      label: "Tarefas",
                                      permission: 'view_tarefas',
                                      onTap: () async {
                                        context.pushNamed(
                                          ObraTarefasWidget.routeName,
                                          queryParameters: {
                                            "obraId": serializeParam(
                                              containerGetIdServidorRowList
                                                  .firstOrNull?.idServidor,
                                              ParamType.int,
                                            ),
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                          extra: <String, dynamic>{
                                            "__transition_info__":
                                                TransitionInfo(
                                              hasTransition: true,
                                              transitionType: PageTransitionType
                                                  .bottomToTop,
                                            ),
                                          },
                                        );
                                      },
                                    ),
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.warning,
                                      label: "Ocorrências",
                                      permission: 'view_ocorrencias',
                                      onTap: () async {
                                        context.pushNamed(
                                          OcorrenciasObraWidget.routeName,
                                          queryParameters: {
                                            "obraId": serializeParam(
                                              containerGetIdServidorRowList
                                                  .firstOrNull?.idServidor,
                                              ParamType.int,
                                            ),
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                        );
                                      },
                                    ),
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.comment,
                                      label: "Comentários",
                                      permission: 'view_comentarios',
                                      onTap: () async {
                                        context.pushNamed(
                                          ComentariosObraNovoWidget.routeName,
                                          queryParameters: {
                                            "obraId": serializeParam(
                                              containerGetIdServidorRowList
                                                  .firstOrNull?.idServidor,
                                              ParamType.int,
                                            ),
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                        );
                                      },
                                    ),
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.place_rounded,
                                      label: "Locais",
                                      permission: 'view_cadastros_gerais',
                                      onTap: () async {
                                        context.pushNamed(
                                          LocaisObraWidget.routeName,
                                          queryParameters: {
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                          extra: <String, dynamic>{
                                            "__transition_info__":
                                                TransitionInfo(
                                              hasTransition: true,
                                              transitionType: PageTransitionType
                                                  .bottomToTop,
                                            ),
                                          },
                                        );
                                      },
                                    ),
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.inventory,
                                      label: "Insumos",
                                      permission: 'view_insumos',
                                      onTap: () async {
                                        context.pushNamed(
                                          InsumosObraWidget.routeName,
                                          queryParameters: {
                                            "obraId": serializeParam(
                                              containerGetIdServidorRowList
                                                  .firstOrNull?.idServidor,
                                              ParamType.int,
                                            ),
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                          extra: <String, dynamic>{
                                            "__transition_info__":
                                                TransitionInfo(
                                              hasTransition: true,
                                              transitionType: PageTransitionType
                                                  .bottomToTop,
                                            ),
                                          },
                                        );
                                      },
                                    ),
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.groups,
                                      label: "Mão de Obra",
                                      permission: 'view_mao_obra',
                                      onTap: () async {
                                        context.pushNamed(
                                          MaoObraWidget.routeName,
                                          queryParameters: {
                                            "obraId": serializeParam(
                                              containerGetIdServidorRowList
                                                  .firstOrNull?.idServidor,
                                              ParamType.int,
                                            ),
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                          extra: <String, dynamic>{
                                            "__transition_info__":
                                                TransitionInfo(
                                              hasTransition: true,
                                              transitionType: PageTransitionType
                                                  .bottomToTop,
                                            ),
                                          },
                                        );
                                      },
                                    ),
                                    _buildAtalhoCelula(
                                      context,
                                      icon: Icons.post_add,
                                      label: "Ordens de Serviço",
                                      permission: 'view_ordens_servico',
                                      onTap: () async {
                                        context.pushNamed(
                                          OrdensServicoObraWidget.routeName,
                                          queryParameters: {
                                            "obraId": serializeParam(
                                              containerGetIdServidorRowList
                                                  .firstOrNull?.idServidor,
                                              ParamType.int,
                                            ),
                                            "obraUuid": serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                          extra: <String, dynamic>{
                                            "__transition_info__":
                                                TransitionInfo(
                                              hasTransition: true,
                                              transitionType: PageTransitionType
                                                  .bottomToTop,
                                            ),
                                          },
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Últimos relatórios',
                                    style: FlutterFlowTheme.of(context)
                                        .titleSmall
                                        .override(
                                      font: GoogleFonts.interTight(
                                        fontWeight: FontWeight.w700,
                                      ),
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () => runWithPermission(
                                      context,
                                      permissions: const [
                                        'view_relatorios_gerais',
                                        'generate_rdo',
                                      ],
                                      onAllowed: () {
                                        context.pushNamed(
                                          RelatoriosObraWidget.routeName,
                                          queryParameters: {
                                            'obraId': serializeParam(
                                              widget!.obraId,
                                              ParamType.int,
                                            ),
                                            'obraUuid': serializeParam(
                                              widget!.obraUuid,
                                              ParamType.String,
                                            ),
                                          }.withoutNulls,
                                          extra: <String, dynamic>{
                                            '__transition_info__':
                                                TransitionInfo(
                                              hasTransition: true,
                                              transitionType: PageTransitionType
                                                  .bottomToTop,
                                            ),
                                          },
                                        );
                                      },
                                    ),
                                    child: Text(
                                      'Ver todos',
                                      style: FlutterFlowTheme.of(context)
                                          .labelMedium
                                          .override(
                                        font: GoogleFonts.inter(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        color: FlutterFlowTheme.of(context)
                                            .primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FutureBuilder<
                                    List<RelatoriosObraUltimosRow>>(
                                  future: _relatoriosFutureOrFetch(),
                                  builder: (context, snapshot) {
                                    if (!snapshot.hasData) {
                                      return _buildUltimosRelatoriosShimmer(
                                          context);
                                    }
                                    return _buildUltimosRelatoriosColumn(
                                      context,
                                      snapshot.data!,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
      },
    );
  }
}

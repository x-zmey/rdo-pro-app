import '/auth/apply_membership_auth.dart';
import '/auth/fetch_allowed_obras.dart';
import '/auth/membership_access.dart';
import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/custom_code/actions/sync_push_runner.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/componentes/tenant_switcher/tenant_switcher_widget.dart';
import '/index.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'inicio_model.dart';
export 'inicio_model.dart';

class _InicioPayload {
  _InicioPayload(this.obras, this.situacoes);

  final List<CarregaObrasRow> obras;
  final List<SituacaoObraRow> situacoes;
}

/// Início: obras do usuário com busca, filtro por situação e cartões informativos.
class InicioWidget extends StatefulWidget {
  const InicioWidget({super.key});

  static String routeName = 'Inicio';
  static String routePath = '/inicio';

  @override
  State<InicioWidget> createState() => _InicioWidgetState();
}

class _InicioWidgetState extends State<InicioWidget> {
  /// Altura compartilhada do filtro de situação e do campo de busca.
  static const double _filtroRowHeight = 40.0;

  late InicioModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Future<_InicioPayload>? _payloadFuture;
  int? _filtroSituacaoId;
  int _lastTenantContextVersion = 0;
  bool _tenantRefreshRunning = false;

  Future<_InicioPayload> _carregarPayload() async {
    final obras = await loadAccessibleObras();
    final situacoes = await SQLiteManager.instance.listaSituacaoObras();
    return _InicioPayload(obras, situacoes);
  }

  void _recarregarLista() {
    setState(() {
      _payloadFuture = _carregarPayload();
    });
  }

  Future<void> _runSyncAndReload() async {
    if (_tenantRefreshRunning) return;
    _tenantRefreshRunning = true;
    try {
      await runFullSyncPipelineFromPush();
    } catch (e) {
      debugPrint('Erro no sync: $e');
    } finally {
      _tenantRefreshRunning = false;
      if (mounted) _recarregarLista();
    }
  }

  void _onTenantContextChanged() {
    final v = FFAppState().tenantContextVersion;
    if (v == _lastTenantContextVersion) return;
    _lastTenantContextVersion = v;
    _recarregarLista();
    unawaited(_runSyncAndReload());
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InicioModel());
    _lastTenantContextVersion = FFAppState().tenantContextVersion;
    FFAppState().addListener(_onTenantContextChanged);
    _payloadFuture = _carregarPayload();
    _model.textControllerBusca?.addListener(() => setState(() {}));

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await refreshSessionFromServer();
      await refreshAppStatePermissoesFromSqlite();
      await refreshAllowedObraIdsIfNeeded();
      // Atualiza lista cedo (permissões/vínculos) sem esperar o sync completo.
      if (mounted) _recarregarLista();
      await _runSyncAndReload();
    });
  }

  @override
  void dispose() {
    FFAppState().removeListener(_onTenantContextChanged);
    _model.dispose();
    super.dispose();
  }

  String _str(String? s) => (s ?? '').trim();

  String _formatDataCurta(String? raw) {
    final s = _str(raw);
    if (s.isEmpty) return '';
    var dt = DateTime.tryParse(s);
    if (dt == null && s.contains(' ') && !s.contains('T')) {
      dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }
    if (dt == null) {
      if (s.length >= 10) return s.substring(0, 10);
      return s;
    }
    return dateTimeFormat('dd/MM/yyyy', dt.toLocal(), locale: 'pt_BR');
  }

  String _enderecoResumido(CarregaObrasRow r) {
    final parts = <String>[
      _str(r.rua),
      _str(r.numero),
      _str(r.bairro),
    ].where((e) => e.isNotEmpty).join(', ');
    final cidadeUf = [
      _str(r.cidade),
      _str(r.estado),
    ].where((e) => e.isNotEmpty).join('/');
    if (parts.isEmpty && cidadeUf.isEmpty) return 'Endereço não informado';
    if (parts.isEmpty) return cidadeUf;
    if (cidadeUf.isEmpty) return parts;
    return '$parts · $cidadeUf';
  }

  String _nomeSituacao(CarregaObrasRow r, List<SituacaoObraRow> situacoes) {
    final id = r.situacaoId;
    if (id == null) return 'Situação não informada';
    for (final s in situacoes) {
      if (s.id == id) {
        final n = _str(s.nome);
        if (n.isNotEmpty) return n;
      }
    }
    return 'Situação #$id';
  }

  Color _corSituacaoAccent(BuildContext context, int? situacaoId) {
    final primary = FlutterFlowTheme.of(context).primary;
    if (situacaoId == null || situacaoId <= 0) return primary;
    final hues = <double>[158, 200, 32, 280, 12, 210];
    final h = hues[situacaoId.abs() % hues.length];
    return HSLColor.fromAHSL(1, h, 0.55, 0.45).toColor();
  }

  List<CarregaObrasRow> _filtrarObras(List<CarregaObrasRow> todas) {
    final q = _model.textControllerBusca?.text.trim().toLowerCase() ?? '';
    return todas.where((r) {
      if (_filtroSituacaoId != null && r.situacaoId != _filtroSituacaoId) {
        return false;
      }
      if (q.isEmpty) return true;
      final blob = [
        r.nome,
        r.cidade,
        r.estado,
        r.contrato,
        r.rua,
        r.bairro,
        r.engenheiro,
      ].map((e) => e?.toString().toLowerCase() ?? '').join(' ');
      return blob.contains(q);
    }).toList();
  }

  String _labelFiltroSituacao(List<SituacaoObraRow> situacoes) {
    if (_filtroSituacaoId == null) return 'Todas';
    for (final s in situacoes) {
      if (s.id == _filtroSituacaoId) {
        final nome = _str(s.nome);
        return nome.isEmpty ? 'Situação #${s.id}' : nome;
      }
    }
    return 'Situação #$_filtroSituacaoId';
  }

  Widget _statusFilterDropdown({
    required BuildContext context,
    required List<SituacaoObraRow> situacoes,
  }) {
    final t = FlutterFlowTheme.of(context);
    final selectedAccent = _corSituacaoAccent(context, _filtroSituacaoId);
    final hasSpecificStatus = _filtroSituacaoId != null;
    return PopupMenuButton<int?>(
      tooltip: 'Filtrar por status',
      onSelected: (value) => setState(() => _filtroSituacaoId = value),
      itemBuilder: (_) => <PopupMenuEntry<int?>>[
        PopupMenuItem<int?>(
          value: null,
          child: Row(
            children: [
              Icon(
                Icons.layers_clear_rounded,
                size: 18,
                color: _filtroSituacaoId == null ? t.primary : t.secondaryText,
              ),
              const SizedBox(width: 8),
              Text(
                'Todas',
                style: t.bodyMedium.override(
                  font: GoogleFonts.inter(),
                  fontWeight: _filtroSituacaoId == null ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        ...situacoes.where((s) => s.id != null).map((s) {
          final id = s.id!;
          final nome = _str(s.nome).isEmpty ? 'Situação #$id' : _str(s.nome);
          final selected = _filtroSituacaoId == id;
          return PopupMenuItem<int?>(
            value: id,
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _corSituacaoAccent(context, id),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    nome,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyMedium.override(
                      font: GoogleFonts.inter(),
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
      child: Container(
        height: _filtroRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.secondaryBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasSpecificStatus
                ? selectedAccent.withValues(alpha: 0.45)
                : Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: hasSpecificStatus ? 1.2 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: selectedAccent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.flag_rounded, size: 11, color: selectedAccent),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 98),
              child: Text(
                _labelFiltroSituacao(situacoes),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall.override(
                  font: GoogleFonts.inter(),
                  fontWeight: FontWeight.w700,
                  color: t.primaryText,
                  fontSize: (t.bodySmall.fontSize ?? 14.0) * 0.93,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 17, color: t.secondaryText),
          ],
        ),
      ),
    );
  }

  Widget _obraCard({
    required BuildContext context,
    required CarregaObrasRow r,
    required List<SituacaoObraRow> situacoes,
  }) {
    final t = FlutterFlowTheme.of(context);
    final accent = _corSituacaoAccent(context, r.situacaoId);
    final situacaoNome = _nomeSituacao(r, situacoes);
    final di = _formatDataCurta(r.dataInicio);
    final df = _formatDataCurta(r.dataFinal);
    String periodo;
    if (di.isEmpty && df.isEmpty) {
      periodo = 'Prazo não informado';
    } else if (df.isEmpty) {
      periodo = 'Início $di';
    } else if (di.isEmpty) {
      periodo = 'Até $df';
    } else {
      periodo = '$di → $df';
    }

    final obraTitleSize = (t.titleMedium.fontSize ?? 18.0) * 0.85;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            final obraId = r.id;
            if (!MembershipAccess.canAccessObra(obraId)) {
              MembershipAccess.showDenied(
                context,
                'Você não tem acesso a esta obra.',
              );
              return;
            }
            context.pushNamed(
              DetalhesObraWidget.routeName,
              queryParameters: {
                'obraId': serializeParam(r.id, ParamType.int),
                'obraUuid': serializeParam(r.uuid, ParamType.String),
              }.withoutNulls,
              extra: <String, dynamic>{
                '__transition_info__': const TransitionInfo(
                  hasTransition: true,
                  transitionType: PageTransitionType.bottomToTop,
                ),
              },
            );
          },
          child: Ink(
            decoration: BoxDecoration(
              color: t.secondaryBackground,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(13),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.domain_rounded, size: 17, color: accent),
                              const SizedBox(width: 7),
                              Expanded(
                                child: Text(
                                  r.nome,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: t.titleMedium.override(
                                    font: GoogleFonts.interTight(fontWeight: FontWeight.w700),
                                    letterSpacing: 0,
                                    fontWeight: FontWeight.w700,
                                    fontSize: obraTitleSize,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                color: t.secondaryText,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _enderecoResumido(r),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodySmall.override(
                              font: GoogleFonts.inter(),
                              color: t.secondaryText,
                              letterSpacing: 0,
                              fontSize: (t.bodySmall.fontSize ?? 14.0) * 0.92,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: [
                              _infoChip(
                                context,
                                Icons.flag_outlined,
                                situacaoNome,
                                accent.withValues(alpha: 0.14),
                                accent,
                              ),
                              _infoChip(
                                context,
                                Icons.date_range_rounded,
                                periodo,
                                t.alternate.withValues(alpha: 0.65),
                                t.primaryText,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoChip(
    BuildContext context,
    IconData icon,
    String text,
    Color bg,
    Color fg,
  ) {
    final t = FlutterFlowTheme.of(context);
    final chipFontSize = (t.labelSmall.fontSize ?? 12.0) * 0.88;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg.withValues(alpha: 0.9)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.labelSmall.override(
                font: GoogleFonts.inter(),
                color: fg,
                letterSpacing: 0,
                fontWeight: FontWeight.w600,
                fontSize: chipFontSize,
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
    final t = FlutterFlowTheme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: t.primaryBackground,
        appBar: AppBar(
          backgroundColor: t.primaryBackground,
          automaticallyImplyLeading: false,
          elevation: 0,
          toolbarHeight: 72,
          titleSpacing: 16,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Obras e projetos',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.headlineSmall.override(
                        font: GoogleFonts.interTight(fontWeight: FontWeight.w800),
                        letterSpacing: -0.2,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const TenantSwitcherWidget(compact: true),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                FFAppState().UserName.isNotEmpty
                    ? 'Olá, ${FFAppState().UserName}'
                    : 'Gerencie suas obras sincronizadas',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodySmall.override(
                  font: GoogleFonts.inter(),
                  color: t.secondaryText,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: kBarraNavegacaoPrincipalReservaScroll + bottomInset,
                  ),
                  child: FutureBuilder<_InicioPayload>(
                    future: _payloadFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 36,
                                height: 36,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: t.primary,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Carregando obras…',
                                style: t.bodyMedium.override(
                                  font: GoogleFonts.inter(),
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline_rounded, size: 48, color: t.error),
                                const SizedBox(height: 12),
                                Text(
                                  'Não foi possível carregar as obras.',
                                  textAlign: TextAlign.center,
                                  style: t.titleSmall,
                                ),
                                const SizedBox(height: 16),
                                FilledButton.icon(
                                  onPressed: _recarregarLista,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Tentar novamente'),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      final payload = snapshot.data!;
                      final filtradas = _filtrarObras(payload.obras);

                      return RefreshIndicator(
                        color: t.primary,
                        onRefresh: () async {
                          await _runSyncAndReload();
                          final f = _carregarPayload();
                          setState(() {
                            _payloadFuture = f;
                          });
                          await f;
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _statusFilterDropdown(
                                      context: context,
                                      situacoes: payload.situacoes,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: _filtroRowHeight,
                                        child: TextField(
                                          controller: _model.textControllerBusca,
                                          focusNode: _model.textFieldBuscaFocusNode,
                                          textInputAction: TextInputAction.search,
                                          style: t.bodySmall.override(
                                            font: GoogleFonts.inter(),
                                            fontSize: (t.bodySmall.fontSize ?? 14.0) * 0.93,
                                          ),
                                          decoration: InputDecoration(
                                            isDense: true,
                                            hintText: 'Buscar obra...',
                                            hintStyle: t.bodySmall.override(
                                              font: GoogleFonts.inter(),
                                              color: t.secondaryText,
                                              fontSize: (t.bodySmall.fontSize ?? 14.0) * 0.93,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.search_rounded,
                                              size: 20,
                                              color: t.secondaryText,
                                            ),
                                            prefixIconConstraints: const BoxConstraints(
                                              minWidth: 36,
                                              minHeight: 36,
                                            ),
                                            suffixIcon: (_model.textControllerBusca?.text.isNotEmpty ?? false)
                                                ? IconButton(
                                                    tooltip: 'Limpar',
                                                    padding: EdgeInsets.zero,
                                                    constraints: const BoxConstraints(
                                                      minWidth: 32,
                                                      minHeight: 32,
                                                    ),
                                                    icon: Icon(
                                                      Icons.close_rounded,
                                                      size: 18,
                                                      color: t.secondaryText,
                                                    ),
                                                    onPressed: () {
                                                      _model.textControllerBusca?.clear();
                                                    },
                                                  )
                                                : null,
                                            suffixIconConstraints: const BoxConstraints(
                                              minWidth: 32,
                                              minHeight: 32,
                                            ),
                                            filled: true,
                                            fillColor: t.secondaryBackground,
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide.none,
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: Theme.of(context)
                                                    .dividerColor
                                                    .withValues(alpha: 0.3),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: t.primary,
                                                width: 1.2,
                                              ),
                                            ),
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 0,
                                              vertical: 10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                                child: Row(
                                  children: [
                                    Text(
                                      '${filtradas.length} obra${filtradas.length == 1 ? '' : 's'}',
                                      style: t.labelLarge.override(
                                        font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                                        color: t.secondaryText,
                                      ),
                                    ),
                                    if (filtradas.length != payload.obras.length) ...[
                                      Text(
                                        ' · ${payload.obras.length} no total',
                                        style: t.labelMedium.override(
                                          font: GoogleFonts.inter(),
                                          color: t.secondaryText.withValues(alpha: 0.85),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            if (filtradas.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.folder_open_rounded,
                                        size: 56,
                                        color: t.secondaryText.withValues(alpha: 0.45),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        payload.obras.isEmpty
                                            ? 'Nenhuma obra sincronizada ainda.\nPuxe para atualizar após o primeiro sync.'
                                            : 'Nenhuma obra corresponde à busca ou ao filtro.',
                                        textAlign: TextAlign.center,
                                        style: t.bodyMedium
                                            .override(
                                              font: GoogleFonts.inter(),
                                              color: t.secondaryText,
                                            )
                                            .copyWith(height: 1.4),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    return _obraCard(
                                      context: context,
                                      r: filtradas[index],
                                      situacoes: payload.situacoes,
                                    );
                                  },
                                  childCount: filtradas.length,
                                ),
                              ),
                            const SliverToBoxAdapter(child: SizedBox(height: 12)),
                          ],
                        ),
                      );
                    },
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
  }
}

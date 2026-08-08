import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'sincronizacoes_model.dart';
export 'sincronizacoes_model.dart';

/// Histórico das últimas sincronizações registradas localmente.
class SincronizacoesWidget extends StatefulWidget {
  const SincronizacoesWidget({super.key});

  static String routeName = 'sincronizacoes';
  static String routePath = '/sincronizacoes';

  @override
  State<SincronizacoesWidget> createState() => _SincronizacoesWidgetState();
}

class _SincronizacoesWidgetState extends State<SincronizacoesWidget> {
  late SincronizacoesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  late Future<List<SyncHistoryRecentRow>> _historyFuture;

  static const _limit = 20;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SincronizacoesModel());
    _historyFuture = _carregarHistorico();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<List<SyncHistoryRecentRow>> _carregarHistorico() {
    return SQLiteManager.instance.syncHistoryRecent(
      userUuid: FFAppState().creatorUuid,
      userId: FFAppState().creatorId,
      limit: _limit,
    );
  }

  Future<void> _refresh() async {
    setState(() {
      _historyFuture = _carregarHistorico();
    });
    await _historyFuture;
  }

  void _iniciarSincronizacao() {
    context.pushNamed(
      SincronizandoWidget.routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.bottomToTop,
        ),
      },
    );
  }

  ({bool success, bool error, Color color, IconData icon, String label})
      _statusInfo(FlutterFlowTheme theme, String? raw) {
    final status = (raw ?? '').toLowerCase();
    final isSuccess = status.contains('success') ||
        status.contains('sucesso') ||
        status.contains('completed') ||
        status.contains('ok');
    final isError = status.contains('erro') ||
        status.contains('error') ||
        status.contains('fail');

    if (isSuccess) {
      return (
        success: true,
        error: false,
        color: theme.success,
        icon: Icons.check_circle_rounded,
        label: 'Sucesso',
      );
    }
    if (isError) {
      return (
        success: false,
        error: true,
        color: theme.error,
        icon: Icons.cancel_rounded,
        label: 'Erro',
      );
    }
    return (
      success: false,
      error: false,
      color: theme.warning,
      icon: Icons.sync_rounded,
      label: (raw ?? '').trim().isEmpty ? 'Em andamento' : raw!.trim(),
    );
  }

  String _formatDateTime(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final dt = DateTime.tryParse(raw.trim());
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dt.toLocal());
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
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          toolbarHeight: 58,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.safePop(),
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sincronização',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Histórico local de sincronizações',
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
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 21),
              onPressed: _refresh,
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildBody(theme)),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FlutterFlowTheme theme) {
    return RefreshIndicator(
      color: theme.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<SyncHistoryRecentRow>>(
        future: _historyFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  ),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
              children: [
                Icon(Icons.error_outline_rounded,
                    size: 40, color: theme.error.withValues(alpha: 0.7)),
                const SizedBox(height: 12),
                Text(
                  'Erro ao carregar histórico',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            );
          }

          final rows = snapshot.data ?? const <SyncHistoryRecentRow>[];
          var ok = 0;
          var erro = 0;
          var outros = 0;
          for (final row in rows) {
            final info = _statusInfo(theme, row.status);
            if (info.success) {
              ok++;
            } else if (info.error) {
              erro++;
            } else {
              outros++;
            }
          }

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              kBarraNavegacaoPrincipalReservaScroll,
            ),
            children: [
              RdoSectionCard(
                title: 'Sincronizar agora',
                icon: Icons.cloud_sync_outlined,
                subtitle: 'Baixar e enviar dados com o servidor',
                margin: EdgeInsets.zero,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Inicie uma nova sincronização para atualizar obras, cadastros e relatórios.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: theme.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      onPressed: _iniciarSincronizacao,
                      icon: const Icon(Icons.sync_rounded, size: 18),
                      label: Text(
                        'Iniciar sincronização',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 10),
                RdoSectionCard(
                  title: 'Resumo',
                  icon: Icons.insights_outlined,
                  margin: EdgeInsets.zero,
                  contentPadding: EdgeInsets.zero,
                  child: RdoKpiStrip(
                    itens: [
                      RdoKpiData(
                        label: 'Total',
                        value: '${rows.length}',
                        destaque: true,
                      ),
                      RdoKpiData(label: 'Sucesso', value: '$ok'),
                      RdoKpiData(
                        label: erro > 0 ? 'Erro' : 'Outros',
                        value: erro > 0 ? '$erro' : '$outros',
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
              RdoSectionCard(
                title: 'Últimas sincronizações',
                icon: Icons.history_rounded,
                subtitle: rows.isEmpty
                    ? 'Nenhum registro local'
                    : 'Até as $_limit mais recentes',
                margin: EdgeInsets.zero,
                trailing:
                    rows.isEmpty ? null : RdoContadorChip('${rows.length}'),
                contentPadding: EdgeInsets.zero,
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 40,
                              color:
                                  theme.secondaryText.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Nenhuma sincronização registrada',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Execute uma sincronização para ver o histórico aqui.',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < rows.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.alternate,
                              ),
                            _buildHistoricoItem(theme, rows[i]),
                          ],
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHistoricoItem(
    FlutterFlowTheme theme,
    SyncHistoryRecentRow row,
  ) {
    final info = _statusInfo(theme, row.status);
    final started = row.startedAt ?? row.createdAt;
    final completed = row.completedAt;
    final when = completed ?? started;
    final subtitle = completed != null
        ? 'Início ${_formatDateTime(started)}'
        : 'Sincronização em andamento';

    return Material(
      color: theme.secondaryBackground,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: info.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(info.icon, color: info.color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  info.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.primaryText,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: info.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: info.color.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  (row.status ?? '—').trim().isEmpty
                                      ? '—'
                                      : row.status!.trim(),
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: info.color,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: theme.secondaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDateTime(when),
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.primary,
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
      ),
    );
  }
}

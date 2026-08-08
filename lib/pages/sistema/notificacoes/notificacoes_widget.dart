import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'notificacoes_model.dart';

export 'notificacoes_model.dart';

/// Lista notificações da API (`GET /api/notificacoes`), alinhada ao web.
///
/// Payload `data` pode incluir `action_mobile_url`, `ordem_servico_uuid`,
/// `relatorio_uuid`, `action_mobile_text`, etc. (ex.: [OrdemServicoAtrasada], [RdoCriado]).
class NotificacoesWidget extends StatefulWidget {
  const NotificacoesWidget({super.key});

  static String routeName = 'Notificacoes';
  static String routePath = '/notificacoes';

  @override
  State<NotificacoesWidget> createState() => _NotificacoesWidgetState();
}

class _NotificacoesWidgetState extends State<NotificacoesWidget> {
  late NotificacoesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _unreadCount = 0;

  /// `all` | `unread` | `read` — repassado à API como `filter`.
  String _filterLeitura = 'all';

  static const _perPage = 20;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NotificacoesModel());
    _scrollController.addListener(_onScroll);
    _carregar(reset: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _model.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    final pos = _scrollController.position;
    if (pos.pixels > pos.maxScrollExtent - 280) {
      _carregar();
    }
  }

  int? _idOf(Map<String, dynamic> n) {
    final v = n['id'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v');
  }

  bool _isRead(Map<String, dynamic> n) {
    final v = n['is_read'];
    if (v is bool) return v;
    return v == 1 || v == '1' || v == true;
  }

  Map<String, dynamic> _dataMap(Map<String, dynamic> n) {
    final d = n['data'];
    if (d is Map) return Map<String, dynamic>.from(d);
    return {};
  }

  Future<void> _carregar({bool reset = false}) async {
    if (_loadingMore && !reset) return;
    if (!_hasMore && !reset) return;

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login novamente.';
      });
      return;
    }

    if (reset) {
      setState(() {
        _page = 1;
        _hasMore = true;
        _items.clear();
        _loading = true;
        _error = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    final page = reset ? 1 : _page;
    final r = await NotificacoesListCall.call(
      token: token,
      page: page,
      perPage: _perPage,
      filter: _filterLeitura,
    );

    if (!mounted) return;

    if (!r.succeeded) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Não foi possível carregar as notificações (${r.statusCode}).';
      });
      return;
    }

    final body = r.jsonBody;
    if (body is! Map) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Resposta inválida do servidor.';
      });
      return;
    }

    final list = body['data'];
    final meta = body['meta'];
    final unread = body['unread_count'];

    if (list is! List) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Formato de dados inesperado.';
      });
      return;
    }

    final novas =
        list.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();

    int? currentPage;
    int? lastPage;
    if (meta is Map) {
      final cp = meta['current_page'];
      final lp = meta['last_page'];
      if (cp is num) currentPage = cp.toInt();
      if (lp is num) lastPage = lp.toInt();
    }
    final hasMorePages =
        currentPage != null && lastPage != null && currentPage < lastPage;

    setState(() {
      if (reset) {
        _items.clear();
      }
      final ids = _items.map(_idOf).toSet();
      for (final it in novas) {
        final id = _idOf(it);
        if (id != null && ids.contains(id)) continue;
        _items.add(it);
        if (id != null) ids.add(id);
      }
      if (unread is num) {
        _unreadCount = unread.toInt();
      } else if (unread is int) {
        _unreadCount = unread;
      }
      _hasMore =
          hasMorePages || (currentPage == null && novas.length >= _perPage);
      _page = (currentPage ?? page) + 1;
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  String _mensagemErro(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is Map && b['message'] != null) return '${b['message']}';
    return 'Erro ${r.statusCode}';
  }

  Future<void> _marcarLida(Map<String, dynamic> n) async {
    if (_isRead(n)) return;
    final id = _idOf(n);
    if (id == null) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    final r = await NotificacaoMarcarLidaCall.call(token: token, id: id);
    if (!mounted) return;
    if (r.succeeded) {
      setState(() {
        n['is_read'] = true;
        _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
      });
    }
  }

  Future<void> _marcarTodasLidas() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    final r = await NotificacoesMarcarTodasLidasCall.call(token: token);
    if (!mounted) return;
    if (r.succeeded) {
      setState(() {
        for (final n in _items) {
          n['is_read'] = true;
        }
        _unreadCount = 0;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Todas marcadas como lidas.')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensagemErro(r))),
      );
    }
  }

  Future<void> _excluir(Map<String, dynamic> n) async {
    final id = _idOf(n);
    if (id == null) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    final r = await NotificacaoExcluirCall.call(token: token, id: id);
    if (!mounted) return;
    if (r.succeeded) {
      setState(() {
        if (!_isRead(n)) {
          _unreadCount = (_unreadCount - 1).clamp(0, 1 << 30);
        }
        _items.removeWhere((e) => _idOf(e) == id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notificação removida.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_mensagemErro(r))),
      );
    }
  }

  String _tempoRelativo(dynamic createdAt) {
    if (createdAt == null) return '';
    final s = createdAt.toString().trim();
    if (s.isEmpty) return '';
    var dt = DateTime.tryParse(s);
    if (dt == null && s.contains(' ') && !s.contains('T')) {
      dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }
    if (dt == null) return s;
    final now = DateTime.now();
    final diff = now.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'Agora';
    if (diff.inMinutes < 60) return 'Há ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Há ${diff.inHours} h';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) return 'Há ${diff.inDays} dias';
    return dateTimeFormat('dd/MM/yyyy HH:mm', dt.toLocal(), locale: 'pt_BR');
  }

  IconData _iconeTipo(String? type) {
    switch (type) {
      case 'warning':
        return Icons.warning_amber_rounded;
      case 'approval':
        return Icons.fact_check_rounded;
      case 'alert':
        return Icons.notifications_active_rounded;
      case 'reminder':
        return Icons.alarm_rounded;
      case 'info':
        return Icons.info_outline_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _corTipo(BuildContext context, String? type) {
    final t = FlutterFlowTheme.of(context);
    switch (type) {
      case 'warning':
        return t.warning;
      case 'approval':
        return t.success;
      case 'alert':
        return t.error;
      case 'reminder':
        return t.primary;
      default:
        return t.secondaryText;
    }
  }

  Future<void> _abrirNotificacao(Map<String, dynamic> n) async {
    await _marcarLida(n);
    if (!mounted) return;

    final data = _dataMap(n);
    final mobile = data['action_mobile_url']?.toString().trim() ?? '';

    if (mobile.startsWith('rdopro://relatorio/')) {
      final uuid = mobile
          .replaceFirst('rdopro://relatorio/', '')
          .split('/')
          .first
          .trim();
      if (uuid.isNotEmpty) {
        context.pushNamed(
          RelatorioDetalhesWidget.routeName,
          queryParameters: {'uuid': uuid}.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: const TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.rightToLeft,
            ),
          },
        );
      }
      return;
    }

    if (mobile.contains('ordem-servico')) {
      final part = mobile.split('/').last.trim();
      if (part.isNotEmpty) {
        context.pushNamed(
          DetalhesOrdemServicoWidget.routeName,
          queryParameters: {'ordemUuid': part}.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: const TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.rightToLeft,
            ),
          },
        );
      }
      return;
    }

    final relUuid = data['relatorio_uuid']?.toString().trim();
    if (relUuid != null && relUuid.isNotEmpty) {
      context.pushNamed(
        RelatorioDetalhesWidget.routeName,
        queryParameters: {'uuid': relUuid}.withoutNulls,
        extra: <String, dynamic>{
          kTransitionInfoKey: const TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.rightToLeft,
          ),
        },
      );
      return;
    }

    final osUuid = data['ordem_servico_uuid']?.toString().trim();
    if (osUuid != null && osUuid.isNotEmpty) {
      context.pushNamed(
        DetalhesOrdemServicoWidget.routeName,
        queryParameters: {'ordemUuid': osUuid}.withoutNulls,
        extra: <String, dynamic>{
          kTransitionInfoKey: const TransitionInfo(
            hasTransition: true,
            transitionType: PageTransitionType.rightToLeft,
          ),
        },
      );
      return;
    }

    final actionUrl = data['action_url']?.toString() ?? '';
    if (actionUrl.contains('/relatorios/show/')) {
      final cam =
          actionUrl.split('/relatorios/show/').last.split('/').first.trim();
      if (cam.isNotEmpty) {
        context.pushNamed(
          RelatorioDetalhesWidget.routeName,
          queryParameters: {'camufladoId': cam}.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: const TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.rightToLeft,
            ),
          },
        );
      }
    }
  }

  Future<void> _confirmarExcluir(Map<String, dynamic> n) async {
    final theme = FlutterFlowTheme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Excluir notificação?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        content: Text(
          'Esta ação não pode ser desfeita.',
          style: GoogleFonts.inter(fontSize: 13.5, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (ok == true) await _excluir(n);
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
                  'Notificações',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _unreadCount > 0
                      ? '$_unreadCount não lida${_unreadCount == 1 ? '' : 's'}'
                      : 'Alertas de OS, RDO e sistema',
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
            if (_unreadCount > 0)
              IconButton(
                tooltip: 'Marcar todas como lidas',
                icon: const Icon(Icons.done_all_rounded,
                    color: Colors.white, size: 21),
                onPressed: _loading ? null : _marcarTodasLidas,
              ),
            IconButton(
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 21),
              onPressed: _loading ? null : () => _carregar(reset: true),
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
      onRefresh: () => _carregar(reset: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          if (_unreadCount > 0 || _items.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: RdoSectionCard(
                  title: 'Resumo',
                  icon: Icons.insights_outlined,
                  margin: EdgeInsets.zero,
                  contentPadding: EdgeInsets.zero,
                  child: RdoKpiStrip(
                    itens: [
                      RdoKpiData(
                        label: 'Não lidas',
                        value: '$_unreadCount',
                        destaque: _unreadCount > 0,
                      ),
                      RdoKpiData(
                        label: 'Nesta lista',
                        value: '${_items.length}',
                      ),
                      RdoKpiData(
                        label: 'Filtro',
                        value: _filterLeitura == 'all'
                            ? 'Todas'
                            : _filterLeitura == 'unread'
                                ? 'Não lidas'
                                : 'Lidas',
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _buildFiltros(theme),
            ),
          ),
          if (_error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.error.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 18, color: theme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            color: theme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              16,
              10,
              16,
              kBarraNavegacaoPrincipalReservaScroll,
            ),
            sliver: SliverToBoxAdapter(
              child: RdoSectionCard(
                title: 'Lista',
                icon: Icons.notifications_outlined,
                subtitle: _loading && _items.isEmpty
                    ? 'Carregando…'
                    : _items.isEmpty
                        ? 'Nenhuma notificação neste filtro'
                        : 'Toque para abrir · deslize para mais',
                margin: EdgeInsets.zero,
                trailing: _items.isEmpty
                    ? null
                    : RdoContadorChip('${_items.length}'),
                contentPadding: EdgeInsets.zero,
                child: _buildListaConteudo(theme),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros(FlutterFlowTheme theme) {
    return RdoSectionCard(
      title: 'Filtro',
      icon: Icons.filter_list_rounded,
      subtitle: 'Por status de leitura',
      margin: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Container(
        decoration: BoxDecoration(
          color: theme.primaryBackground.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: theme.alternate),
        ),
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _buildFiltroBotao(
                theme,
                value: 'all',
                titulo: 'Todas',
                subtitulo: 'Completo',
                icon: Icons.inbox_outlined,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildFiltroBotao(
                theme,
                value: 'unread',
                titulo: 'Não lidas',
                subtitulo: _unreadCount == 0
                    ? 'Nenhuma'
                    : '$_unreadCount pendente${_unreadCount == 1 ? '' : 's'}',
                icon: Icons.mark_email_unread_outlined,
                badge: _unreadCount > 0 ? _unreadCount : null,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: _buildFiltroBotao(
                theme,
                value: 'read',
                titulo: 'Lidas',
                subtitulo: 'Arquivo',
                icon: Icons.mark_email_read_outlined,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroBotao(
    FlutterFlowTheme theme, {
    required String value,
    required String titulo,
    required String subtitulo,
    required IconData icon,
    int? badge,
  }) {
    final selecionado = _filterLeitura == value;
    final disabled = _loading;

    return Material(
      color: selecionado ? theme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: disabled
            ? null
            : () {
                if (_filterLeitura == value) return;
                setState(() => _filterLeitura = value);
                _carregar(reset: true);
              },
        borderRadius: BorderRadius.circular(8),
        child: Opacity(
          opacity: disabled ? 0.55 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selecionado
                            ? Colors.white.withValues(alpha: 0.18)
                            : theme.secondaryBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: selecionado
                            ? null
                            : Border.all(color: theme.alternate),
                      ),
                      child: Icon(
                        icon,
                        size: 16,
                        color: selecionado ? Colors.white : theme.primary,
                      ),
                    ),
                    if (badge != null)
                      Positioned(
                        right: -6,
                        top: -5,
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 16),
                          height: 16,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selecionado
                                ? Colors.white
                                : theme.error,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: selecionado
                                  ? theme.primary
                                  : theme.secondaryBackground,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            badge > 99 ? '99+' : '$badge',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: selecionado
                                  ? theme.primary
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  titulo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selecionado ? Colors.white : theme.primaryText,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  subtitulo,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                    color: selecionado
                        ? Colors.white.withValues(alpha: 0.85)
                        : theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildListaConteudo(FlutterFlowTheme theme) {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
        child: Column(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: theme.secondaryText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              'Nenhuma notificação',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _filterLeitura == 'unread'
                  ? 'Você não tem notificações não lidas.'
                  : _filterLeitura == 'read'
                      ? 'Nenhuma notificação lida neste filtro.'
                      : 'Quando houver alertas de OS, RDO ou sistema, eles aparecem aqui.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, color: theme.alternate),
          _buildNotificacaoItem(theme, _items[i]),
        ],
        if (_loadingMore)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNotificacaoItem(
    FlutterFlowTheme theme,
    Map<String, dynamic> n,
  ) {
    final read = _isRead(n);
    final tipo = n['type']?.toString();
    final title = n['title']?.toString() ?? 'Notificação';
    final message = n['message']?.toString() ?? '';
    final data = _dataMap(n);
    final actionText =
        data['action_mobile_text']?.toString().trim() ?? 'Abrir';
    final corTipo = _corTipo(context, tipo);
    final faixa = read ? theme.alternate : theme.primary;

    return Material(
      color: read
          ? theme.secondaryBackground
          : theme.primary.withValues(alpha: 0.04),
      child: InkWell(
        onTap: () => _abrirNotificacao(n),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: faixa),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 0, 10),
                child: Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: corTipo.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(_iconeTipo(tipo), color: corTipo, size: 18),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight:
                                    read ? FontWeight.w600 : FontWeight.w700,
                                color: theme.primaryText,
                              ),
                            ),
                          ),
                          if (!read)
                            Container(
                              width: 7,
                              height: 7,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: theme.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.3,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _tempoRelativo(n['created_at']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: theme.secondaryText,
                              ),
                            ),
                          ),
                          Text(
                            actionText,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: read ? theme.secondaryText : theme.primary,
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: read ? theme.secondaryText : theme.primary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message: 'Excluir',
                child: InkWell(
                  onTap: () => _confirmarExcluir(n),
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: 36,
                    child: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: theme.secondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
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
            '__transition_info__': TransitionInfo(
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
            '__transition_info__': TransitionInfo(
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
          '__transition_info__': TransitionInfo(
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
          '__transition_info__': TransitionInfo(
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
            '__transition_info__': TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.rightToLeft,
            ),
          },
        );
      }
    }
  }

  Widget _buildFiltroTabs(FlutterFlowTheme t) {
    Widget tab(String value, String label) {
      final selected = _filterLeitura == value;
      return Expanded(
        child: Material(
          color: selected ? t.secondaryBackground : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          elevation: selected ? 1 : 0,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          child: InkWell(
            onTap: _loading
                ? null
                : () {
                    if (_filterLeitura == value) return;
                    setState(() => _filterLeitura = value);
                    _carregar(reset: true);
                  },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? t.primary : t.secondaryText,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: t.primaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: t.alternate),
      ),
      child: Row(
        children: [
          tab('all', 'Todas'),
          tab('unread', 'Não lidas ($_unreadCount)'),
          tab('read', 'Lidas'),
        ],
      ),
    );
  }

  Widget _buildNotificacaoItem(
    BuildContext context,
    FlutterFlowTheme t,
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
    final faixa = read ? t.alternate : t.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _abrirNotificacao(n),
          child: Container(
            decoration: BoxDecoration(
              color: read
                  ? t.secondaryBackground
                  : t.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: read
                    ? t.primaryText.withValues(alpha: 0.06)
                    : t.primary.withValues(alpha: 0.18),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3.5, color: faixa),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 6, 0, 6),
                      child: Icon(
                        _iconeTipo(tipo),
                        color: corTipo,
                        size: 18,
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(6, 5, 4, 5),
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
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: t.primaryText,
                                    ),
                                  ),
                                ),
                                if (!read)
                                  Container(
                                    width: 6,
                                    height: 6,
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: BoxDecoration(
                                      color: t.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                              ],
                            ),
                            if (message.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  height: 1.25,
                                  color: t.secondaryText,
                                ),
                              ),
                            ],
                            const SizedBox(height: 3),
                            Text(
                              '${_tempoRelativo(n['created_at'])} · $actionText',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: read ? t.secondaryText : t.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _iconAction(
                      t,
                      icon: Icons.delete_outline_rounded,
                      tooltip: 'Excluir',
                      onPressed: () => _confirmarExcluir(n),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconAction(
    FlutterFlowTheme t, {
    required IconData icon,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final btn = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 32,
          height: double.infinity,
          child: Icon(icon, size: 18, color: t.secondaryText),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip, child: btn);
  }

  Future<void> _confirmarExcluir(Map<String, dynamic> n) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir notificação?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Excluir')),
        ],
      ),
    );
    if (ok == true) await _excluir(n);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final t = FlutterFlowTheme.of(context);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        backgroundColor: t.primaryBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          title: Text(
            'Notificações',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: t.primaryText,
              letterSpacing: -0.2,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: t.primary),
            onPressed: () => context.safePop(),
          ),
          actions: [
            if (_unreadCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: TextButton(
                  onPressed: _loading ? null : _marcarTodasLidas,
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'Marcar todas',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: t.primary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.only(
                  bottom: kBarraNavegacaoPrincipalReservaScroll,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 6),
                      child: _buildFiltroTabs(t),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                        child: Text(
                          _error!,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: t.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: _loading && _items.isEmpty
                          ? Center(
                              child:
                                  CircularProgressIndicator(color: t.primary))
                          : RefreshIndicator(
                              color: t.primary,
                              onRefresh: () => _carregar(reset: true),
                              child: _items.isEmpty
                                  ? ListView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      children: [
                                        SizedBox(
                                          height: MediaQuery.sizeOf(context)
                                                  .height *
                                              0.18,
                                        ),
                                        Icon(
                                          Icons.notifications_off_outlined,
                                          size: 36,
                                          color: t.secondaryText
                                              .withValues(alpha: 0.45),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          'Nenhuma notificação por aqui.',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            color: t.secondaryText,
                                          ),
                                        ),
                                      ],
                                    )
                                  : ListView.builder(
                                      controller: _scrollController,
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      padding: const EdgeInsets.fromLTRB(
                                          12, 2, 12, 16),
                                      itemCount: _items.length +
                                          (_loadingMore ? 1 : 0),
                                      itemBuilder: (context, i) {
                                        if (i >= _items.length) {
                                          return Padding(
                                            padding: const EdgeInsets.all(16),
                                            child: Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: t.primary,
                                                ),
                                              ),
                                            ),
                                          );
                                        }
                                        return _buildNotificacaoItem(
                                          context,
                                          t,
                                          _items[i],
                                        );
                                      },
                                    ),
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
  }
}

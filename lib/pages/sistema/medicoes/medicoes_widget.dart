import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'medicoes_model.dart';

export 'medicoes_model.dart';

class MedicoesWidget extends StatefulWidget {
  const MedicoesWidget({super.key});

  static String routeName = 'Medicoes';
  static String routePath = '/medicoes';

  @override
  State<MedicoesWidget> createState() => _MedicoesWidgetState();
}

class _MedicoesWidgetState extends State<MedicoesWidget> {
  late MedicoesModel _model;

  final _scrollController = ScrollController();

  final List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _obras = [];

  int _page = 1;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _totalServidor = 0;

  int? _enviandoAprovacaoMedicaoId;

  int? _obraFiltro;
  String _statusFiltro = '';

  static const _perPage = 15;

  static const _opcoesStatus = <MapEntry<String, String>>[
    MapEntry('', 'Todos'),
    MapEntry('preenchendo', 'Preenchendo'),
    MapEntry('em_aprovacao', 'Em aprovação'),
    MapEntry('aprovada', 'Aprovada'),
    MapEntry('reprovado', 'Reprovado'),
  ];

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MedicoesModel());
    _scrollController.addListener(_onScroll);
    _carregarObras();
    _carregarMedicoes(reset: true);
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
    if (pos.pixels > pos.maxScrollExtent - 320) {
      _carregarMedicoes();
    }
  }

  List<Map<String, dynamic>> _parseObrasIndex(dynamic jsonBody) {
    if (jsonBody is! Map) return [];
    final obras = jsonBody['obras'];
    if (obras is Map && obras['data'] is List) {
      return (obras['data'] as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    return [];
  }

  Future<void> _carregarObras() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    final r = await ListarObrasResumoCall.call(token: token);
    if (!mounted || !r.succeeded) return;
    setState(() {
      _obras = _parseObrasIndex(r.jsonBody);
    });
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  Future<void> _carregarMedicoes({bool reset = false}) async {
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
    final r = await MedicoesListCall.call(
      token: token,
      page: page,
      perPage: _perPage,
      obraId: _obraFiltro,
      status: _statusFiltro.isEmpty ? null : _statusFiltro,
    );

    if (!mounted) return;

    if (!r.succeeded) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Não foi possível carregar as medições (${r.statusCode}).';
      });
      return;
    }

    final body = r.jsonBody;
    if (body is! Map) {
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = 'Resposta inválida.';
      });
      return;
    }

    final list = body['data'];
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
    final cp = body['current_page'];
    final lp = body['last_page'];
    final tot = body['total'];
    if (cp is num) currentPage = cp.toInt();
    if (lp is num) lastPage = lp.toInt();
    if (tot is num) {
      _totalServidor = tot.toInt();
    }

    final hasMorePages =
        currentPage != null && lastPage != null && currentPage < lastPage;

    setState(() {
      if (reset) _items.clear();
      final ids = _items.map((e) => _toInt(e['id'])).toSet();
      for (final it in novas) {
        final id = _toInt(it['id']);
        if (id != null && ids.contains(id)) continue;
        _items.add(it);
        if (id != null) ids.add(id);
      }
      _hasMore =
          hasMorePages || (currentPage == null && novas.length >= _perPage);
      _page = (currentPage ?? page) + 1;
      _loading = false;
      _loadingMore = false;
      _error = null;
    });
  }

  String _obraNome(Map<String, dynamic> m) {
    final o = m['obra'];
    if (o is Map) {
      final n = o['nome']?.toString().trim();
      if (n != null && n.isNotEmpty) return n;
    }
    return 'Obra';
  }

  String _formatDataSimples(dynamic raw) {
    if (raw == null) return '—';
    final s = raw.toString().trim();
    if (s.isEmpty) return '—';
    var dt = DateTime.tryParse(s);
    if (dt == null && s.contains(' ') && !s.contains('T')) {
      dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }
    if (dt == null) {
      if (s.length >= 10) {
        return s.substring(0, 10).split('-').reversed.join('/');
      }
      return s;
    }
    return dateTimeFormat('dd/MM/yyyy', dt.toLocal(), locale: 'pt_BR');
  }

  String _formatMesReferencia(dynamic raw) {
    if (raw == null) return '';
    final s = raw.toString().trim();
    if (s.length >= 7) {
      final p = s.substring(0, 7).split('-');
      if (p.length == 2) return '${p[1]}/${p[0]}';
    }
    return s;
  }

  String _metaCompacta(Map<String, dynamic> m) {
    final ref = _formatMesReferencia(m['mes_referencia']).trim();
    final ini = _formatDataSimples(m['data_inicio_periodo']);
    final fim = _formatDataSimples(m['data_termino_periodo']);
    final dMed = _formatDataSimples(
      m['data_medicao'] ?? m['data_emissao'] ?? m['created_at'],
    );
    final buf = StringBuffer();
    if (ref.isNotEmpty) buf.write('Ref. $ref');
    if (ini != '—' || fim != '—') {
      if (buf.isNotEmpty) buf.write(' · ');
      buf.write('$ini - $fim');
    }
    if (dMed != '—') {
      if (buf.isNotEmpty) buf.write(' · ');
      buf.write(dMed);
    }
    final s = buf.toString();
    return s.isEmpty ? '—' : s;
  }

  int? _statusId(Map<String, dynamic> m) => _toInt(m['status_id']);

  String _labelStatus(Map<String, dynamic> m) {
    final sid = _statusId(m);
    if (sid != null) {
      switch (sid) {
        case 1:
          return 'Preenchendo';
        case 2:
          return 'Em aprovação';
        case 3:
          return 'Aprovada';
        case 4:
          return 'Reprovado';
      }
    }
    final st = m['status']?.toString() ?? '';
    if (st.isEmpty) return '—';
    return st.replaceAll('_', ' ');
  }

  Color _corStatusChip(BuildContext context, Map<String, dynamic> m) {
    final theme = FlutterFlowTheme.of(context);
    final sid = _statusId(m);
    // Prioriza status_id (fonte canônica); a coluna string `status` pode ficar defasada.
    switch (sid) {
      case 1:
        return const Color(0xFF2196F3); // Preenchendo
      case 2:
        return const Color(0xFF7B1FA2); // Em aprovação
      case 3:
        return theme.success; // Aprovada
      case 4:
        return theme.error; // Reprovado
    }
    final st = (m['status'] ?? '').toString().trim().toLowerCase();
    switch (st) {
      case 'em_aprovacao':
      case 'assinatura_pendente':
        return const Color(0xFF7B1FA2);
      case 'aprovada':
        return theme.success;
      case 'reprovado':
      case 'recusada':
        return theme.error;
      case 'preenchendo':
      case 'rascunho':
        return const Color(0xFF2196F3);
      default:
        return theme.secondaryText;
    }
  }

  IconData _iconeStatus(int? statusId) {
    switch (statusId) {
      case 2:
        return Icons.hourglass_top_rounded;
      case 3:
        return Icons.check_circle_rounded;
      case 4:
        return Icons.cancel_rounded;
      default:
        return Icons.edit_note_rounded;
    }
  }

  Future<void> _enviarParaAprovacao(Map<String, dynamic> medicao) async {
    final id = _toInt(medicao['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar para aprovação'),
        content: Text(
          'Enviar medição #${medicao['numero'] ?? id} para a fila de assinaturas?',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;

    setState(() => _enviandoAprovacaoMedicaoId = id);
    final r =
        await MedicaoEnviarAprovacaoCall.call(token: token, medicaoId: id);
    if (!mounted) return;
    setState(() => _enviandoAprovacaoMedicaoId = null);

    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medição enviada para aprovação.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _carregarMedicoes(reset: true);
    } else {
      final msg = r.jsonBody is Map && (r.jsonBody as Map)['message'] != null
          ? '${(r.jsonBody as Map)['message']}'
          : 'Não foi possível enviar (HTTP ${r.statusCode}).';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _abrirDetalhes(Map<String, dynamic> m) {
    final id = _toInt(m['id']);
    if (id == null) return;
    context.pushNamed(
      MedicaoDetalhesWidget.routeName,
      queryParameters: {
        'medicaoId': serializeParam(id, ParamType.int),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
  }

  String _labelFiltroObra() {
    if (_obraFiltro == null) return 'Todas';
    for (final o in _obras) {
      if (_toInt(o['id']) == _obraFiltro) {
        final n = (o['nome']?.toString() ?? '').trim();
        return n.isEmpty ? 'Obra' : n;
      }
    }
    return 'Obra';
  }

  String _labelFiltroStatus() {
    for (final e in _opcoesStatus) {
      if (e.key == _statusFiltro) return e.value;
    }
    return 'Todos';
  }

  Widget _statusChip(BuildContext context, Map<String, dynamic> m) {
    final cor = _corStatusChip(context, m);
    final sid = _statusId(m);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconeStatus(sid), size: 11, color: cor),
          const SizedBox(width: 4),
          Text(
            _labelStatus(m),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconAction({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
    String? tooltip,
    bool loading = false,
  }) {
    final btn = Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(7),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          width: 28,
          height: 28,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(6),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              : Icon(icon, size: 15, color: color),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip, child: btn);
  }

  Widget _filtroChip({
    required String label,
    required String valor,
    required IconData icon,
    required VoidCallback onTap,
    bool ativo = false,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Material(
      color: ativo
          ? theme.primary.withValues(alpha: 0.08)
          : theme.primaryBackground.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: ativo
                  ? theme.primary.withValues(alpha: 0.4)
                  : theme.alternate,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: ativo ? theme.primary : theme.secondaryText,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label.toUpperCase(), style: rdoColumnLabelStyle(context)),
                    Text(
                      valor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.expand_more_rounded, size: 16, color: theme.secondaryText),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _abrirFiltroObraSafe() async {
    final result = await showModalBottomSheet<_FiltroEscolha<int?>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Filtrar por obra',
                  style: GoogleFonts.interTight(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.layers_clear_rounded,
                  color: _obraFiltro == null ? theme.primary : theme.secondaryText,
                ),
                title: Text(
                  'Todas as obras',
                  style: GoogleFonts.inter(
                    fontWeight:
                        _obraFiltro == null ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onTap: () =>
                    Navigator.pop(ctx, const _FiltroEscolha<int?>(null)),
              ),
              ..._obras.map((o) {
                final id = _toInt(o['id']);
                final nome = (o['nome']?.toString() ?? '—').trim();
                final selected = id != null && id == _obraFiltro;
                return ListTile(
                  leading: Icon(
                    Icons.domain_rounded,
                    color: selected ? theme.primary : theme.secondaryText,
                  ),
                  title: Text(
                    nome,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, _FiltroEscolha(id)),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _obraFiltro = result.value);
    await _carregarMedicoes(reset: true);
  }

  Future<void> _abrirFiltroStatus() async {
    final result = await showModalBottomSheet<_FiltroEscolha<String>>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = FlutterFlowTheme.of(ctx);
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'Filtrar por status',
                  style: GoogleFonts.interTight(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              ..._opcoesStatus.map((e) {
                final selected = e.key == _statusFiltro;
                return ListTile(
                  leading: Icon(
                    Icons.flag_outlined,
                    color: selected ? theme.primary : theme.secondaryText,
                  ),
                  title: Text(
                    e.value,
                    style: GoogleFonts.inter(
                      fontWeight:
                          selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, _FiltroEscolha(e.key)),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (result == null || !mounted) return;
    setState(() => _statusFiltro = result.value);
    await _carregarMedicoes(reset: true);
  }

  Widget _barraFiltros(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: rdoCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: _filtroChip(
                    label: 'Obra',
                    valor: _labelFiltroObra(),
                    icon: Icons.domain_rounded,
                    ativo: _obraFiltro != null,
                    onTap: _abrirFiltroObraSafe,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _filtroChip(
                    label: 'Status',
                    valor: _labelFiltroStatus(),
                    icon: Icons.flag_outlined,
                    ativo: _statusFiltro.isNotEmpty,
                    onTap: _abrirFiltroStatus,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context)
                  .primaryBackground
                  .withValues(alpha: 0.45),
              border: Border(
                top: BorderSide(color: FlutterFlowTheme.of(context).alternate),
              ),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(kRdoRadius),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 13,
                  color: FlutterFlowTheme.of(context).secondaryText,
                ),
                const SizedBox(width: 5),
                Text(
                  _loading && _items.isEmpty
                      ? 'CARREGANDO…'
                      : '${_items.length} MEDIÇÃO${_items.length == 1 ? '' : 'ÕES'}',
                  style: rdoColumnLabelStyle(context),
                ),
                if (_totalServidor > 0) ...[
                  const Spacer(),
                  Text(
                    'de $_totalServidor no total',
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: FlutterFlowTheme.of(context)
                          .secondaryText
                          .withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicaoCard(Map<String, dynamic> m, {required bool ultimo}) {
    final theme = FlutterFlowTheme.of(context);
    final numero = m['numero']?.toString() ?? '—';
    final cor = _corStatusChip(context, m);
    final sid = _statusId(m);
    final enviandoEsta = _enviandoAprovacaoMedicaoId == _toInt(m['id']);

    return Padding(
      padding: EdgeInsets.only(bottom: ultimo && !_hasMore ? 0 : 6),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: rdoCardDecoration(context),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _abrirDetalhes(m),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3.5, color: cor),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Med. #$numero',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.interTight(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: theme.primaryText,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    _statusChip(context, m),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              if (sid == 1)
                                _iconAction(
                                  icon: Icons.send_rounded,
                                  color: theme.success,
                                  tooltip: 'Enviar para aprovação',
                                  loading: enviandoEsta,
                                  onPressed: enviandoEsta
                                      ? null
                                      : () => _enviarParaAprovacao(m),
                                ),
                              if (sid == 1) const SizedBox(width: 4),
                              _iconAction(
                                icon: Icons.visibility_outlined,
                                color: theme.primary,
                                tooltip: 'Detalhes',
                                onPressed: () => _abrirDetalhes(m),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _obraNome(m),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_outlined,
                                size: 12,
                                color: theme.secondaryText,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  _metaCompacta(m),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _lista(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    if (_loading && _items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Carregando medições…',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: () => _carregarMedicoes(reset: true),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          kBarraNavegacaoPrincipalReservaScroll + bottomInset + 16,
        ),
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(kRdoRadius),
                border: Border.all(color: theme.error.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 18, color: theme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _error!,
                      style: GoogleFonts.inter(fontSize: 12.5, color: theme.error),
                    ),
                  ),
                ],
              ),
            ),
          RdoSectionCard(
            title: 'Medições',
            icon: Icons.receipt_long_outlined,
            margin: EdgeInsets.zero,
            trailing: _totalServidor > 0
                ? RdoContadorChip('$_totalServidor')
                : null,
            contentPadding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: _items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 28,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 44,
                          color: theme.secondaryText.withValues(alpha: 0.45),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Nenhuma medição encontrada',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ajuste os filtros ou cadastre uma nova medição.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      for (var i = 0; i < _items.length; i++)
                        _medicaoCard(
                          _items[i],
                          ultimo: i == _items.length - 1,
                        ),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          child: Center(
                            child: SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
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
            onPressed: () {
              if (context.canPop()) {
                context.safePop();
              } else {
                context.goNamed(InicioWidget.routeName);
              }
            },
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medições',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Medições mensais das obras',
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
              icon: const Icon(
                Icons.refresh_rounded,
                color: Colors.white,
                size: 21,
              ),
              onPressed: _loading ? null : () => _carregarMedicoes(reset: true),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          top: true,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    _barraFiltros(context),
                    Expanded(child: _lista(context)),
                  ],
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

class _FiltroEscolha<T> {
  const _FiltroEscolha(this.value);
  final T value;
}

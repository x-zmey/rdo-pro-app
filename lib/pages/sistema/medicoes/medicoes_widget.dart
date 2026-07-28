import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
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

class _MedicoesWidgetState extends State<MedicoesWidget>
    with SingleTickerProviderStateMixin {
  late MedicoesModel _model;
  late AnimationController _animationController;

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
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _scrollController.addListener(_onScroll);
    _carregarObras();
    _carregarMedicoes(reset: true);
    _animationController.forward();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _animationController.dispose();
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
      if (s.length >= 10)
        return s.substring(0, 10).split('-').reversed.join('/');
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

  /// Uma linha: referência, período e data da medição (layout compacto).
  String _metaCompacta(Map<String, dynamic> m) {
    final ref = _formatMesReferencia(m['mes_referencia']).trim();
    final ini = _formatDataSimples(m['data_inicio_periodo']);
    final fim = _formatDataSimples(m['data_termino_periodo']);
    final dMed = _formatDataSimples(
        m['data_medicao'] ?? m['data_emissao'] ?? m['created_at']);
    final buf = StringBuffer();
    if (ref.isNotEmpty) buf.write('Ref. $ref');
    if (ini != '—' || fim != '—') {
      if (buf.isNotEmpty) buf.write(' · ');
      buf.write('$ini–$fim');
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
    final st = (m['status'] ?? '').toString();
    switch (st) {
      case 'em_aprovacao':
        return theme.warning;
      case 'aprovada':
        return theme.success;
      case 'reprovado':
        return theme.error;
      case 'preenchendo':
      default:
        return theme.secondaryText;
    }
  }

  Future<void> _enviarParaAprovacao(Map<String, dynamic> medicao) async {
    final id = _toInt(medicao['id']);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
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
        '__transition_info__': TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
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
        appBar: _buildAppBar(theme),
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
                  child: _buildBody(theme),
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

  PreferredSizeWidget _buildAppBar(FlutterFlowTheme theme) {
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
          onPressed: () => context.safePop(),
        ),
      ),
      title: Text(
        'Medições',
        style: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: theme.primaryText,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.primary, size: 22),
            onPressed: () => _carregarMedicoes(reset: true),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(FlutterFlowTheme theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(theme),
        _buildFilters(theme),
        if (_totalServidor > 0) _buildTotalInfo(theme),
        if (_error != null) _buildErrorWidget(theme),
        Expanded(
          child: _buildContent(theme),
        ),
      ],
    );
  }

  Widget _buildHeader(FlutterFlowTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.receipt_long_rounded,
                  size: 18, color: theme.primary),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Medições mensais das obras. Use Detalhes para aprovar ou reprovar quando permitido.',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  color: theme.secondaryText,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(FlutterFlowTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: _buildDropdown(
              theme,
              value: _obraFiltro,
              label: 'Obra',
              hint: 'Todas as obras',
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text(
                    'Todas as obras',
                    style: GoogleFonts.inter(color: theme.primaryText),
                  ),
                ),
                ..._obras.map((o) {
                  final id = _toInt(o['id']);
                  final nome = o['nome']?.toString() ?? '—';
                  return DropdownMenuItem<int>(
                    value: id,
                    child: Text(
                      nome,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(color: theme.primaryText),
                    ),
                  );
                }),
              ],
              onChanged: (v) {
                setState(() => _obraFiltro = v);
                _carregarMedicoes(reset: true);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildDropdown(
              theme,
              value: _statusFiltro,
              label: 'Status',
              hint: 'Todos',
              items: _opcoesStatus
                  .map(
                    (e) => DropdownMenuItem<String>(
                      value: e.key,
                      child: Text(
                        e.value,
                        style: GoogleFonts.inter(color: theme.primaryText),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() => _statusFiltro = v ?? '');
                _carregarMedicoes(reset: true);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    FlutterFlowTheme theme, {
    required T? value,
    required String label,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            fontSize: 12,
            color: theme.primaryText,
          ),
          floatingLabelStyle: GoogleFonts.inter(
            fontSize: 12,
            color: theme.primaryText,
          ),
          filled: true,
          fillColor: theme.secondaryBackground,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: theme.primary, width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        isExpanded: true,
        hint: Text(
          hint,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: theme.primaryText,
          ),
        ),
        items: items,
        onChanged: onChanged,
        style: GoogleFonts.inter(
          fontSize: 14,
          color: theme.primaryText,
        ),
        iconEnabledColor: theme.primaryText,
        dropdownColor: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _buildTotalInfo(FlutterFlowTheme theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: theme.alternate.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 14, color: theme.secondaryText),
            const SizedBox(width: 6),
            Text(
              'Total: $_totalServidor medições',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget(FlutterFlowTheme theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 20, color: theme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _error!,
                style: GoogleFonts.inter(fontSize: 13, color: theme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(FlutterFlowTheme theme) {
    if (_loading && _items.isEmpty) {
      return _buildLoadingState(theme);
    }

    return RefreshIndicator(
      onRefresh: () => _carregarMedicoes(reset: true),
      color: theme.primary,
      child: _items.isEmpty
          ? _buildEmptyState(theme)
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(12, 2, 12, 16),
              itemCount: _items.length + (_loadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return _buildLoadingMoreIndicator(theme);
                }
                return _buildMedicaoCard(theme, _items[index]);
              },
            ),
    );
  }

  Widget _buildLoadingState(FlutterFlowTheme theme) {
    return Center(
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
            'Carregando medições...',
            style: GoogleFonts.inter(fontSize: 14, color: theme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(FlutterFlowTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: theme.alternate.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Nenhuma medição encontrada',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tente ajustar os filtros ou cadastrar uma nova medição.',
            style: GoogleFonts.inter(fontSize: 14, color: theme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingMoreIndicator(FlutterFlowTheme theme) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.primary,
          ),
        ),
      ),
    );
  }

  Widget _buildMedicaoCard(FlutterFlowTheme theme, Map<String, dynamic> m) {
    final numero = m['numero']?.toString() ?? '—';
    final cor = _corStatusChip(context, m);
    final sid = _statusId(m);
    final enviandoEsta = _enviandoAprovacaoMedicaoId == _toInt(m['id']);
    final statusLabel = _labelStatus(m);
    final borderColor = theme.primaryText.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _abrirDetalhes(m),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.secondaryBackground,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 3.5, color: cor),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(9, 5, 4, 5),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        theme.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Med. #$numero',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: theme.primary,
                                      height: 1,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _buildStatusChipMini(
                                  theme,
                                  label: statusLabel,
                                  color: cor,
                                  statusId: sid,
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              _obraNome(m),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                height: 1.15,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _metaCompacta(m),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                height: 1.1,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 6, 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (sid == 1)
                            _buildIconAction(
                              theme,
                              icon: Icons.send_rounded,
                              tooltip: 'Enviar para aprovação',
                              onPressed: enviandoEsta
                                  ? null
                                  : () => _enviarParaAprovacao(m),
                              loading: enviandoEsta,
                              color: Colors.green.shade700,
                            ),
                          if (sid == 1) const SizedBox(height: 4),
                          _buildIconAction(
                            theme,
                            icon: Icons.visibility_outlined,
                            tooltip: 'Detalhes',
                            onPressed: () => _abrirDetalhes(m),
                          ),
                        ],
                      ),
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

  Widget _buildStatusChipMini(
    FlutterFlowTheme theme, {
    required String label,
    required Color color,
    required int? statusId,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (statusId == 2)
            Icon(Icons.hourglass_top, size: 10, color: color),
          if (statusId == 3)
            Icon(Icons.check_circle, size: 10, color: color),
          if (statusId == 4) Icon(Icons.cancel, size: 10, color: color),
          if (statusId == 2 || statusId == 3 || statusId == 4)
            const SizedBox(width: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: color,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconAction(
    FlutterFlowTheme theme, {
    required IconData icon,
    required VoidCallback? onPressed,
    String? tooltip,
    bool loading = false,
    Color? color,
  }) {
    final fg = color ?? theme.primary;
    final btn = Material(
      color: theme.alternate.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 26,
          height: 26,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(5),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              : Icon(icon, size: 14, color: fg),
        ),
      ),
    );
    if (tooltip == null) return btn;
    return Tooltip(message: tooltip, child: btn);
  }
}

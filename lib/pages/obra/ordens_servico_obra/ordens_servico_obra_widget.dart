import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart' show SQLiteManager;
import '/backend/sqlite/queries/read.dart'
    show GetOrdensServicoRow, GetTarefasOrdemRow;
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'ordens_servico_obra_model.dart';
export 'ordens_servico_obra_model.dart';

String _formatOrdemServicoDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '—';
  if (s.contains('/')) return s.split(' ').first;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(s)) {
    try {
      final d = DateTime.parse(s.substring(0, 10));
      return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    } catch (_) {}
  }
  return s;
}

/// Ordem + tarefas (SQLite não retorna tarefas embutidas em [GetOrdensServicoRow]).
class _OrdemComTarefas {
  _OrdemComTarefas(this.ordem, this.tarefas);
  final GetOrdensServicoRow ordem;
  final List<GetTarefasOrdemRow> tarefas;
}

String _labelSituacaoOrdemServico(int situacao) {
  switch (situacao) {
    case 1:
      return 'Preenchendo';
    case 2:
      return 'Aguardando';
    case 3:
      return 'Aprovado';
    case 4:
      return 'Reprovado';
    default:
      return 'Situação $situacao';
  }
}

Color _corSituacaoOrdemServico(int situacao) {
  switch (situacao) {
    case 1:
      return const Color(0xFF2196F3);
    case 2:
      return const Color(0xFF7B1FA2);
    case 3:
      return const Color(0xFF2E7D32);
    case 4:
      return const Color(0xFFC62828);
    default:
      return Colors.grey;
  }
}

String _tituloOrdem(GetOrdensServicoRow ordem) {
  final nome = ordem.nome?.trim() ?? '';
  if (nome.isNotEmpty) return nome;
  final obs = ordem.observacoes?.trim() ?? '';
  if (obs.isNotEmpty) return obs;
  return 'Ordem de serviço';
}

class OrdensServicoObraWidget extends StatefulWidget {
  const OrdensServicoObraWidget({
    super.key,
    required this.obraId,
    required this.obraUuid,
  });

  final int? obraId;
  final String? obraUuid;

  static String routeName = 'ordensServicoObra';
  static String routePath = '/ordensServicoObra';

  @override
  State<OrdensServicoObraWidget> createState() =>
      _OrdensServicoObraWidgetState();
}

class _OrdensServicoObraWidgetState extends State<OrdensServicoObraWidget> {
  late OrdensServicoObraModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<String> _expandedOrdens = {};

  String _obraNome = '';
  late Future<List<_OrdemComTarefas>> _ordensFuture;

  /// `null` = todas; senão filtra por [GetOrdensServicoRow.statusId].
  int? _filtroStatus;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OrdensServicoObraModel());
    _ordensFuture = _fetchOrdensComTarefas();
    _carregarNomeObra();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_ordens_servico')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar ordens de serviço.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregarNomeObra() async {
    final uuid = (widget.obraUuid ?? '').trim();
    if (uuid.isEmpty) return;
    try {
      final rows = await SQLiteManager.instance.obraDetalhes(
        uuid: uuid,
        userId: FFAppState().creatorId,
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      final nome = rows.firstOrNull?.nome.trim() ?? '';
      if (!mounted || nome.isEmpty) return;
      setState(() => _obraNome = nome);
    } catch (_) {}
  }

  Future<List<_OrdemComTarefas>> _fetchOrdensComTarefas() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) return const [];

    try {
      await actions.refreshOrdensPorObra(obraUuid: obraUuid);
      await actions.syncOrdensTarefas();
    } catch (_) {}

    final ordens = await SQLiteManager.instance.getOrdensServico(
      obraUuid: obraUuid,
      userId: FFAppState().creatorId,
    );
    final out = <_OrdemComTarefas>[];
    for (final o in ordens) {
      final tarefas = await SQLiteManager.instance.getTarefasOrdem(
        ordemUuid: o.uuid,
      );
      out.add(_OrdemComTarefas(o, tarefas));
    }
    return out;
  }

  Future<void> _refresh() async {
    setState(() {
      _ordensFuture = _fetchOrdensComTarefas();
    });
    await _ordensFuture;
  }

  void _voltarParaDetalhes() {
    context.pushNamed(
      DetalhesObraWidget.routeName,
      queryParameters: {
        'obraId': serializeParam(widget.obraId, ParamType.int),
        'obraUuid': serializeParam(widget.obraUuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
  }

  void _abrirDetalhes(GetOrdensServicoRow ordem) {
    context.pushNamed(
      OrdemServicoDetalhesWidget.routeName,
      queryParameters: {
        'ordemUuid': serializeParam(ordem.uuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        '__transition_info__': const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
  }

  double _calcularProgressoOrdem(List<GetTarefasOrdemRow> tarefas) {
    if (tarefas.isEmpty) return 0;
    double totalRealizada = 0;
    double totalProgramada = 0;
    for (final t in tarefas) {
      totalProgramada += (t.qtdProgramada ?? 0);
      totalRealizada += (t.qtdRealizada ?? 0);
    }
    if (totalProgramada == 0) return 0;
    return (totalRealizada / totalProgramada) * 100;
  }

  double _calcularProgressoTarefa(GetTarefasOrdemRow tarefa) {
    final programada = tarefa.qtdProgramada ?? 0;
    final realizada = tarefa.qtdRealizada ?? 0;
    if (programada == 0) return 0;
    return (realizada / programada) * 100;
  }

  Color _getStatusTarefaColor(double progresso) {
    if (progresso >= 100) return const Color(0xFF2E7D32);
    if (progresso > 0) return const Color(0xFFEF6C00);
    return const Color(0xFF757575);
  }

  String _getStatusTarefaTexto(double progresso) {
    if (progresso >= 100) return 'Concluída';
    if (progresso > 0) return 'Em andamento';
    return 'Não iniciada';
  }

  String _formatNumero(dynamic valor) {
    if (valor == null) return '0';
    final n = double.tryParse(valor.toString());
    if (n == null) return valor.toString();
    return n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
  }

  List<_OrdemComTarefas> _aplicarFiltro(List<_OrdemComTarefas> todas) {
    final f = _filtroStatus;
    if (f == null) return todas;
    return todas.where((e) => e.ordem.statusId == f).toList();
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
            onPressed: _voltarParaDetalhes,
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ordens de Serviço',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _obraNome.isEmpty
                      ? 'Planejamento e execução da obra'
                      : _obraNome,
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
            Expanded(child: _body(theme)),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _body(FlutterFlowTheme theme) {
    final u = (widget.obraUuid ?? '').trim();
    if (u.isEmpty) {
      return Center(
        child: Text(
          'Obra sem identificador.',
          style: GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
        ),
      );
    }

    return RefreshIndicator(
      color: theme.primary,
      onRefresh: _refresh,
      child: FutureBuilder<List<_OrdemComTarefas>>(
        future: _ordensFuture,
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
                  'Erro ao carregar ordens',
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

          final todas = snapshot.data ?? const <_OrdemComTarefas>[];
          final filtradas = _aplicarFiltro(todas);

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
              if (todas.isNotEmpty) ...[
                _buildResumoCard(theme, todas),
                const SizedBox(height: 10),
                _buildFiltros(theme, todas),
                const SizedBox(height: 10),
              ],
              RdoSectionCard(
                title: 'Lista de ordens',
                icon: Icons.assignment_outlined,
                subtitle: todas.isEmpty
                    ? 'Nenhuma ordem nesta obra'
                    : filtradas.length == todas.length
                        ? 'Toque para abrir os detalhes'
                        : '${filtradas.length} de ${todas.length} exibidas',
                margin: EdgeInsets.zero,
                trailing: filtradas.isEmpty
                    ? null
                    : RdoContadorChip('${filtradas.length}'),
                contentPadding: EdgeInsets.zero,
                child: filtradas.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 40,
                              color:
                                  theme.secondaryText.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              todas.isEmpty
                                  ? 'Nenhuma ordem de serviço'
                                  : 'Nenhuma ordem neste filtro',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              todas.isEmpty
                                  ? 'As ordens sincronizadas desta obra aparecem aqui.'
                                  : 'Altere o filtro de status para ver outras ordens.',
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
                          for (var i = 0; i < filtradas.length; i++) ...[
                            if (i > 0)
                              Divider(
                                height: 1,
                                thickness: 1,
                                color: theme.alternate,
                              ),
                            _buildOrdemItem(theme, filtradas[i]),
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

  Widget _buildResumoCard(
    FlutterFlowTheme theme,
    List<_OrdemComTarefas> todas,
  ) {
    var aprovadas = 0;
    var aguardando = 0;
    var preenchendo = 0;
    var reprovadas = 0;
    for (final o in todas) {
      switch (o.ordem.statusId) {
        case 3:
          aprovadas++;
          break;
        case 2:
          aguardando++;
          break;
        case 4:
          reprovadas++;
          break;
        default:
          preenchendo++;
      }
    }

    return RdoSectionCard(
      title: 'Resumo',
      icon: Icons.insights_outlined,
      margin: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      child: RdoKpiStrip(
        itens: [
          RdoKpiData(label: 'Total', value: '${todas.length}', destaque: true),
          RdoKpiData(label: 'Aprovadas', value: '$aprovadas'),
          RdoKpiData(
            label: 'Pendentes',
            value: '${aguardando + preenchendo}',
            hint: reprovadas > 0 ? '$reprovadas reprovada(s)' : null,
          ),
        ],
      ),
    );
  }

  Widget _buildFiltros(
    FlutterFlowTheme theme,
    List<_OrdemComTarefas> todas,
  ) {
    int count(int? status) {
      if (status == null) return todas.length;
      return todas.where((e) => e.ordem.statusId == status).length;
    }

    Widget chip(String label, int? status) {
      final selected = _filtroStatus == status;
      final n = count(status);
      final cor = status == null
          ? theme.primary
          : _corSituacaoOrdemServico(status);
      return FilterChip(
        selected: selected,
        showCheckmark: false,
        label: Text(
          '$label ($n)',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : theme.primaryText,
          ),
        ),
        selectedColor: cor,
        backgroundColor: theme.secondaryBackground,
        side: BorderSide(
          color: selected ? cor : theme.alternate,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 2),
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onSelected: (_) {
          setState(() => _filtroStatus = status);
        },
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          chip('Todas', null),
          const SizedBox(width: 6),
          chip('Preenchendo', 1),
          const SizedBox(width: 6),
          chip('Aguardando', 2),
          const SizedBox(width: 6),
          chip('Aprovado', 3),
          const SizedBox(width: 6),
          chip('Reprovado', 4),
        ],
      ),
    );
  }

  Widget _buildOrdemItem(FlutterFlowTheme theme, _OrdemComTarefas com) {
    final ordem = com.ordem;
    final tarefas = com.tarefas;
    final statusId = ordem.statusId;
    final corStatus = _corSituacaoOrdemServico(statusId);
    final progresso = _calcularProgressoOrdem(tarefas);
    final uuid = ordem.uuid;
    final expanded = _expandedOrdens.contains(uuid);
    final titulo = _tituloOrdem(ordem);

    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: () => _abrirDetalhes(ordem),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3, color: corStatus),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      ordem.codigo,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.2,
                                        color: theme.secondaryText,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      titulo,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w700,
                                        color: theme.primaryText,
                                        height: 1.25,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: corStatus.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: corStatus.withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Text(
                                  _labelSituacaoOrdemServico(statusId),
                                  style: GoogleFonts.inter(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: corStatus,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.event_outlined,
                                  size: 13, color: theme.secondaryText),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${_formatOrdemServicoDate(ordem.dataInicio)}'
                                  ' → '
                                  '${_formatOrdemServicoDate(ordem.dataFim)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                              Text(
                                '${tarefas.length} tarefa${tarefas.length == 1 ? '' : 's'}',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: (progresso / 100).clamp(0.0, 1.0),
                                    minHeight: 6,
                                    backgroundColor:
                                        theme.alternate.withValues(alpha: 0.7),
                                    color: progresso >= 100
                                        ? const Color(0xFF2E7D32)
                                        : theme.primary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${progresso.toStringAsFixed(0)}%',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: progresso >= 100
                                      ? const Color(0xFF2E7D32)
                                      : theme.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Abrir detalhes',
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primary,
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded,
                                  size: 16, color: theme.primary),
                              const Spacer(),
                              if (tarefas.isNotEmpty)
                                InkWell(
                                  borderRadius: BorderRadius.circular(6),
                                  onTap: () {
                                    setState(() {
                                      if (expanded) {
                                        _expandedOrdens.remove(uuid);
                                      } else {
                                        _expandedOrdens.add(uuid);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          expanded
                                              ? 'Ocultar tarefas'
                                              : 'Ver tarefas',
                                          style: GoogleFonts.inter(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.w500,
                                            color: theme.secondaryText,
                                          ),
                                        ),
                                        Icon(
                                          expanded
                                              ? Icons.expand_less_rounded
                                              : Icons.expand_more_rounded,
                                          size: 18,
                                          color: theme.secondaryText,
                                        ),
                                      ],
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
            if (expanded && tarefas.isNotEmpty)
              _buildTarefasPreview(theme, tarefas),
          ],
        ),
      ),
    );
  }

  Widget _buildTarefasPreview(
    FlutterFlowTheme theme,
    List<GetTarefasOrdemRow> tarefas,
  ) {
    return Container(
      width: double.infinity,
      color: theme.primaryBackground.withValues(alpha: 0.55),
      padding: const EdgeInsets.fromLTRB(15, 0, 12, 12),
      child: Column(
        children: [
          for (var i = 0; i < tarefas.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _buildTarefaMini(theme, tarefas[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTarefaMini(
    FlutterFlowTheme theme,
    GetTarefasOrdemRow tarefa,
  ) {
    final progresso = _calcularProgressoTarefa(tarefa);
    final cor = _getStatusTarefaColor(progresso);
    final unidade = (tarefa.unidade ?? '').trim();

    return Container(
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.alternate),
      ),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 28,
                decoration: BoxDecoration(
                  color: cor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tarefa.nome ?? 'Tarefa',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _getStatusTarefaTexto(progresso),
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: cor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Prog. ${_formatNumero(tarefa.qtdProgramada)}'
                  '${unidade.isEmpty ? '' : ' $unidade'}',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Real. ${_formatNumero(tarefa.qtdRealizada)}'
                  '${unidade.isEmpty ? '' : ' $unidade'}',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (progresso / 100).clamp(0.0, 1.0),
              minHeight: 4,
              backgroundColor: theme.alternate,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }
}

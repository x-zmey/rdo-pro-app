import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'ordens_servico_obra_model.dart';
export 'ordens_servico_obra_model.dart';

String _formatOrdemServicoDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return '---';
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
      return 'Aguardando Aprovação';
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
      return const Color(0xFF6200EE);
    case 3:
      return const Color(0xFF4CAF50);
    case 4:
      return const Color(0xFFE53935);
    default:
      return Colors.grey;
  }
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

class _OrdensServicoObraWidgetState extends State<OrdensServicoObraWidget>
    with SingleTickerProviderStateMixin {
  late OrdensServicoObraModel _model;
  late AnimationController _animationController;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _expandedOrdens = {};

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OrdensServicoObraModel());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
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
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<List<_OrdemComTarefas>> _fetchOrdensComTarefas() async {
    final ordens = await SQLiteManager.instance.getOrdensServico(
      obraUuid: widget.obraUuid!,
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
        appBar: _buildAppBar(theme),
        body: FadeTransition(
          opacity: _animationController,
          child: _buildBody(theme),
        ),
        bottomNavigationBar: const BarraNavegacaoPrincipal(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(FlutterFlowTheme theme) {
    return AppBar(
      backgroundColor: Colors.transparent,
      toolbarHeight: 52,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: Container(
        margin: const EdgeInsets.only(left: 10),
        decoration: BoxDecoration(
          color: theme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.primary, size: 20),
          onPressed: () {
            context.pushNamed(
              DetalhesObraWidget.routeName,
              queryParameters: {
                'obraId': serializeParam(widget.obraId, ParamType.int),
                'obraUuid': serializeParam(widget.obraUuid, ParamType.String),
              }.withoutNulls,
            );
          },
        ),
      ),
      title: Text(
        'Ordens de Serviço',
        style: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: theme.primaryText,
          letterSpacing: -0.3,
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 10),
          decoration: BoxDecoration(
            color: theme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.primary, size: 20),
            onPressed: () => setState(() {}),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(FlutterFlowTheme theme) {
    return SafeArea(
      top: true,
      child: FutureBuilder<List<_OrdemComTarefas>>(
        future: _fetchOrdensComTarefas(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return _buildLoadingState(theme);
          }

          if (snapshot.hasError) {
            return _buildErrorState(theme, snapshot.error.toString());
          }

          final ordens = snapshot.data!;

          if (ordens.isEmpty) {
            return _buildEmptyState(theme);
          }

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  kBarraNavegacaoPrincipalReservaScroll,
                ),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final com = ordens[index];
                      final ordem = com.ordem;
                      final tarefas = com.tarefas;
                      final isExpanded = _expandedOrdens.contains(index);
                      final situacaoOrdem = ordem.statusId;
                      final corSituacaoOrdem =
                          _corSituacaoOrdemServico(situacaoOrdem);
                      final progresso = _calcularProgressoOrdem(tarefas);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          children: [
                            _buildOrdemCard(
                              theme,
                              context,
                              ordem,
                              tarefas,
                              isExpanded,
                              corSituacaoOrdem,
                              situacaoOrdem,
                              progresso,
                              index,
                            ),
                            if (isExpanded && tarefas.isNotEmpty)
                              _buildTarefasList(context, theme, tarefas),
                          ],
                        ),
                      );
                    },
                    childCount: ordens.length,
                  ),
                ),
              ),
            ],
          );
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
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: theme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 24),
          Text(
            'Carregando ordens',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aguarde um momento...',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(FlutterFlowTheme theme, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(Icons.error_outline_rounded,
                  size: 40, color: theme.error),
            ),
            const SizedBox(height: 24),
            Text(
              'Erro ao carregar',
              style: GoogleFonts.inter(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(FlutterFlowTheme theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.alternate.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Icon(
              Icons.assignment_outlined,
              size: 50,
              color: theme.secondaryText,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Nenhuma ordem de serviço',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Não há ordens de serviço cadastradas para esta obra.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: theme.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdemCard(
    FlutterFlowTheme theme,
    BuildContext context,
    GetOrdensServicoRow ordem,
    List<GetTarefasOrdemRow> tarefas,
    bool isExpanded,
    Color corSituacaoOrdem,
    int situacaoOrdem,
    double progresso,
    int index,
  ) {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_expandedOrdens.contains(index)) {
            _expandedOrdens.remove(index);
          } else {
            _expandedOrdens.add(index);
          }
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: theme.secondaryBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                if (_expandedOrdens.contains(index)) {
                  _expandedOrdens.remove(index);
                } else {
                  _expandedOrdens.add(index);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: theme.secondaryText,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              (ordem.observacoes != null &&
                                      ordem.observacoes!.trim().isNotEmpty)
                                  ? ordem.observacoes!.trim()
                                  : 'Ordem de serviço',
                              style: GoogleFonts.inter(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: corSituacaoOrdem.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: corSituacaoOrdem.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _labelSituacaoOrdemServico(situacaoOrdem),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: corSituacaoOrdem,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 14, color: theme.secondaryText),
                      const SizedBox(width: 6),
                      Text(
                        'Início: ${_formatOrdemServicoDate(ordem.dataInicio)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.secondaryText,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.calendar_today,
                          size: 14, color: theme.secondaryText),
                      const SizedBox(width: 6),
                      Text(
                        'Fim: ${_formatOrdemServicoDate(ordem.dataFim)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progresso',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: theme.secondaryText,
                            ),
                          ),
                          Text(
                            '${progresso.toStringAsFixed(1)}%',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: progresso >= 100
                                  ? Colors.green.shade700
                                  : theme.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progresso / 100,
                          minHeight: 8,
                          backgroundColor:
                              theme.alternate.withValues(alpha: 0.5),
                          color: progresso >= 100
                              ? Colors.green.shade700
                              : theme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        context.pushNamed(
                          OrdemServicoDetalhesWidget.routeName,
                          queryParameters: {
                            'ordemUuid': serializeParam(
                              ordem.uuid,
                              ParamType.String,
                            ),
                          }.withoutNulls,
                          extra: <String, dynamic>{
                            '__transition_info__': TransitionInfo(
                              hasTransition: true,
                              transitionType: PageTransitionType.rightToLeft,
                            ),
                          },
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: theme.primaryBackground,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.visibility_outlined, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Ver detalhes',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.alternate.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.task_alt,
                                  size: 16, color: theme.primary),
                              const SizedBox(width: 6),
                              Text(
                                '${tarefas.length} tarefas',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (tarefas.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isExpanded ? Icons.expand_less : Icons.expand_more,
                          size: 20,
                          color: theme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isExpanded ? 'Ocultar tarefas' : 'Ver tarefas',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTarefasList(
    BuildContext context,
    FlutterFlowTheme theme,
    List<GetTarefasOrdemRow> tarefas,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.alternate.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Tarefas da Ordem',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
              ),
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: tarefas.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tarefa = tarefas[index];
              final progressoTarefa = _calcularProgressoTarefa(tarefa);

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context)
                        .dividerColor
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 4,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _getStatusTarefaColor(progressoTarefa),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tarefa.nome ?? 'Tarefa',
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: theme.primaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusTarefaColor(progressoTarefa)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _getStatusTarefaTexto(progressoTarefa),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getStatusTarefaColor(progressoTarefa),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoTarefa(
                            theme,
                            'Quantidade Programada',
                            '${_formatNumero(tarefa.qtdProgramada)} ${tarefa.unidade ?? ''}',
                            Icons.assignment_turned_in,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildInfoTarefa(
                            theme,
                            'Quantidade Realizada',
                            '${_formatNumero(tarefa.qtdRealizada)} ${tarefa.unidade ?? ''}',
                            Icons.check_circle_outline,
                            highlight: true,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progresso da tarefa',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: theme.secondaryText,
                              ),
                            ),
                            Text(
                              '${progressoTarefa.toStringAsFixed(1)}%',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: progressoTarefa >= 100
                                    ? Colors.green.shade700
                                    : theme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progressoTarefa / 100,
                            minHeight: 6,
                            backgroundColor: theme.alternate,
                            color: progressoTarefa >= 100
                                ? Colors.green.shade700
                                : theme.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTarefa(
    FlutterFlowTheme theme,
    String label,
    String value,
    IconData icon, {
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: highlight
            ? theme.primary.withValues(alpha: 0.05)
            : theme.alternate.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: theme.secondaryText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: theme.secondaryText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w700 : FontWeight.w600,
              color: highlight ? theme.primary : theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }

  double _calcularProgressoTarefa(GetTarefasOrdemRow tarefa) {
    final programada = tarefa.qtdProgramada ?? 0;
    final realizada = tarefa.qtdRealizada ?? 0;
    if (programada == 0) return 0;
    return (realizada / programada) * 100;
  }

  Color _getStatusTarefaColor(double progresso) {
    if (progresso >= 100) return const Color(0xFF4CAF50);
    if (progresso > 0) return const Color(0xFFFF9800);
    return const Color(0xFF9E9E9E);
  }

  String _getStatusTarefaTexto(double progresso) {
    if (progresso >= 100) return 'Concluída';
    if (progresso > 0) return 'Em andamento';
    return 'Não iniciada';
  }

  String _formatNumero(dynamic valor) {
    if (valor == null) return '0';
    final num = double.tryParse(valor.toString());
    if (num == null) return valor.toString();
    return num.toStringAsFixed(num.truncateToDouble() == num ? 0 : 2);
  }
}

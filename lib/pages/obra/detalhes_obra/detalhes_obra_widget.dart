import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/permission/permission_gate.dart';
import '/componentes/relatorios/relatorio_list_item_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/ensure_obras_fotos_locais.dart';
import '/custom_code/actions/obra_foto_url.dart';
import '/custom_code/actions/sync_push_runner.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

      // Capa offline: se o servidor tem foto e o SQLite não tem arquivo local.
      try {
        final baixadas = await ensureObrasFotosLocais();
        if (baixadas > 0 && mounted) {
          await _reloadObraFromSqlite();
          safeSetState(() {});
        }
      } catch (e) {
        debugPrint('Erro ao garantir capa da obra: $e');
      }

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
    final theme = FlutterFlowTheme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : 6),
          child: Container(
            width: double.infinity,
            decoration: rdoCardDecoration(context),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 3.5, color: theme.alternate),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              _shimmerBox(context, width: 72, height: 14),
                              const Spacer(),
                              _shimmerBox(
                                context,
                                width: 64,
                                height: 18,
                                radius: 10,
                              ),
                              const SizedBox(width: 6),
                              _shimmerBox(
                                context,
                                width: 28,
                                height: 28,
                                radius: 7,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _shimmerBox(context, width: 160, height: 11),
                        ],
                      ),
                    ),
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
          Builder(
            builder: (ctx) {
              final row = rows[i];
              final dataExec =
                  formatDataResumoRelatorio(row.dataExecutado);
              final dataLabel =
                  dataExec.isNotEmpty ? dataExec : row.dataExecutado;
              final criador =
                  nomeExibicaoCriadorRelatorio(row.criadorNome, row.criador);

              return RelatorioListItemWidget(
                numero: row.numero,
                dataLabel: dataLabel,
                statusId: row.statusId,
                statusLabel: labelRelatorioStatus(
                  statusId: row.statusId,
                  statusNome: row.statusNome,
                ),
                criador: criador,
                marginBottom: i == rows.length - 1 ? 0 : 6,
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

  /// Atalhos compactos no estilo da identidade RDO.
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
    final cell = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => runWithPermission(
          context,
          permission: permission,
          permissions: permissions,
          onAllowed: onTap,
        ),
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: t.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: t.alternate),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  allowed ? icon : Icons.lock_outline,
                  color: t.primary,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w600,
                    color: t.primaryText,
                    fontSize: 9.5,
                    height: 1.1,
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

  String _dataBr(String? raw) {
    final s = (raw ?? '').trim();
    if (s.isEmpty) return '';
    if (RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(s)) return s;
    final formatado = _formatDataResumo(s);
    return formatado.isEmpty ? s : formatado;
  }

  String _obraCidadeUf(ObraDetalhesRow? o) {
    if (o == null) return '';
    final c = o.cidade?.trim();
    final e = (o.estado ?? '').trim();
    final uf = e.length >= 2 ? e.substring(0, 2).toUpperCase() : e;
    if ((c ?? '').isNotEmpty && uf.isNotEmpty) return '$c / $uf';
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
    if (mounted) {
      await _reloadObraFromSqlite();
      safeSetState(() {});
    }
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

  Widget _capaObraImage(ObraDetalhesRow? obra, Color accent) {
    final local = (obra?.fotoLocal ?? '').trim();
    final remoto = (obra?.foto ?? '').trim();

    Widget placeholder() => Container(
          color: accent.withValues(alpha: 0.12),
          alignment: Alignment.center,
          child: Icon(Icons.domain_rounded, size: 48, color: accent),
        );

    if (local.isNotEmpty && !local.startsWith('http')) {
      try {
        final arquivo = local.startsWith('file://')
            ? File.fromUri(Uri.parse(local))
            : File(local);
        if (arquivo.existsSync()) {
          return Image.file(
            arquivo,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => placeholder(),
          );
        }
      } catch (_) {}
    }

    final url = resolveObraFotoNetworkUrl(foto: remoto) ??
        (local.startsWith('http') ? local : '');
    if (url.isNotEmpty) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    }
    return placeholder();
  }

  Widget _parInfo(
    String label1,
    String valor1,
    String label2,
    String valor2, {
    int flexEsquerda = 3,
    int flexDireita = 2,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: flexEsquerda, child: _campoInfo(label1, valor1)),
        const SizedBox(width: 12),
        Expanded(flex: flexDireita, child: _campoInfo(label2, valor2)),
      ],
    );
  }

  Widget _campoInfo(String label, String valor) {
    final theme = FlutterFlowTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: rdoColumnLabelStyle(context)),
        const SizedBox(height: 2),
        Text(
          valor.trim().isEmpty ? '—' : valor.trim(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: theme.primaryText,
          ),
        ),
      ],
    );
  }

  String _diasLabel(int? dias) {
    if (dias == null) return '—';
    return '$dias d';
  }

  Widget _buildCapaHeader({
    required ObraDetalhesRow? obra,
    required String situacaoNome,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final nome = valueOrDefault<String>(obra?.nome, 'Obra');

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      clipBehavior: Clip.antiAlias,
      decoration: rdoCardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 168,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _capaObraImage(obra, theme.primary),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                      stops: const [0.35, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (situacaoNome.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            situacaoNome,
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      Text(
                        nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.interTight(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                    top: 8,
                    right: 8,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: _abrirEditarObra,
                        child: Padding(
                          padding: const EdgeInsets.all(7),
                          child: Icon(
                            MembershipAccess.canPermission('edit_obras')
                                ? Icons.edit_outlined
                                : Icons.lock_outline,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
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

  Widget _buildInformacoesObra({
    required ObraDetalhesRow? obra,
    required String clienteNome,
    required _ObraPrazosInfo prazos,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final endereco = _obraEnderecoLinha(obra);
    final cidade = _obraCidadeUf(obra);
    final decorrido = prazos.porcentagemDecorrida?.clamp(0, 100).toDouble() ?? 0;
    final aVencerLabel = prazos.valido
        ? (prazos.prazoAVencer < 0
            ? '${prazos.prazoAVencer.abs()} d'
            : _diasLabel(prazos.prazoAVencer))
        : '—';

    return RdoSectionCard(
      title: 'Informações da Obra',
      icon: Icons.apartment_rounded,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              children: [
                _parInfo(
                  'Cliente',
                  clienteNome,
                  'Contrato',
                  (obra?.contrato ?? '').trim(),
                ),
                const SizedBox(height: 8),
                _parInfo(
                  'Encarregado',
                  (obra?.engenheiro ?? '').trim(),
                  'Progresso do prazo',
                  prazos.valido ? '${decorrido.round()}%' : '—',
                ),
                const SizedBox(height: 8),
                _parInfo(
                  'Início da obra',
                  _dataBr(obra?.dataInicio),
                  'Fim da obra',
                  _dataBr(obra?.dataFinal),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: theme.alternate),
              ),
            ),
            child: RdoKpiStrip(
              itens: [
                RdoKpiData(
                  label: 'Prazo contratual',
                  value: prazos.valido
                      ? _diasLabel(prazos.prazoContratual)
                      : '—',
                ),
                RdoKpiData(
                  label: 'Decorrido',
                  value: prazos.valido
                      ? _diasLabel(prazos.prazoDecorrido)
                      : '—',
                ),
                RdoKpiData(
                  label: 'A vencer',
                  value: aVencerLabel,
                  destaque: true,
                ),
              ],
            ),
          ),
          if (prazos.valido)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: decorrido / 100,
                  minHeight: 5,
                  backgroundColor: theme.alternate,
                  color: decorrido >= 100 ? theme.error : theme.primary,
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: theme.alternate)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 14, color: theme.secondaryText),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        endereco.isEmpty ? 'Endereço não informado' : endereco,
                        style: GoogleFonts.inter(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: theme.primaryText,
                        ),
                      ),
                      if (cidade.isNotEmpty)
                        Text(
                          cidade,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.secondaryText,
                          ),
                        ),
                    ],
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

    return FutureBuilder<List<ObraDetalhesRow>>(
      future: SQLiteManager.instance.obraDetalhes(
        uuid: widget.obraUuid!,
        userId: FFAppState().creatorId,
        accountOwnerUuid: FFAppState().creatorUuid,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
            body: Center(
              child: CircularProgressIndicator(
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
          );
        }
        final detalhesObraObraDetalhesRowList = snapshot.data!;
        final obra = detalhesObraObraDetalhesRowList.firstOrNull;
        final theme = FlutterFlowTheme.of(context);
        final bottomInset = MediaQuery.paddingOf(context).bottom;
        final obraNome = valueOrDefault<String>(obra?.nome, 'Obra');

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
                      'Detalhes da Obra',
                      style: GoogleFonts.interTight(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      obraNome,
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
                  tooltip: 'Editar obra',
                  icon: Icon(
                    MembershipAccess.canPermission('edit_obras')
                        ? Icons.edit_outlined
                        : Icons.lock_outline,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: _abrirEditarObra,
                ),
                const SizedBox(width: 4),
              ],
            ),
            body: Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: FutureBuilder<_ObraHeaderExtras>(
                    future: _loadHeaderExtras(obra),
                    builder: (context, snapExtras) {
                      final extras = snapExtras.data;
                      final clienteNome = extras?.clienteNome?.trim() ?? '';
                      final situacaoNome = extras?.situacaoNome?.trim() ?? '';
                      final prazos = _calcularPrazosObra(
                        obra?.dataInicio,
                        obra?.dataFinal,
                      );

                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: kBarraNavegacaoPrincipalReservaScroll +
                              bottomInset,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildCapaHeader(
                              obra: obra,
                              situacaoNome: situacaoNome,
                            ),
                            _buildInformacoesObra(
                              obra: obra,
                              clienteNome: clienteNome,
                              prazos: prazos,
                            ),
                            FutureBuilder<List<GetIdServidorRow>>(
                              future: SQLiteManager.instance.getIdServidor(
                                tabela: 'obras',
                                uuid: obra?.uuid,
                              ),
                              builder: (context, snapId) {
                                final idServidor =
                                    snapId.data?.firstOrNull?.idServidor;
                                return RdoSectionCard(
                                  title: 'Atalhos da obra',
                                  icon: Icons.grid_view_rounded,
                                  margin: const EdgeInsets.fromLTRB(
                                    16,
                                    10,
                                    16,
                                    0,
                                  ),
                                  contentPadding: const EdgeInsets.fromLTRB(
                                    10,
                                    10,
                                    10,
                                    10,
                                  ),
                                  child: GridView(
                                    padding: EdgeInsets.zero,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 4,
                                      crossAxisSpacing: 6,
                                      mainAxisSpacing: 6,
                                      childAspectRatio: 1.15,
                                    ),
                                    primary: false,
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    children: [
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.construction,
                                        label: 'Equipamentos',
                                        permission: 'view_equipamentos',
                                        onTap: () {
                                          context.pushNamed(
                                            EquipamentosObraWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              '__transition_info__':
                                                  const TransitionInfo(
                                                hasTransition: true,
                                                transitionType:
                                                    PageTransitionType
                                                        .bottomToTop,
                                              ),
                                            },
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.assignment,
                                        label: 'Tarefas',
                                        permission: 'view_tarefas',
                                        onTap: () {
                                          context.pushNamed(
                                            ObraTarefasWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              '__transition_info__':
                                                  const TransitionInfo(
                                                hasTransition: true,
                                                transitionType:
                                                    PageTransitionType
                                                        .bottomToTop,
                                              ),
                                            },
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.warning_amber_rounded,
                                        label: 'Ocorrências',
                                        permission: 'view_ocorrencias',
                                        onTap: () {
                                          context.pushNamed(
                                            OcorrenciasObraWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.comment_outlined,
                                        label: 'Comentários',
                                        permission: 'view_comentarios',
                                        onTap: () {
                                          context.pushNamed(
                                            ComentariosObraNovoWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.place_rounded,
                                        label: 'Locais',
                                        permission: 'view_cadastros_gerais',
                                        onTap: () {
                                          context.pushNamed(
                                            LocaisObraWidget.routeName,
                                            queryParameters: {
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              '__transition_info__':
                                                  const TransitionInfo(
                                                hasTransition: true,
                                                transitionType:
                                                    PageTransitionType
                                                        .bottomToTop,
                                              ),
                                            },
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.inventory_2_outlined,
                                        label: 'Insumos',
                                        permission: 'view_insumos',
                                        onTap: () {
                                          context.pushNamed(
                                            InsumosObraWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              '__transition_info__':
                                                  const TransitionInfo(
                                                hasTransition: true,
                                                transitionType:
                                                    PageTransitionType
                                                        .bottomToTop,
                                              ),
                                            },
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.groups_outlined,
                                        label: 'Mão de Obra',
                                        permission: 'view_mao_obra',
                                        onTap: () {
                                          context.pushNamed(
                                            MaoObraWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              '__transition_info__':
                                                  const TransitionInfo(
                                                hasTransition: true,
                                                transitionType:
                                                    PageTransitionType
                                                        .bottomToTop,
                                              ),
                                            },
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.post_add_rounded,
                                        label: 'Ordens',
                                        permission: 'view_ordens_servico',
                                        onTap: () {
                                          context.pushNamed(
                                            OrdensServicoObraWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                              'obraUuid': serializeParam(
                                                widget.obraUuid,
                                                ParamType.String,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              '__transition_info__':
                                                  const TransitionInfo(
                                                hasTransition: true,
                                                transitionType:
                                                    PageTransitionType
                                                        .bottomToTop,
                                              ),
                                            },
                                          );
                                        },
                                      ),
                                      _buildAtalhoCelula(
                                        context,
                                        icon: Icons.checklist_rtl_rounded,
                                        label: 'Checklists',
                                        onTap: () {
                                          context.pushNamed(
                                            ChecklistsWidget.routeName,
                                            queryParameters: {
                                              'obraId': serializeParam(
                                                idServidor,
                                                ParamType.int,
                                              ),
                                            }.withoutNulls,
                                            extra: <String, dynamic>{
                                              '__transition_info__':
                                                  const TransitionInfo(
                                                hasTransition: true,
                                                transitionType:
                                                    PageTransitionType
                                                        .bottomToTop,
                                              ),
                                            },
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            RdoSectionCard(
                              title: 'Últimos relatórios',
                              icon: Icons.description_outlined,
                              margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                              trailing: InkWell(
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
                                          widget.obraId,
                                          ParamType.int,
                                        ),
                                        'obraUuid': serializeParam(
                                          widget.obraUuid,
                                          ParamType.String,
                                        ),
                                      }.withoutNulls,
                                      extra: <String, dynamic>{
                                        '__transition_info__':
                                            const TransitionInfo(
                                          hasTransition: true,
                                          transitionType:
                                              PageTransitionType.bottomToTop,
                                        ),
                                      },
                                    );
                                  },
                                ),
                                child: Text(
                                  'Ver todos',
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: theme.primary,
                                  ),
                                ),
                              ),
                              contentPadding: const EdgeInsets.fromLTRB(
                                10,
                                8,
                                10,
                                10,
                              ),
                              child: FutureBuilder<
                                  List<RelatoriosObraUltimosRow>>(
                                future: _relatoriosFutureOrFetch(),
                                builder: (context, snapRel) {
                                  if (!snapRel.hasData) {
                                    return _buildUltimosRelatoriosShimmer(
                                      context,
                                    );
                                  }
                                  final rows = snapRel.data!;
                                  if (rows.isEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      child: Text(
                                        'Nenhum relatório nesta obra ainda.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.inter(
                                          fontSize: 12.5,
                                          color: theme.secondaryText,
                                        ),
                                      ),
                                    );
                                  }
                                  return _buildUltimosRelatoriosColumn(
                                    context,
                                    rows,
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
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


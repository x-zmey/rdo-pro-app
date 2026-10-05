import '/backend/api_requests/api_calls.dart';
import '/componentes/relatorios/relatorio_list_item_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';

import 'relatorio_detalhes_model.dart';

export 'relatorio_detalhes_model.dart';

class RelatorioDetalhesWidget extends StatefulWidget {
  const RelatorioDetalhesWidget({
    super.key,
    this.id,
    this.uuid,
    this.camufladoId,
  });

  final int? id;
  final String? uuid;
  final String? camufladoId;

  static String routeName = 'relatorioDetalhes';
  static String routePath = '/relatorioDetalhes';

  @override
  State<RelatorioDetalhesWidget> createState() =>
      _RelatorioDetalhesWidgetState();
}

class _RelatorioDetalhesWidgetState extends State<RelatorioDetalhesWidget>
    with SingleTickerProviderStateMixin {
  late RelatorioDetalhesModel _model;
  late AnimationController _animationController;

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  dynamic _fluxo;
  bool? _podeProcessarAssinatura;
  String? _camuflado;
  bool _pdfLoading = false;
  bool _enviandoAprovacao = false;
  bool _reenviandoAprovacao = false;
  bool _processandoAssinatura = false;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _atividadesTableHScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => RelatorioDetalhesModel());
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _atividadesTableHScroll.dispose();
    _animationController.dispose();
    _model.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login para ver os dados do relatório.';
      });
      return;
    }

    final camParam = widget.camufladoId?.trim();
    final uuidParam = widget.uuid?.trim();

    late final ApiCallResponse ex;
    if (camParam != null && camParam.isNotEmpty) {
      ex = await RelatorioExibirCall.call(token: token, camufladoId: camParam);
    } else if (uuidParam != null && uuidParam.isNotEmpty) {
      ex = await RelatorioExibirPorUuidCall.call(token: token, uuid: uuidParam);
    } else {
      setState(() {
        _loading = false;
        _error =
            'Abra o relatório a partir da lista (uuid ou identificador ausente).';
      });
      return;
    }

    if (!ex.succeeded || ex.jsonBody == null) {
      setState(() {
        _loading = false;
        _error = 'Erro ao carregar relatório (HTTP ${ex.statusCode}).';
      });
      return;
    }

    final body = ex.jsonBody;
    if (body is Map && body['error'] != null) {
      setState(() {
        _loading = false;
        _error = '${body['error']}';
      });
      return;
    }

    Map<String, dynamic> data;
    if (body is Map<String, dynamic>) {
      data = body;
    } else if (body is Map) {
      data = Map<String, dynamic>.from(body);
    } else {
      setState(() {
        _loading = false;
        _error = 'Resposta inválida do servidor.';
      });
      return;
    }

    dynamic fluxo;
    bool? podeProcessar;
    final sid = data['status_id'];
    final relatorioId = _relatorioIdNumerico(data);
    if (sid == 2 && relatorioId != null) {
      final fx = await RelatorioFluxoAssinaturasCall.call(
        token: token,
        relatorioId: relatorioId,
      );
      if (fx.succeeded && fx.jsonBody is Map) {
        fluxo = (fx.jsonBody as Map)['fluxo'];
      }
      if (fluxo == null) {
        final st = await AssinaturaRelatorioStatusCall.call(
          token: token,
          relatorioId: relatorioId,
        );
        if (st.succeeded && st.jsonBody is Map) {
          final inner = (st.jsonBody as Map)['data'];
          if (inner is Map) {
            fluxo = inner;
          }
        }
      }
      final pp = await AssinaturaRelatorioPodeProcessarCall.call(
        token: token,
        relatorioId: relatorioId,
      );
      if (pp.succeeded && pp.jsonBody is Map) {
        podeProcessar = (pp.jsonBody as Map)['pode_processar'] == true;
      } else {
        podeProcessar = false;
      }
    }

    if (!mounted) return;

    final camufladoResp = data['camuflado_id']?.toString().trim();
    setState(() {
      _data = data;
      _fluxo = fluxo;
      _podeProcessarAssinatura = podeProcessar;
      _loading = false;
      _camuflado = (camufladoResp != null && camufladoResp.isNotEmpty)
          ? camufladoResp
          : camParam;
    });
  }

  Future<void> _onImprimir() async {
    final token = FFAppState().UserToken.trim();
    final cam = _camuflado;
    final d = _data;
    if (token.isEmpty || cam == null || cam.isEmpty) return;

    setState(() => _pdfLoading = true);
    final nome = 'rdo-${d?['numero'] ?? d?['id'] ?? 'relatorio'}';
    final path = await RelatorioExportarPdf.downloadToTemp(
      token: token,
      camufladoId: cam,
      baseFileName: nome.toString(),
    );
    if (!mounted) return;
    setState(() => _pdfLoading = false);

    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível gerar o PDF.')),
      );
      return;
    }

    // Abrir com app de PDF (equivalente ao download + abrir no browser do frontend).
    // `url_launcher` com file:// costuma falhar no Android 11+ por visibilidade de pacotes.
    final opened = await OpenFilex.open(path);
    if (!mounted) return;
    if (opened.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened.message.isNotEmpty
                ? 'PDF: ${opened.message}'
                : 'Não foi possível abrir o PDF. Arquivo em: $path',
          ),
        ),
      );
    }
  }

  Future<void> _onAprovarRevogacao(String revogacaoUuid) async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    final r = await RelatorioRevogacaoAprovarCall.call(
      token: token,
      revogacaoUuid: revogacaoUuid,
    );
    if (!mounted) return;
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revogação aprovada.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao aprovar (${r.statusCode}).')),
      );
    }
  }

  Future<void> _onRejeitarRevogacao(String revogacaoUuid) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Rejeitar revogação'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Obrigatório',
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
    if (motivo == null || motivo.length < 5) {
      if (motivo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Informe um motivo (mín. 5 caracteres).')),
        );
      }
      return;
    }
    final token = FFAppState().UserToken.trim();
    final r = await RelatorioRevogacaoRejeitarCall.call(
      token: token,
      revogacaoUuid: revogacaoUuid,
      motivo: motivo,
    );
    if (!mounted) return;
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revogação rejeitada.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao rejeitar (${r.statusCode}).')),
      );
    }
  }

  Future<void> _onSolicitarRevogacao() async {
    final d = _data;
    if (d == null) return;
    final id = _relatorioIdNumerico(d);
    if (id == null) return;

    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Solicitar revogação'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Motivo da revogação',
              hintText: 'Mínimo 10 caracteres',
            ),
            maxLines: 5,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    if (motivo == null || motivo.length < 10) {
      if (motivo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Informe um motivo (mín. 10 caracteres).')),
        );
      }
      return;
    }

    final token = FFAppState().UserToken.trim();
    final r = await RelatorioSolicitarRevogacaoCall.call(
      token: token,
      relatorioId: id,
      motivoRevogacao: motivo,
    );
    if (!mounted) return;
    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitação enviada.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  int? _relatorioIdNumerico(Map<String, dynamic> data) {
    final rid = data['id'];
    if (rid is int) return rid;
    if (rid is num) return rid.toInt();
    return int.tryParse('$rid');
  }

  String _apiErroMensagem(ApiCallResponse r) {
    final b = r.jsonBody;
    if (b is Map) {
      final m = b['message'] ?? b['error'];
      if (m != null && '$m'.trim().isNotEmpty) return '$m';
    }
    return 'Falha na requisição (HTTP ${r.statusCode}).';
  }

  Future<void> _onEnviarParaAprovacao() async {
    final id = _relatorioIdNumerico(_data!);
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Enviar para aprovação'),
        content: const Text(
          'O relatório passará para o status "Aguardando aprovação" e os aprovadores serão notificados. Deseja continuar?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Enviar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _enviandoAprovacao = true);
    final token = FFAppState().UserToken.trim();
    final r =
        await RelatorioEnviarAprovacaoCall.call(token: token, relatorioId: id);
    if (!mounted) return;
    setState(() => _enviandoAprovacao = false);

    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório enviado para aprovação.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onReenviarParaAprovacao() async {
    final id = _relatorioIdNumerico(_data!);
    if (id == null) return;

    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Reenviar para aprovação'),
          content: SingleChildScrollView(
            child: TextField(
              controller: c,
              decoration: const InputDecoration(
                labelText: 'Observação (opcional)',
                hintText: 'Ex.: correções realizadas',
              ),
              maxLines: 4,
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Reenviar'),
            ),
          ],
        );
      },
    );
    if (motivo == null || !mounted) return;

    setState(() => _reenviandoAprovacao = true);
    final token = FFAppState().UserToken.trim();
    final r = await RelatorioReenviarAprovacaoCall.call(
      token: token,
      relatorioId: id,
      motivo: motivo,
    );
    if (!mounted) return;
    setState(() => _reenviandoAprovacao = false);

    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório reenviado para aprovação.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onAprovarRelatorioAssinatura() async {
    final id = _relatorioIdNumerico(_data!);
    if (id == null) return;
    final conf = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprovar relatório'),
        content: const Text(
          'Confirma a aprovação desta etapa? O relatório seguirá para o próximo aprovador ou será concluído se for a última assinatura.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Aprovar')),
        ],
      ),
    );
    if (conf != true || !mounted) return;

    setState(() => _processandoAssinatura = true);
    final token = FFAppState().UserToken.trim();
    final r = await AssinaturaRelatorioAprovarCall.call(
        token: token, relatorioId: id);
    if (!mounted) return;
    setState(() => _processandoAssinatura = false);

    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aprovação registrada.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  Future<void> _onReprovarRelatorioAssinatura() async {
    final id = _relatorioIdNumerico(_data!);
    if (id == null) return;

    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController();
        return AlertDialog(
          title: const Text('Reprovar relatório'),
          content: TextField(
            controller: c,
            decoration: const InputDecoration(
              labelText: 'Motivo',
              hintText: 'Descreva o motivo da reprovação',
            ),
            maxLines: 4,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: const Text('Confirmar'),
            ),
          ],
        );
      },
    );
    if (motivo == null || motivo.length < 3) {
      if (motivo != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Informe um motivo (mín. 3 caracteres).')),
        );
      }
      return;
    }
    if (!mounted) return;

    setState(() => _processandoAssinatura = true);
    final token = FFAppState().UserToken.trim();
    final r = await AssinaturaRelatorioReprovarCall.call(
      token: token,
      relatorioId: id,
      motivo: motivo,
    );
    if (!mounted) return;
    setState(() => _processandoAssinatura = false);

    if (r.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Relatório reprovado.')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErroMensagem(r))),
      );
    }
  }

  void _openPhoto(String url) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Visualizar foto',
                    style: FlutterFlowTheme.of(ctx).titleSmall,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(height: 1),
            Flexible(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _animationController,
          child: _buildBody(),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    final theme = FlutterFlowTheme.of(context);
    final data = _data;
    final numero = _str(data?['numero']);
    final obraNome = _str(_map(data?['obra'])?['nome']);
    final subtitulo = [
      if (numero.isNotEmpty) 'RDO #$numero',
      if (obraNome.isNotEmpty) obraNome,
    ].join(' · ');

    return AppBar(
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
              'Detalhes do RDO',
              style: GoogleFonts.interTight(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            Text(
              subtitulo.isEmpty ? 'Relatório diário de obra' : subtitulo,
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
          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 21),
          onPressed: _loading ? null : _load,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoadingState();
    if (_error != null) return _buildErrorState();
    if (_data == null) return const SizedBox.shrink();

    final data = _data!;
    return RefreshIndicator(
      onRefresh: _load,
      color: FlutterFlowTheme.of(context).primary,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(data),
                const SizedBox(height: 10),
                _buildRevogacaoPanels(data),
                _buildHistoricoRevogacoes(data),
                _buildPainelFluxoAprovacao(data),
                _buildObraInfo(data),
                _buildHorarios(data),
                _buildMaoObraVinculada(data),
                _buildAtividades(data),
                _buildMateriaisECustos(data),
                _buildEquipamentosEMaoUsadas(data),
                _buildOcorrencias(data),
                _buildComentarios(data),
                _buildFotos(data),
                _buildStatusAlerts(data),
                const SizedBox(height: 12),
                _buildFooter(data),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    final theme = FlutterFlowTheme.of(context);
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
            'Carregando relatório',
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

  Widget _buildErrorState() {
    final theme = FlutterFlowTheme.of(context);
    return Center(
      child: SingleChildScrollView(
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
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 28),
            Container(
              width: 200,
              child: FilledButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Tentar novamente'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> data) {
    final theme = FlutterFlowTheme.of(context);
    final obra = _map(data['obra']);
    final status = _map(data['status']);
    final obraNome = _str(obra?['nome']).isEmpty ? 'N/A' : _str(obra?['nome']);
    final statusId = int.tryParse('${data['status_id'] ?? ''}') ??
        int.tryParse('${status?['id'] ?? ''}');
    final statusNomeApi =
        _str(status?['nome']).isEmpty ? null : _str(status?['nome']);
    final statusNome = labelRelatorioStatus(
      statusId: statusId,
      statusNome: statusNomeApi,
    );
    final statusCor = corStatusRelatorioChip(context, statusId);
    final podePdf = _camuflado != null && _camuflado!.trim().isNotEmpty;

    final inicio = _dataBr(data['data_inicio']);
    final fim = _dataBr(data['data_final']);
    // API/web: data única vem em `data` (accessor d/m/Y). SQLite local usa data_executado.
    final dataCampo = _dataBr(data['data']);
    final dataExecutado = _dataBr(data['data_executado']);
    final ehPeriodo = inicio.isNotEmpty && fim.isNotEmpty && inicio != fim;
    final dataUnica = [
      dataCampo,
      dataExecutado,
      inicio,
      fim,
    ].firstWhere((e) => e.isNotEmpty, orElse: () => '');
    final entrada = _str(data['entrada_manha']);
    final saida = _str(data['saida_tarde']);
    final jornada = entrada.isEmpty && saida.isEmpty
        ? '--'
        : '${entrada.isEmpty ? '--' : entrada} - ${saida.isEmpty ? '--' : saida}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: rdoCardDecoration(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                decoration: BoxDecoration(
                  color: theme.primaryBackground.withValues(alpha: 0.5),
                  border: Border(bottom: BorderSide(color: theme.alternate)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.apartment_rounded,
                        size: 16, color: theme.secondaryText),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        obraNome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusCor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusCor.withValues(alpha: 0.28)),
                      ),
                      child: Text(
                        statusNome,
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: statusCor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              RdoKpiStrip(
                itens: [
                  RdoKpiData(
                    label: 'RDO nº',
                    value: _str(data['numero']).isEmpty
                        ? '---'
                        : _str(data['numero']),
                    flex: 2,
                  ),
                  RdoKpiData(
                    label: ehPeriodo ? 'Período' : 'Data',
                    value: ehPeriodo
                        ? '$inicio - $fim'
                        : (dataUnica.isEmpty ? '---' : dataUnica),
                    flex: ehPeriodo ? 4 : 2,
                  ),
                  RdoKpiData(
                    label: 'Jornada',
                    value: jornada,
                    destaque: true,
                    flex: 2,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                icon: Icons.picture_as_pdf_outlined,
                label: 'PDF',
                onPressed: podePdf && !_pdfLoading ? _onImprimir : null,
                loading: _pdfLoading,
                backgroundColor: theme.secondaryBackground,
                foregroundColor: theme.primary,
                outlined: true,
              ),
            ),
            if (data['pode_solicitar_revogacao'] == true) ...[
              const SizedBox(width: 8),
              Expanded(
                child: _buildActionButton(
                  icon: Icons.undo_rounded,
                  label: 'Revogar',
                  onPressed: _onSolicitarRevogacao,
                  backgroundColor: theme.error.withValues(alpha: 0.08),
                  foregroundColor: theme.error,
                  outlined: true,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
    required Color backgroundColor,
    required Color foregroundColor,
    bool outlined = false,
  }) {
    final borderRadius = BorderRadius.circular(8);
    final child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: foregroundColor,
            ),
          )
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );

    if (outlined) {
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          side: BorderSide(color: foregroundColor.withValues(alpha: 0.35)),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
        ),
        child: child,
      );
    }

    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        minimumSize: const Size(0, 36),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: borderRadius),
      ),
      child: child,
    );
  }

  Widget _buildRevogacaoPanels(Map<String, dynamic> data) {
    final ativa = data['revogacao_ativa'];
    if (ativa == null || ativa is! Map) return const SizedBox.shrink();

    final assinaturas = ativa['assinaturas'];
    final list = assinaturas is List ? assinaturas : const [];
    final decididos = list.where((a) {
      if (a is! Map) return false;
      return a['status'] == 'Decidido';
    }).length;

    final pode = data['usuario_pode_decidir_revogacao'] == true;
    final uuid = _str(ativa['uuid']);

    final theme = FlutterFlowTheme.of(context);
    return _buildSection(
      title: 'Revogação em Andamento',
      icon: Icons.gavel_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Solicitante: ${_str(ativa['solicitante'])}',
                style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w500),
              ),
              Chip(
                label: Text('$decididos/${list.length}'),
                backgroundColor: theme.warning.withValues(alpha: 0.1),
                side: BorderSide(color: theme.warning.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Data: ${_str(ativa['data_solicitacao'])}',
            style: GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
          ),
          const SizedBox(height: 8),
          Text(
            'Motivo: ${_str(ativa['motivo'])}',
            style: GoogleFonts.inter(fontSize: 13),
          ),
          const SizedBox(height: 12),
          ...list.map((a) {
            if (a is! Map) return const SizedBox.shrink();
            final ok = a['status'] == 'Decidido';
            final dec = a['decisao'];
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    ok
                        ? (dec == 'Aprovou' ? Icons.check_circle : Icons.cancel)
                        : Icons.schedule,
                    color: ok
                        ? (dec == 'Aprovou' ? Colors.green : Colors.red)
                        : theme.warning,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${_str(a['posicao'])}º — ${_str(a['assinante'])} ${ok ? '($dec)' : ''}',
                    style: GoogleFonts.inter(fontSize: 13),
                  ),
                ],
              ),
            );
          }),
          if (pode && uuid.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.check_rounded,
                    label: 'Aprovar',
                    onPressed: () => _onAprovarRevogacao(uuid),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.close_rounded,
                    label: 'Rejeitar',
                    onPressed: () => _onRejeitarRevogacao(uuid),
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHistoricoRevogacoes(Map<String, dynamic> data) {
    final h = data['historico_revogacoes'];
    if (h is! List || h.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);

    return _buildSection(
      title: 'Histórico de Revogações',
      icon: Icons.history_rounded,
      child: Column(
        children: h.map((rev) {
          if (rev is! Map) return const SizedBox.shrink();
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(Icons.description_outlined,
                    size: 20, color: theme.secondaryText),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _str(rev['solicitante']),
                        style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _str(rev['motivo']),
                        style: GoogleFonts.inter(
                            fontSize: 12, color: theme.secondaryText),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getStatusColor(rev['status'])
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _str(rev['status']),
                        style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(rev['status'])),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _str(rev['data_conclusao']),
                      style: GoogleFonts.inter(
                          fontSize: 10, color: theme.secondaryText),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    final s = _str(status).toLowerCase();
    if (s.contains('aprov')) return Colors.green;
    if (s.contains('rejeit')) return Colors.red;
    return Colors.orange;
  }

  Widget _buildPainelFluxoAprovacao(Map<String, dynamic> data) {
    final sid = data['status_id'];
    if (sid != 1 && sid != 2 && sid != 4) return const SizedBox.shrink();

    final theme = FlutterFlowTheme.of(context);

    if (sid == 1) {
      return _buildSection(
        title: 'Enviar para Aprovação',
        icon: Icons.send_rounded,
        child: Column(
          children: [
            Text(
              'Quando o relatório estiver pronto, envie para o fluxo de assinaturas.',
              style:
                  GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              icon: Icons.send_rounded,
              label:
                  _enviandoAprovacao ? 'Enviando...' : 'Enviar para aprovação',
              onPressed: _enviandoAprovacao ? null : _onEnviarParaAprovacao,
              loading: _enviandoAprovacao,
              backgroundColor: theme.primary,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      );
    }

    if (sid == 4) {
      return _buildSection(
        title: 'Reenviar para Aprovação',
        icon: Icons.refresh_rounded,
        child: Column(
          children: [
            Text(
              'Após ajustar o relatório, coloque-o novamente na fila de assinaturas.',
              style:
                  GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
            ),
            const SizedBox(height: 10),
            _buildActionButton(
              icon: Icons.refresh_rounded,
              label: _reenviandoAprovacao
                  ? 'Reenviando...'
                  : 'Reenviar para aprovação',
              onPressed: _reenviandoAprovacao ? null : _onReenviarParaAprovacao,
              loading: _reenviandoAprovacao,
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ],
        ),
      );
    }

    final fluxoMap =
        _fluxo is Map ? Map<String, dynamic>.from(_fluxo as Map) : null;
    final assinaturas = fluxoMap == null ? null : fluxoMap['assinaturas'];
    final lista = assinaturas is List ? assinaturas : const [];
    final prox = fluxoMap == null ? null : fluxoMap['proximo'];
    final proxNome = prox is Map ? _str(prox['nome']) : '';

    return _buildSection(
      title: 'Fluxo de Assinaturas',
      icon: Icons.fact_check_rounded,
      child: Column(
        children: [
          if (lista.isEmpty)
            Text(
              'Carregando fila de aprovadores...',
              style:
                  GoogleFonts.inter(fontSize: 13, color: theme.secondaryText),
            )
          else ...[
            ...lista.map((raw) {
              if (raw is! Map) return const SizedBox.shrink();
              final a = Map<String, dynamic>.from(raw);
              final situacao = _str(a['situacao']);
              final numSit = a['situacao_numero'];
              Color chipColor = theme.secondaryText;
              if (numSit == 1) chipColor = Colors.orange;
              if (numSit == 2) chipColor = Colors.green;
              if (numSit == 3) chipColor = theme.error;
              final proximo = a['e_proximo'] == true;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      proximo ? Icons.arrow_circle_right : Icons.person_outline,
                      color: proximo ? theme.primary : theme.secondaryText,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_str(a['posicao'])}º ${_str(a['nome'])}',
                            style: GoogleFonts.inter(
                                fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                          if (proximo)
                            Text(
                              'Aguardando esta assinatura',
                              style: GoogleFonts.inter(
                                  fontSize: 11, color: theme.secondaryText),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: chipColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        situacao,
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: chipColor),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_podeProcessarAssinatura == true) ...[
              const Divider(height: 16),
              Text(
                'Sua decisão',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.check,
                      label: 'Aprovar',
                      onPressed: _processandoAssinatura
                          ? null
                          : _onAprovarRelatorioAssinatura,
                      loading: _processandoAssinatura,
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.close_rounded,
                      label: 'Reprovar',
                      onPressed: _processandoAssinatura
                          ? null
                          : _onReprovarRelatorioAssinatura,
                      backgroundColor: theme.error.withValues(alpha: 0.08),
                      foregroundColor: theme.error,
                      outlined: true,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildObraInfo(Map<String, dynamic> data) {
    final theme = FlutterFlowTheme.of(context);
    final obra = _map(data['obra']);
    final cliente = _map(obra?['cliente']);
    final prazos = _map(data['prazos']);
    final enc = _map(data['encarregado']);

    final logradouro = [
      _str(obra?['rua']),
      _str(obra?['numero']),
    ].where((e) => e.isNotEmpty).join(', ');
    final endereco = [
      logradouro,
      _str(obra?['bairro']),
    ].where((e) => e.isNotEmpty).join(' · ');
    final cidade = [
      _str(obra?['cidade']),
      _str(obra?['estado']),
    ].where((e) => e.isNotEmpty).join(' / ');

    final decorrido =
        double.tryParse(_str(prazos?['porcentagem_decorrida']).replaceAll(',', '.'))
                ?.clamp(0, 100)
                .toDouble() ??
            0;

    return _buildSection(
      title: 'Informações da Obra',
      icon: Icons.apartment_rounded,
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
                  _str(cliente?['nome']),
                  'Contrato',
                  _str(obra?['contrato']),
                ),
                const SizedBox(height: 8),
                _parInfo(
                  'Encarregado',
                  _str(enc?['nome']),
                  'Progresso do prazo',
                  '${decorrido.round()}%',
                ),
                const SizedBox(height: 8),
                _parInfo(
                  'Início da obra',
                  _dataBr(obra?['data_inicio']),
                  'Fim da obra',
                  _dataBr(obra?['data_final']),
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
                  value: _dias(prazos?['prazo_contratual']),
                ),
                RdoKpiData(
                  label: 'Decorrido',
                  value: _dias(prazos?['prazo_decorrido']),
                ),
                RdoKpiData(
                  label: 'A vencer',
                  value: _dias(prazos?['prazo_a_vencer']),
                  destaque: true,
                ),
              ],
            ),
          ),
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

  /// Dois campos rótulo/valor na mesma linha, no padrão das tabelas do RDO.
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

  String _dias(dynamic v) {
    final s = _str(v);
    if (s.isEmpty) return '—';
    final n = double.tryParse(s.replaceAll(',', '.'));
    final texto = n == null ? s : n.round().toString();
    return '$texto d';
  }

  Widget _buildHorarios(Map<String, dynamic> data) {
    String hora(dynamic v) {
      final s = _str(v);
      return s.isEmpty ? '--' : s;
    }

    final horas = _str(data['horas_trabalhadas']);

    return _buildSection(
      title: 'Horários e Turnos',
      icon: Icons.schedule_rounded,
      contentPadding: EdgeInsets.zero,
      child: RdoKpiStrip(
        itens: [
          RdoKpiData(label: 'Entrada', value: hora(data['entrada_manha'])),
          RdoKpiData(
            label: 'Intervalo',
            value: hora(data['inicio_intervalo']),
            hint: 'até ${hora(data['fim_intervalo'])}',
          ),
          RdoKpiData(label: 'Saída', value: hora(data['saida_tarde'])),
          RdoKpiData(
            label: 'Jornada',
            value: horas.isEmpty ? '--' : '${horas}h',
            destaque: true,
          ),
        ],
      ),
    );
  }

  /// API às vezes envia camelCase ou o payload pode variar conforme cliente JSON.
  List<dynamic>? _listaRelatorioFirstMatch(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v is List) return v;
    }
    return null;
  }

  Widget _buildMaoObraVinculada(Map<String, dynamic> data) {
    final list = _listaRelatorioFirstMatch(data, ['mao_obra_vinculada', 'maoObraVinculada']);
    if (list == null || list.isEmpty) {
      return _buildSection(
        title: 'Mão de Obra',
        icon: Icons.groups_2_rounded,
        child: _buildEmptyState('Nenhuma mão de obra registrada'),
      );
    }

    final theme = FlutterFlowTheme.of(context);
    return _buildSection(
      title: 'Mão de Obra Vinculada',
      icon: Icons.groups_2_rounded,
      trailing: RdoContadorChip(
        list.length == 1 ? '1 pessoa' : '${list.length} pessoas',
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const RdoTableHeader(
            columns: [
              RdoColumn('Colaborador', flex: 5),
              RdoColumn('Presença', flex: 3, align: TextAlign.center),
              RdoColumn('Horas', flex: 2, align: TextAlign.end),
            ],
          ),
          for (var idx = 0; idx < list.length; idx++)
            Builder(
              builder: (_) {
                final mo = list[idx] as Map?;
                if (mo == null) return const SizedBox.shrink();
                final maoObra = _map(mo['mao_obra']) ??
                    _map(mo['maoObra']) ??
                    _map(mo['obra_item']);
                final nome = _str(mo['nome']).isNotEmpty
                    ? _str(mo['nome'])
                    : _str(maoObra?['descricao']);
                final cargo = _str(mo['cargo']).isNotEmpty
                    ? _str(mo['cargo'])
                    : _str(maoObra?['cargo_funcao']);
                final presenca = _str(mo['status_presenca']);
                final cor = _getPresencaColor(mo['status_presenca']);
                final horas = _str(mo['horas_trabalhadas']);

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: idx == list.length - 1
                      ? null
                      : BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.alternate),
                          ),
                        ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome.isEmpty ? '—' : nome,
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            if (cargo.isNotEmpty)
                              Text(
                                cargo,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: theme.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(child: _chipStatus(presenca, cor)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          horas.isEmpty ? '—' : '${horas}h',
                          textAlign: TextAlign.end,
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: theme.primaryText,
                          ),
                        ),
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

  Widget _chipStatus(String texto, Color cor) {
    if (texto.isEmpty) {
      return Text(
        '—',
        style: GoogleFonts.inter(
          fontSize: 11,
          color: FlutterFlowTheme.of(context).secondaryText,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.3)),
      ),
      child: Text(
        texto,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: cor,
        ),
      ),
    );
  }

  Color _getPresencaColor(dynamic status) {
    final statusStr = _str(status).toLowerCase();
    if (statusStr.contains('presente')) return Colors.green;
    if (statusStr.contains('ausente')) return Colors.red;
    return Colors.orange;
  }

  Widget _buildEmptyState(String message) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(
            Icons.inbox_outlined,
            size: 20,
            color: theme.secondaryText.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtividades(Map<String, dynamic> data) {
    final list = data['atividades'];
    if (list is! List || list.isEmpty) {
      return _buildSection(
        title: 'Atividades Realizadas',
        icon: Icons.task_alt_rounded,
        child: _buildEmptyState('Nenhuma atividade registrada'),
      );
    }

    return _buildSection(
      title: 'Atividades Realizadas',
      icon: Icons.task_alt_rounded,
      trailing: RdoContadorChip(
        list.length == 1 ? '1 atividade' : '${list.length} atividades',
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < list.length; i++)
            _buildActivityCard(list[i], i < list.length - 1),
        ],
      ),
    );
  }

  Widget _buildActivityCard(dynamic activity, bool showDivider) {
    if (activity is! Map) return const SizedBox.shrink();

    final theme = FlutterFlowTheme.of(context);
    final progress = _progressoAtividade(activity);
    final status = _statusAtividade(activity);
    final statusColor = progress >= 100
        ? Colors.green
        : (progress > 0 ? Colors.orange : theme.secondaryText);

    final local = _str(activity['local_nome'] ?? activity['local']);
    final unidade = _str(activity['unidade']);
    final etapa = _etapaAtividade(activity);

    final insumos = _itensAtividade(activity, const ['insumos']);
    final equipamentos = _itensAtividade(activity, const ['equipamentos']);
    final maoObra = _itensAtividade(activity, const ['mao_obra', 'maoObra']);
    final temItens =
        insumos.isNotEmpty || equipamentos.isNotEmpty || maoObra.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: showDivider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.alternate)),
            )
          : null,
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
                      _descricaoAtividade(activity),
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        color: theme.primaryText,
                      ),
                    ),
                    if (etapa.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          etapa,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _chipStatus(status, statusColor),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.place_outlined, size: 13, color: theme.secondaryText),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  local.isEmpty ? 'Local não informado' : local,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: theme.secondaryText,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Realizado ${_qtd(activity['qtd_realizada'])}'
                '${unidade.isEmpty ? '' : ' $unidade'}',
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: theme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress / 100,
                    minHeight: 5,
                    backgroundColor: theme.alternate,
                    color: progress >= 100 ? Colors.green : theme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${progress.round()}%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
          if (temItens) ...[
            const SizedBox(height: 10),
            _grupoItensAtividade(
              titulo: 'Insumos',
              icone: Icons.inventory_2_outlined,
              cor: theme.primary,
              itens: insumos,
              mostrarProduzida: false,
            ),
            _grupoItensAtividade(
              titulo: 'Equipamentos',
              icone: Icons.precision_manufacturing_outlined,
              cor: theme.tertiary,
              itens: equipamentos,
              mostrarProduzida: true,
            ),
            _grupoItensAtividade(
              titulo: 'Mão de obra',
              icone: Icons.groups_2_outlined,
              cor: theme.secondary,
              itens: maoObra,
              mostrarProduzida: true,
            ),
          ],
        ],
      ),
    );
  }

  /// Itens vinculados à atividade (`relatorio_atividades_itens` no payload).
  List<Map<String, dynamic>> _itensAtividade(
    Map<dynamic, dynamic> atividade,
    List<String> chaves,
  ) {
    for (final chave in chaves) {
      final v = atividade[chave];
      if (v is List) {
        return v
            .map(_map)
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
    }
    return const [];
  }

  String _etapaAtividade(Map<dynamic, dynamic> a) {
    final tarefa = _map(a['tarefa']);
    final etapa = _map(tarefa?['etapa']);
    final nome = _str(etapa?['nome']);
    if (nome.isNotEmpty) return nome;
    final item = _str(etapa?['item']);
    if (item.isNotEmpty) return item;
    return '';
  }

  /// Bloco de recursos usados na atividade, no formato de tabela compacta.
  /// Equipamentos e mão de obra também trazem a quantidade produzida.
  Widget _grupoItensAtividade({
    required String titulo,
    required IconData icone,
    required Color cor,
    required List<Map<String, dynamic>> itens,
    required bool mostrarProduzida,
  }) {
    if (itens.isEmpty) return const SizedBox.shrink();
    final theme = FlutterFlowTheme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 8),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.primaryBackground.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.08),
              border: Border(bottom: BorderSide(color: theme.alternate)),
            ),
            child: Row(
              children: [
                Icon(icone, size: 13, color: cor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    titulo.toUpperCase(),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: cor,
                    ),
                  ),
                ),
                Text(
                  '${itens.length}',
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: theme.alternate)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Text('Item', style: rdoColumnLabelStyle(context)),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'UTIL.',
                    textAlign: TextAlign.end,
                    style: rdoColumnLabelStyle(context),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'REAL.',
                    textAlign: TextAlign.end,
                    style: rdoColumnLabelStyle(context),
                  ),
                ),
                if (mostrarProduzida)
                  Expanded(
                    flex: 2,
                    child: Text(
                      'PROD.',
                      textAlign: TextAlign.end,
                      style: rdoColumnLabelStyle(context),
                    ),
                  ),
              ],
            ),
          ),
          for (var i = 0; i < itens.length; i++)
            _linhaItemAtividade(
              itens[i],
              mostrarProduzida: mostrarProduzida,
              ultimo: i == itens.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _linhaItemAtividade(
    Map<String, dynamic> item, {
    required bool mostrarProduzida,
    required bool ultimo,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final obraItem = _map(item['obra_item']) ?? _map(item['obraItem']);
    final profissional = _map(obraItem?['profissional']);

    final nomeProfissional = _str(profissional?['nome_completo']).isNotEmpty
        ? _str(profissional?['nome_completo'])
        : _str(profissional?['nome']);
    final descricao = _str(obraItem?['descricao']);
    final nome = nomeProfissional.isNotEmpty
        ? nomeProfissional
        : (descricao.isEmpty ? '—' : descricao);

    final apoio = [
      _str(obraItem?['cargo_funcao']),
      _str(obraItem?['unidade']),
    ].where((e) => e.isNotEmpty).join(' · ');

    Widget valor(dynamic v) => Expanded(
          flex: 2,
          child: Text(
            _qtd(v),
            textAlign: TextAlign.end,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: ultimo
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: theme.alternate.withValues(alpha: 0.6),
                ),
              ),
            ),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.primaryText,
                  ),
                ),
                if (apoio.isNotEmpty)
                  Text(
                    apoio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: theme.secondaryText,
                    ),
                  ),
              ],
            ),
          ),
          valor(item['qtd_utilizada']),
          valor(item['qtd_realizada']),
          if (mostrarProduzida) valor(item['qtd_produzida']),
        ],
      ),
    );
  }

  double _progressoAtividade(Map<dynamic, dynamic> a) {
    final p = a['progresso'];
    final n = double.tryParse('$p');
    if (n == null || n.isNaN) return 0;
    return n.clamp(0, 100);
  }

  String _statusAtividade(Map a) {
    final g = _progressoAtividade(a);
    if (g >= 100) return 'Concluído';
    if (g > 0) return 'Em andamento';
    return 'Não iniciada';
  }

  String _descricaoAtividade(Map<dynamic, dynamic> a) {
    for (final key in ['descricao', 'item', 'nome']) {
      final s = _str(a[key]);
      if (s.isNotEmpty) return s;
    }
    final tf = _map(a['tarefa']);
    if (tf != null) {
      final n = _str(tf['nome']);
      if (n.isNotEmpty) return n;
    }
    return 'N/A';
  }

  Widget _buildMateriaisECustos(Map<String, dynamic> data) {
    final rec = _listaRelatorioFirstMatch(
        data, ['materiais_recebidos', 'materiaisRecebidos']);
    final ins =
        _listaRelatorioFirstMatch(data, ['insumos_usados', 'insumosUsados']);
    final custos = data['custos'];

    return _buildSection(
      title: 'Materiais e Custos',
      icon: Icons.inventory_2_rounded,
      contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _subtituloTabela('Materiais recebidos'),
          _tabelaResumo(
            list: rec,
            vazio: 'Nenhum material recebido',
            rotuloItem: 'Material',
            nome: (m) => _str(m['descricao'] ?? _map(m['equipamento'])?['descricao']),
            apoio: (m) => _str(m['unidade'] ?? _map(m['equipamento'])?['unidade']),
            colunas: [
              _ColunaResumo('Qtd', (m) => _qtd(m['quantidade'])),
            ],
          ),
          _subtituloTabela('Insumos utilizados'),
          _tabelaResumo(
            list: ins,
            vazio: 'Nenhum insumo utilizado',
            rotuloItem: 'Insumo',
            nome: (m) => _str(m['descricao']),
            apoio: (m) => _str(m['unidade']),
            colunas: [
              _ColunaResumo('Util.', (m) => _qtd(m['total_utilizado'])),
              _ColunaResumo('Real.', (m) => _qtd(m['total_realizado'])),
            ],
          ),
          _subtituloTabela('Custos lançados'),
          _tabelaResumo(
            list: custos,
            vazio: 'Nenhum custo registrado',
            rotuloItem: 'Custo',
            nome: (m) => _str(
                m['descricao'] ?? _map(m['ordem_servico_custo'])?['descricao']),
            apoio: (m) =>
                _str(m['unidade'] ?? _map(m['ordem_servico_custo'])?['unidade']),
            colunas: [
              _ColunaResumo('Qtd', (m) => _qtd(m['qtd_realizada'])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEquipamentosEMaoUsadas(Map<String, dynamic> data) {
    final mo = data['mao_obra_usadas'];
    final eq = data['equipamentos_usados'];

    // `total_produzido` só existe em servidores atualizados; sem ele a coluna
    // some em vez de mostrar zero para todo mundo.
    bool temProduzido(dynamic list) =>
        list is List &&
        list.any((e) => e is Map && e['total_produzido'] != null);

    List<_ColunaResumo> colunas(dynamic list) => [
          _ColunaResumo('Util.', (m) => _qtd(m['total_utilizado'])),
          _ColunaResumo('Real.', (m) => _qtd(m['total_realizado'])),
          if (temProduzido(list))
            _ColunaResumo('Prod.', (m) => _qtd(m['total_produzido'])),
        ];

    return _buildSection(
      title: 'Equipamentos e Mão de Obra',
      icon: Icons.precision_manufacturing_rounded,
      subtitle: 'Totais somados de todas as atividades',
      contentPadding: const EdgeInsets.fromLTRB(0, 0, 0, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _subtituloTabela('Mão de obra utilizada'),
          _tabelaResumo(
            list: mo,
            vazio: 'Nenhuma mão de obra utilizada',
            rotuloItem: 'Colaborador',
            nome: (m) => _str(m['descricao']),
            apoio: (m) => _str(m['unidade']),
            colunas: colunas(mo),
          ),
          _subtituloTabela('Equipamentos utilizados'),
          _tabelaResumo(
            list: eq,
            vazio: 'Nenhum equipamento utilizado',
            rotuloItem: 'Equipamento',
            nome: (m) => _str(m['descricao']),
            apoio: (m) => _str(m['unidade']),
            colunas: colunas(eq),
          ),
        ],
      ),
    );
  }

  Widget _subtituloTabela(String texto) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Text(
        texto,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: theme.primaryText,
        ),
      ),
    );
  }

  /// Tabela compacta reaproveitada pelas listas de recursos do RDO.
  Widget _tabelaResumo({
    required dynamic list,
    required String vazio,
    required String rotuloItem,
    required String Function(Map<String, dynamic>) nome,
    required List<_ColunaResumo> colunas,
    String Function(Map<String, dynamic>)? apoio,
  }) {
    final theme = FlutterFlowTheme.of(context);
    if (list is! List || list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
        child: Text(
          vazio,
          style: GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
        ),
      );
    }

    final itens = list
        .map(_map)
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        RdoTableHeader(
          columns: [
            RdoColumn(rotuloItem, flex: 5),
            for (final c in colunas)
              RdoColumn(c.label, flex: 2, align: TextAlign.end),
          ],
        ),
        for (var i = 0; i < itens.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: i == itens.length - 1
                ? null
                : BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: theme.alternate.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        nome(itens[i]).isEmpty ? '—' : nome(itens[i]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: theme.primaryText,
                        ),
                      ),
                      if (apoio != null && apoio(itens[i]).isNotEmpty)
                        Text(
                          apoio(itens[i]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            color: theme.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                for (final c in colunas)
                  Expanded(
                    flex: 2,
                    child: Text(
                      c.valor(itens[i]),
                      textAlign: TextAlign.end,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.primaryText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildOcorrencias(Map<String, dynamic> data) {
    final list = data['ocorrencias'];
    if (list is! List || list.isEmpty) return const SizedBox.shrink();

    final theme = FlutterFlowTheme.of(context);
    final itens = list.map(_map).whereType<Map<String, dynamic>>().toList();

    return _buildSection(
      title: 'Ocorrências',
      icon: Icons.warning_amber_rounded,
      trailing: RdoContadorChip(
        itens.length == 1 ? '1 ocorrência' : '${itens.length} ocorrências',
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itens.length; i++)
            Builder(
              builder: (_) {
                final o = itens[i];
                final tipo = _map(o['tipo']);
                final horario = [
                  _str(o['hora_inicio']),
                  _str(o['hora_saida']),
                ].where((e) => e.isNotEmpty).join(' - ');

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: i == itens.length - 1
                      ? null
                      : BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.alternate),
                          ),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _str(tipo?['nome']).isEmpty
                                  ? 'Ocorrência'
                                  : _str(tipo?['nome']),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: theme.error,
                              ),
                            ),
                          ),
                          if (horario.isNotEmpty)
                            Text(
                              horario,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.secondaryText,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _str(o['descricao']).isEmpty
                            ? '—'
                            : _str(o['descricao']),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.3,
                          color: theme.primaryText,
                        ),
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

  Widget _buildComentarios(Map<String, dynamic> data) {
    final list = data['comentarios'];
    if (list is! List || list.isEmpty) return const SizedBox.shrink();

    final theme = FlutterFlowTheme.of(context);
    final itens = list.map(_map).whereType<Map<String, dynamic>>().toList();

    return _buildSection(
      title: 'Comentários',
      icon: Icons.chat_bubble_outline_rounded,
      trailing: RdoContadorChip(
        itens.length == 1 ? '1 comentário' : '${itens.length} comentários',
      ),
      contentPadding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < itens.length; i++)
            Builder(
              builder: (_) {
                final c = itens[i];
                final autor = _str(c['autor_nome']).isNotEmpty
                    ? _str(c['autor_nome'])
                    : _str(c['created_by']);
                final quando = _formatDataHoraBr(c['created_at']);
                final assinatura = [autor, quando]
                    .where((e) => e.isNotEmpty)
                    .join(' · ');

                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: i == itens.length - 1
                      ? null
                      : BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: theme.alternate),
                          ),
                        ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _str(c['texto']).isEmpty ? '—' : _str(c['texto']),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          height: 1.3,
                          color: theme.primaryText,
                        ),
                      ),
                      if (assinatura.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: Text(
                            assinatura,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: theme.secondaryText,
                            ),
                          ),
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

  Widget _buildFotos(Map<String, dynamic> data) {
    final list = data['fotos'];
    if (list is! List || list.isEmpty) return const SizedBox.shrink();

    final take = list.length > 54 ? 54 : list.length;
    return _buildSection(
      title: 'Fotos',
      icon: Icons.photo_library_rounded,
      trailing: RdoContadorChip(
        list.length == 1 ? '1 foto' : '${list.length} fotos',
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 6,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 1,
        ),
        itemCount: take,
        itemBuilder: (ctx, i) {
          final f = list[i];
          if (f is! Map) return const SizedBox.shrink();
          final url = _str(f['arquivo_url']);
          final theme = FlutterFlowTheme.of(context);
          return InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: url.isNotEmpty ? () => _openPhoto(url) : null,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: theme.alternate,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: url.isNotEmpty
                    ? Image.network(
                        url,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Icon(Icons.broken_image,
                              size: 16, color: theme.secondaryText),
                        ),
                      )
                    : Center(
                        child: Icon(Icons.image_not_supported,
                            size: 16, color: theme.secondaryText),
                      ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusAlerts(Map<String, dynamic> data) {
    final sid = data['status_id'];
    final theme = FlutterFlowTheme.of(context);

    if (sid == 2) {
      Map<String, dynamic>? prox;
      if (_fluxo is Map) {
        final fm = _map(_fluxo);
        final raw = fm == null ? null : fm['proximo'];
        if (raw is Map) {
          prox = Map<String, dynamic>.from(raw);
        }
      }
      return _buildStatusAlert(
        color: theme.tertiary,
        icon: Icons.hourglass_top_rounded,
        title: 'Aguardando aprovação',
        subtitle:
            prox != null ? 'Próximo aprovador: ${_str(prox['nome'])}' : null,
      );
    }

    if (sid == 3) {
      return _buildStatusAlert(
        color: Colors.green,
        icon: Icons.verified_rounded,
        title: 'Relatório aprovado',
        subtitle: 'Documento finalizado no fluxo de aprovação',
      );
    }

    if (sid == 4) {
      return _buildStatusAlert(
        color: theme.error,
        icon: Icons.cancel_rounded,
        title: 'Relatório reprovado',
        subtitle: _str(data['ultimo_motivo_reprovacao']).isNotEmpty
            ? _str(data['ultimo_motivo_reprovacao'])
            : null,
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildStatusAlert({
    required Color color,
    required IconData icon,
    required String title,
    String? subtitle,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: theme.secondaryText,
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

  Widget _buildFooter(Map<String, dynamic> data) {
    final theme = FlutterFlowTheme.of(context);
    final enc = _map(data['encarregado']);

    return Text(
      'Preenchido por ${_str(enc?['nome']).isNotEmpty ? _str(enc?['nome']) : 'Não informado'} · ${_str(data['data'])}',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 11,
        color: theme.secondaryText,
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required Widget child,
    IconData? icon,
    String? subtitle,
    Widget? trailing,
    EdgeInsetsGeometry contentPadding = const EdgeInsets.all(12),
  }) {
    return RdoSectionCard(
      title: title,
      subtitle: subtitle,
      icon: icon,
      trailing: trailing,
      margin: const EdgeInsets.only(bottom: 10),
      contentPadding: contentPadding,
      child: child,
    );
  }

  String _formatDataHoraBr(dynamic raw) {
    final s = _str(raw);
    if (s.isEmpty) return '';
    var dt = DateTime.tryParse(s);
    if (dt == null && s.contains(' ') && !s.contains('T')) {
      dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    }
    if (dt == null) return s;
    return dateTimeFormat('dd/MM/yyyy HH:mm', dt.toLocal(), locale: 'pt_BR');
  }

  /// A API mistura `2026-07-30`, `2026-07-30 00:00:00`, `30/07/2026` e o accessor `d/m/Y`.
  String _dataBr(dynamic raw) {
    final s = _str(raw);
    if (s.isEmpty || s == 'null' || s.toUpperCase() == 'N/A') return '';
    final br = RegExp(r'^(\d{2})/(\d{2})/(\d{4})').firstMatch(s);
    if (br != null) {
      return '${br.group(1)}/${br.group(2)}/${br.group(3)}';
    }
    final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (iso != null) {
      return '${iso.group(3)}/${iso.group(2)}/${iso.group(1)}';
    }
    final dt = DateTime.tryParse(s.replaceFirst(' ', 'T'));
    if (dt == null) return s;
    return dateTimeFormat('dd/MM/yyyy', dt.toLocal(), locale: 'pt_BR');
  }

  Map<String, dynamic>? _map(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  String _str(dynamic v) {
    if (v == null) return '';
    return v.toString().trim();
  }

  /// Quantidade no padrão do RDO: inteiro sem casas, decimal com vírgula.
  String _qtd(dynamic v) {
    if (v == null) return '—';
    final s = v.toString().trim();
    if (s.isEmpty) return '—';
    return formatQuantidadeRelatorio(v);
  }
}

class _ColunaResumo {
  const _ColunaResumo(this.label, this.valor);

  final String label;
  final String Function(Map<String, dynamic> item) valor;
}

import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_drop_down.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'dart:ui';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'selecionar_tarefa_atividade_model.dart';
export 'selecionar_tarefa_atividade_model.dart';

String _statusTarefaLabel(int? status) {
  switch (status) {
    case 1:
      return 'Em andamento';
    case 0:
      return 'Pendente';
    case 2:
      return 'Concluída';
    default:
      return 'Não informado';
  }
}

Color _statusTarefaColor(BuildContext context, int? status) {
  final theme = FlutterFlowTheme.of(context);
  switch (status) {
    case 1:
      return theme.warning;
    case 2:
      return theme.success;
    case 0:
      return theme.secondaryText;
    default:
      return theme.secondaryText;
  }
}

String _prioridadeTarefaLabel(double? porcentagem) {
  if (porcentagem == null) return 'Não informada';
  if (porcentagem >= 75) return 'Alta';
  if (porcentagem >= 40) return 'Média';
  return 'Baixa';
}

Color _prioridadeTarefaColor(BuildContext context, double? porcentagem) {
  if (porcentagem == null) {
    return FlutterFlowTheme.of(context).secondaryText;
  }
  if (porcentagem >= 75) return FlutterFlowTheme.of(context).error;
  if (porcentagem >= 40) return FlutterFlowTheme.of(context).warning;
  return FlutterFlowTheme.of(context).success;
}

/// Seleção da tarefa (por ordem de serviço ou por etapa) antes de criar a
/// atividade vinculada no RDO.
class SelecionarTarefaAtividadeWidget extends StatefulWidget {
  const SelecionarTarefaAtividadeWidget({
    super.key,
    required this.relatorioID,
    required this.obraId,
    required this.relatorioUuid,
    required this.obraUuid,
  });

  final int? relatorioID;
  final int? obraId;
  final String? relatorioUuid;
  final String? obraUuid;

  static String routeName = 'SelecionarTarefaAtividade';
  static String routePath = '/selecionarTarefaAtividade';

  @override
  State<SelecionarTarefaAtividadeWidget> createState() =>
      _SelecionarTarefaAtividadeWidgetState();
}

class _SelecionarTarefaAtividadeWidgetState
    extends State<SelecionarTarefaAtividadeWidget> {
  late SelecionarTarefaAtividadeModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _salvando = false;
  late Future<List<GetOrdensServicoRow>> _ordensFuture;
  late Future<List<ListaEtapasObraRow>> _etapasFuture;
  int _listasReloadToken = 0;

  late Future<void> _listasReady;

  Future<void> _refreshListasLocais() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) return;
    try {
      await Future.wait([
        actions.refreshOrdensPorObra(obraUuid: obraUuid),
        actions.refreshEtapasTarefasPorObra(obraUuid: obraUuid),
        actions.syncOrdensTarefas(),
      ]);
    } catch (_) {}
  }

  Future<List<GetOrdensServicoRow>> _loadOrdens() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) return <GetOrdensServicoRow>[];
    await _listasReady;
    return SQLiteManager.instance.getOrdensServico(
      obraUuid: obraUuid,
      userId: FFAppState().creatorId,
    );
  }

  Future<List<ListaEtapasObraRow>> _loadEtapas() async {
    final obraUuid = (widget.obraUuid ?? '').trim();
    if (obraUuid.isEmpty) return <ListaEtapasObraRow>[];
    await _listasReady;
    return SQLiteManager.instance.listaEtapasObra(obraUuid: obraUuid);
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SelecionarTarefaAtividadeModel());

    _model.switchOrdemValue = false;
    _model.usarTarefaListaOrdem = true;
    _listasReady = _refreshListasLocais();
    _ordensFuture = _loadOrdens();
    _etapasFuture = _loadEtapas();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  void _limparSelecaoTarefa() {
    _model.tarefaSelected = null;
    _model.dropDownTarefasOrdemValue = null;
    _model.dropDownTarefasOrdemValueController?.value = null;
    _model.dropDownTarefasValue = null;
    _model.dropDownTarefasValueController?.value = null;
  }

  bool get _temTarefa =>
      (_model.tarefaSelected ?? '').trim().isNotEmpty &&
      _model.tarefaSelected != '0';

  void _voltarParaRelatorio() {
    context.pushNamed(
      ObraAddRelatorioWidget.routeName,
      queryParameters: {
        'id': serializeParam(widget.relatorioID, ParamType.int),
        'uuid': serializeParam(widget.relatorioUuid, ParamType.String),
      }.withoutNulls,
    );
  }

  Widget _rotulo(String texto) => Padding(
        padding: const EdgeInsets.only(bottom: 4, left: 2),
        child: Text(texto.toUpperCase(), style: rdoColumnLabelStyle(context)),
      );

  Widget _dropdownTarefa({
    required FormFieldController<String> controller,
    required List<String> options,
    required List<String> optionLabels,
    required String hint,
    required String buscaHint,
    required Future<void> Function(String?) onChanged,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return FlutterFlowDropDown<String>(
      controller: controller,
      options: options,
      optionLabels: optionLabels,
      onChanged: (val) async => onChanged(val),
      width: double.infinity,
      height: 38.0,
      textStyle: rdoCompactFieldTextStyle(context),
      searchTextStyle: rdoCompactFieldTextStyle(context),
      searchHintTextStyle:
          GoogleFonts.inter(fontSize: 12, color: theme.secondaryText),
      hintText: hint,
      searchHintText: buscaHint,
      icon: Icon(
        Icons.keyboard_arrow_down_rounded,
        color: theme.secondaryText,
        size: 18.0,
      ),
      fillColor: theme.secondaryBackground,
      elevation: 0.0,
      borderColor: theme.alternate,
      borderWidth: 1.0,
      borderRadius: 8.0,
      margin: const EdgeInsetsDirectional.fromSTEB(10, 0, 6, 0),
      hidesUnderline: true,
      isOverButton: false,
      isSearchable: true,
      isMultiSelect: false,
    );
  }

  Widget _aviso(String texto, {IconData icone = Icons.info_outline_rounded}) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 14, color: theme.secondaryText),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              texto,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                height: 1.3,
                color: theme.secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _carregando() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: LinearProgressIndicator(
          color: FlutterFlowTheme.of(context).primary,
          minHeight: 3,
        ),
      );

  /// Alternador «Lista da ordem» × «Por etapa», no formato das abas do web.
  Widget _seletorModoBusca() {
    final theme = FlutterFlowTheme.of(context);
    final porLista = _model.usarTarefaListaOrdem ?? true;

    Widget opcao(String texto, IconData icone, bool valor) {
      final ativo = porLista == valor;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () {
            if (porLista == valor) return;
            safeSetState(() {
              _model.usarTarefaListaOrdem = valor;
              _limparSelecaoTarefa();
              _model.dropDownEtapaValue = null;
              _model.etapaSelected = null;
              _model.dropDownEtapaValueController?.value = null;
            });
          },
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              color: ativo ? theme.secondaryBackground : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: ativo ? Border.all(color: theme.alternate) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icone,
                  size: 14,
                  color: ativo ? theme.primary : theme.secondaryText,
                ),
                const SizedBox(width: 6),
                Text(
                  texto,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: ativo ? FontWeight.w600 : FontWeight.w500,
                    color: ativo ? theme.primary : theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: theme.primaryBackground.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          opcao('Lista da ordem', Icons.playlist_add_check_rounded, true),
          const SizedBox(width: 3),
          opcao('Por etapa', Icons.stairs_rounded, false),
        ],
      ),
    );
  }

  /// Etapa + tarefa (sem OS ou com OS em modo «Por etapa»).
  Widget _selecaoPorEtapa() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rotulo('Etapa'),
        FutureBuilder<List<ListaEtapasObraRow>>(
          key: ValueKey('etapas_$_listasReloadToken'),
          future: _etapasFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) return _carregando();
            final etapas = snapshot.data!;
            if (etapas.isEmpty) {
              return _aviso(
                'Nenhuma etapa cadastrada nesta obra. Cadastre etapas na web '
                'para localizar tarefas por etapa.',
                icone: Icons.warning_amber_rounded,
              );
            }

            return _dropdownTarefa(
              controller: _model.dropDownEtapaValueController ??=
                  FormFieldController<String>(_model.dropDownEtapaValue),
              options: etapas.map((e) => e.uuid).toList(),
              optionLabels: etapas
                  .map((e) => valueOrDefault<String>(e.nome, 'Etapa sem nome'))
                  .toList(),
              hint: 'Escolha uma etapa...',
              buscaHint: 'Buscar etapa...',
              onChanged: (val) async {
                safeSetState(() {
                  _model.dropDownEtapaValue = val;
                  _model.etapaSelected = val;
                  _limparSelecaoTarefa();
                });
              },
            );
          },
        ),
        const SizedBox(height: 10),
        _rotulo('Tarefa da etapa'),
        if ((_model.etapaSelected ?? '').isEmpty)
          _aviso('Selecione a etapa para listar as tarefas.')
        else
          FutureBuilder<List<ListaTarefasEtapasObraRow>>(
            future: SQLiteManager.instance.listaTarefasEtapasObra(
              etapaUuid: _model.etapaSelected!,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _carregando();
              final tarefas = snapshot.data!;
              if (tarefas.isEmpty) {
                return _aviso(
                  'Esta etapa ainda não tem tarefas cadastradas.',
                  icone: Icons.warning_amber_rounded,
                );
              }

              return _dropdownTarefa(
                controller: _model.dropDownTarefasValueController ??=
                    FormFieldController<String>(_model.dropDownTarefasValue),
                options: tarefas.map((e) => e.uuid).toList(),
                optionLabels: tarefas
                    .map((e) =>
                        valueOrDefault<String>(e.descricao, 'Tarefa sem nome'))
                    .toList(),
                hint: 'Selecione uma tarefa...',
                buscaHint: 'Buscar tarefa...',
                onChanged: (val) async {
                  safeSetState(() {
                    _model.dropDownTarefasValue = val;
                    _model.tarefaSelected = val;
                  });
                },
              );
            },
          ),
      ],
    );
  }

  /// Tarefas listadas diretamente na ordem de serviço escolhida.
  Widget _selecaoPorOrdem() {
    final ordem = (_model.ordemSelected ?? '').trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _rotulo('Tarefa da ordem'),
        if (ordem.isEmpty || ordem == '0')
          _aviso('Selecione a ordem de serviço para listar as tarefas.')
        else
          FutureBuilder<List<GetTarefasOrdemRow>>(
            future: SQLiteManager.instance.getTarefasOrdem(ordemUuid: ordem),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return _carregando();
              final tarefas = snapshot.data!;
              if (tarefas.isEmpty) {
                return _aviso(
                  'Esta ordem não tem tarefas cadastradas. Use a busca por '
                  'etapa ou cadastre as tarefas na web.',
                  icone: Icons.warning_amber_rounded,
                );
              }

              return _dropdownTarefa(
                controller: _model.dropDownTarefasOrdemValueController ??=
                    FormFieldController<String>(
                        _model.dropDownTarefasOrdemValue),
                options: tarefas
                    .map((e) => valueOrDefault<String>(e.uuid, '0'))
                    .toList(),
                optionLabels: tarefas.map((e) {
                  final nome = valueOrDefault<String>(e.nome, 'Tarefa');
                  final unidade = (e.unidade ?? '').trim();
                  final programada = e.qtdProgramada;
                  if (programada == null || programada == 0) return nome;
                  return '$nome · $programada${unidade.isEmpty ? '' : ' $unidade'}';
                }).toList(),
                hint: 'Selecione uma tarefa específica...',
                buscaHint: 'Buscar tarefa...',
                onChanged: (val) async {
                  safeSetState(() {
                    _model.dropDownTarefasOrdemValue = val;
                    _model.tarefaSelected = val;
                  });
                },
              );
            },
          ),
      ],
    );
  }

  Widget _cardOrigem() {
    final theme = FlutterFlowTheme.of(context);
    final comOrdem = _model.switchOrdemValue ?? false;
    final porLista = _model.usarTarefaListaOrdem ?? true;

    return RdoSectionCard(
      title: 'Origem da tarefa',
      subtitle: 'Escolha de onde vem a tarefa desta atividade',
      icon: Icons.account_tree_outlined,
      margin: EdgeInsets.zero,
      contentPadding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 0, 4, 0),
            decoration: BoxDecoration(
              color: theme.primaryBackground.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.alternate),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 15, color: theme.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Vincular ordem de serviço',
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: theme.primaryText,
                    ),
                  ),
                ),
                Transform.scale(
                  scale: 0.75,
                  child: Switch.adaptive(
                    value: comOrdem,
                    onChanged: (newValue) {
                      safeSetState(() {
                        _model.switchOrdemValue = newValue;
                        if (!newValue) {
                          _model.dropDownOrdemValue = null;
                          _model.ordemSelected = null;
                          _model.dropDownOrdemValueController?.value = null;
                          _model.dropDownEtapaValue = null;
                          _model.etapaSelected = null;
                          _model.dropDownEtapaValueController?.value = null;
                        }
                        _model.usarTarefaListaOrdem = true;
                        _limparSelecaoTarefa();
                      });
                    },
                    activeColor: theme.primary,
                    activeTrackColor: theme.primary.withValues(alpha: 0.35),
                    inactiveTrackColor: theme.alternate,
                    inactiveThumbColor: theme.secondaryBackground,
                  ),
                ),
              ],
            ),
          ),
          if (comOrdem) ...[
            const SizedBox(height: 10),
            _rotulo('Ordem de serviço'),
            FutureBuilder<List<GetOrdensServicoRow>>(
              key: ValueKey('ordens_$_listasReloadToken'),
              future: _ordensFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return _carregando();
                final ordens = snapshot.data!;
                if (ordens.isEmpty) {
                  return _aviso(
                    'Nenhuma ordem de serviço sincronizada para esta obra.',
                    icone: Icons.warning_amber_rounded,
                  );
                }

                return _dropdownTarefa(
                  controller: _model.dropDownOrdemValueController ??=
                      FormFieldController<String>(_model.dropDownOrdemValue),
                  options: ordens.map((e) => e.uuid).toList(),
                  optionLabels: ordens.map((e) {
                    final nome = (e.nome ?? '').trim();
                    return nome.isEmpty ? e.codigo : '${e.codigo} — $nome';
                  }).toList(),
                  hint: 'Escolha uma ordem de serviço...',
                  buscaHint: 'Buscar ordem...',
                  onChanged: (val) async {
                    safeSetState(() {
                      _model.dropDownOrdemValue = val;
                      _model.ordemSelected = val;
                      _limparSelecaoTarefa();
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 10),
            _rotulo('Como localizar a tarefa'),
            _seletorModoBusca(),
            const SizedBox(height: 10),
            if (porLista) _selecaoPorOrdem() else _selecaoPorEtapa(),
          ] else ...[
            const SizedBox(height: 10),
            _selecaoPorEtapa(),
          ],
        ],
      ),
    );
  }

  Widget _chip(String texto, Color cor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: cor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            texto,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _linhaDetalhe(String rotulo, String valor) {
    final theme = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 78,
            child: Text(rotulo.toUpperCase(),
                style: rdoColumnLabelStyle(context)),
          ),
          Expanded(
            child: Text(
              valor,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cardTarefaSelecionada() {
    final theme = FlutterFlowTheme.of(context);

    if (!_temTarefa) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        decoration: BoxDecoration(
          color: theme.primaryBackground.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(kRdoRadius),
          border: Border.all(color: theme.alternate),
        ),
        child: Row(
          children: [
            Icon(Icons.touch_app_outlined, size: 18, color: theme.secondaryText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Nenhuma tarefa selecionada. Escolha uma tarefa acima para '
                'continuar.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  height: 1.3,
                  color: theme.secondaryText,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<GetDetalhesTarefaRow>>(
      future: SQLiteManager.instance.getDetalhesTarefa(
        uuid: _model.tarefaSelected!,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _carregando();
        final tarefa = snapshot.data!.firstOrNull;
        if (tarefa == null) {
          return _aviso(
            'Não foi possível carregar os detalhes desta tarefa.',
            icone: Icons.error_outline_rounded,
          );
        }

        final unidade = (tarefa.unidade ?? '').trim();
        final planejado = (tarefa.qtd ?? '').trim();

        return RdoSectionCard(
          title: 'Tarefa selecionada',
          icon: Icons.task_alt_rounded,
          margin: EdgeInsets.zero,
          contentPadding: const EdgeInsets.all(12),
          trailing: Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: theme.success,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                valueOrDefault<String>(tarefa.descricao, 'Sem descrição'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    _statusTarefaLabel(tarefa.status),
                    _statusTarefaColor(context, tarefa.status),
                  ),
                  _chip(
                    'Prioridade ${_prioridadeTarefaLabel(tarefa.porcentagem).toLowerCase()}',
                    _prioridadeTarefaColor(context, tarefa.porcentagem),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: theme.alternate),
              const SizedBox(height: 10),
              _linhaDetalhe(
                'Local',
                valueOrDefault<String>(tarefa.local, 'Não informado'),
              ),
              if ((tarefa.item ?? '').trim().isNotEmpty)
                _linhaDetalhe('Item', tarefa.item!.trim()),
              _linhaDetalhe(
                'Planejado',
                planejado.isEmpty
                    ? 'Não informado'
                    : '$planejado${unidade.isEmpty ? '' : ' $unidade'}',
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _avancar() async {
    if (_salvando || !_temTarefa) return;
    safeSetState(() => _salvando = true);
    try {
      final detalhes = await SQLiteManager.instance.getDetalhesTarefa(
        uuid: _model.tarefaSelected!,
      );
      final tarefa = detalhes.firstOrNull;
      if (tarefa == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Não foi possível carregar a tarefa.'),
            backgroundColor: FlutterFlowTheme.of(context).error,
          ),
        );
        return;
      }

      _model.relatorioDetalhes = await SQLiteManager.instance.relatorioDetalhes(
        uuid: widget.relatorioUuid!,
        userUuid: FFAppState().creatorUuid,
        accountOwnerUuid: FFAppState().creatorUuid,
      );
      _model.uuid = await actions.generateUuid();

      int? ordemIdInsert;
      String? ordemUuidInsert;
      if (_model.switchOrdemValue == true) {
        final sel =
            (_model.dropDownOrdemValue ?? _model.ordemSelected ?? '').trim();
        if (sel.isNotEmpty && sel != '0') {
          ordemUuidInsert = sel;
          final obraUuid = widget.obraUuid;
          if (obraUuid != null && obraUuid.isNotEmpty) {
            final ordensRows = await SQLiteManager.instance.getOrdensServico(
              obraUuid: obraUuid,
              userId: FFAppState().creatorId,
            );
            ordemIdInsert = ordensRows
                .where((o) => o.uuid == ordemUuidInsert)
                .firstOrNull
                ?.id;
          }
        }
      }

      await SQLiteManager.instance.insertAtividadeRelatorio(
        userId: FFAppState().UserID,
        relatorioId: widget.relatorioID!,
        createdBy: FFAppState().UserID.toString(),
        local: tarefa.local,
        descricao: tarefa.descricao,
        quantidade: 0,
        unidade: tarefa.unidade,
        item: tarefa.item,
        tarefaId: tarefa.id,
        ordemId: ordemIdInsert,
        ordemUuid: ordemUuidInsert,
        relatorioUuid: _model.relatorioDetalhes?.firstOrNull?.uuid,
        uuid: _model.uuid!,
        userUuid: FFAppState().creatorUuid,
        tarefaUuid: tarefa.uuid,
      );
      _model.atividadeResult =
          await SQLiteManager.instance.carregaUltimaAtividadeRelatorio();

      if (!mounted) return;
      context.pushNamed(
        AddAtividadeRelatorioWidget.routeName,
        queryParameters: {
          'relatorioId': serializeParam(widget.relatorioID, ParamType.int),
          'obraId': serializeParam(widget.obraId, ParamType.int),
          'atividadeId': serializeParam(
            _model.atividadeResult?.firstOrNull?.id,
            ParamType.int,
          ),
          'atividadeUuid': serializeParam(
            _model.atividadeResult?.firstOrNull?.uuid,
            ParamType.String,
          ),
          'relatorioUuid':
              serializeParam(widget.relatorioUuid, ParamType.String),
          'obraUuid': serializeParam(widget.obraUuid, ParamType.String),
          'novaAtividade': serializeParam(true, ParamType.bool),
        }.withoutNulls,
      );
    } finally {
      if (mounted) safeSetState(() => _salvando = false);
    }
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
          automaticallyImplyLeading: false,
          elevation: 0.0,
          scrolledUnderElevation: 0.0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0.0,
          toolbarHeight: 58.0,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _voltarParaRelatorio,
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gerenciador de Tarefas',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Vincule a atividade a uma tarefa da obra',
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
        ),
        body: SafeArea(
          top: true,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _cardOrigem(),
                const SizedBox(height: 12),
                _cardTarefaSelecionada(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: theme.secondaryBackground,
            border: Border(top: BorderSide(color: theme.alternate)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _salvando ? null : _voltarParaRelatorio,
                      icon: const Icon(Icons.arrow_back_rounded, size: 16),
                      label: const Text('Voltar'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.secondaryText,
                        minimumSize: const Size(0, 42),
                        side: BorderSide(color: theme.alternate),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: (_temTarefa && !_salvando) ? _avancar : null,
                      icon: _salvando
                          ? const SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: Text(
                          _salvando ? 'Criando...' : 'Avançar para atividade'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: theme.alternate,
                        disabledForegroundColor: theme.secondaryText,
                        minimumSize: const Size(0, 42),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
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
}

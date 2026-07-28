import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/includes/atividade_produtividade.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_equipamento_atividade_relatorio/qtd_field_equipamento_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_equipamento_realizado_atividade_relatorio/qtd_field_equipamento_realizado_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_produzida_item_atividade/qtd_field_produzida_item_atividade_widget.dart';
import '/componentes/dialogs/cofirma_exclusao_item_atividade/cofirma_exclusao_item_atividade_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'equipamentos_atividade_relatorio_model.dart';
export 'equipamentos_atividade_relatorio_model.dart';

class _EquipListaData {
  const _EquipListaData(this.itens, this.atividade);
  final List<GetItensAtividadeRow> itens;
  final GetDadosAtividadeRow? atividade;
}

class EquipamentosAtividadeRelatorioWidget extends StatefulWidget {
  const EquipamentosAtividadeRelatorioWidget({
    super.key,
    required this.relatorioUuid,
    required this.atividadeUuid,
    this.listRefreshToken = 0,
  });

  final String? relatorioUuid;
  final String? atividadeUuid;
  final int listRefreshToken;

  @override
  State<EquipamentosAtividadeRelatorioWidget> createState() =>
      _EquipamentosAtividadeRelatorioWidgetState();
}

class _EquipamentosAtividadeRelatorioWidgetState
    extends State<EquipamentosAtividadeRelatorioWidget> {
  late EquipamentosAtividadeRelatorioModel _model;
  int _listReloadToken = 0;
  late Future<_EquipListaData> _itensFuture;

  Future<_EquipListaData> _loadItens() async {
    final itens = await SQLiteManager.instance.getItensAtividade(
      atividadeUuid: widget.atividadeUuid!,
      tipo: 'equipamento',
    );
    final ativRows = await SQLiteManager.instance.getDadosAtividade(
      uuid: widget.atividadeUuid!,
    );
    return _EquipListaData(itens, ativRows.firstOrNull);
  }

  void _recarregarLista() {
    setState(() {
      _listReloadToken++;
      _itensFuture = _loadItens();
    });
    _model.onUpdate();
  }

  String _fmtProd(num n) {
    final v = n.toDouble();
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2).replaceAll('.', ',');
  }

  Future<void> _confirmarExclusaoItem(int itemId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          alignment: const AlignmentDirectional(0.0, 0.0)
              .resolve(Directionality.of(context)),
          child: CofirmaExclusaoItemAtividadeWidget(itemID: itemId),
        );
      },
    );
    if (ok == true && mounted) {
      _recarregarLista();
    }
  }

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EquipamentosAtividadeRelatorioModel());
    _itensFuture = _loadItens();
  }

  @override
  void didUpdateWidget(covariant EquipamentosAtividadeRelatorioWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.listRefreshToken != oldWidget.listRefreshToken) {
      _recarregarLista();
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Widget _qtyLabel(String text) {
    return SizedBox(
      height: 32.0,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: FlutterFlowTheme.of(context).labelSmall.override(
                font: GoogleFonts.inter(
                  fontWeight:
                      FlutterFlowTheme.of(context).labelSmall.fontWeight,
                ),
                letterSpacing: 0.0,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        boxShadow: const [
          BoxShadow(
            blurRadius: 3.0,
            color: Color(0x33000000),
            offset: Offset(0.0, 1.0),
          )
        ],
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Equipamentos Utilizados',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      font: GoogleFonts.interTight(
                        fontWeight: FlutterFlowTheme.of(context)
                            .headlineMedium
                            .fontWeight,
                      ),
                      fontSize: 20.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            const SizedBox(height: 12.0),
            FutureBuilder<_EquipListaData>(
              key: ValueKey('equip_ativ_list_$_listReloadToken'),
              future: _itensFuture,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(
                    child: LinearProgressIndicator(
                      color: FlutterFlowTheme.of(context).primary,
                    ),
                  );
                }
                final listaData = snapshot.data!;
                final itens = listaData.itens;
                final atividade = listaData.atividade;
                final unidadeProd = unidadeProdutividadeAtividade(atividade);
                final limiteProd = qtdRealizadaAtividadeNum(atividade);
                final totalProd = somaProdutividadeItens(itens);
                final excede = totalProd - limiteProd > 1e-6;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: itens.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                      itemBuilder: (context, listViewIndex) {
                        final row = itens[listViewIndex];
                        return Container(
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(8.0),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context).alternate,
                            ),
                          ),
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      valueOrDefault<String>(
                                        row.descricao,
                                        'N/A',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyLarge
                                          .override(
                                            font: GoogleFonts.inter(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ),
                                  FlutterFlowIconButton(
                                    borderColor: Colors.transparent,
                                    borderRadius: 16.0,
                                    buttonSize: 32.0,
                                    fillColor:
                                        FlutterFlowTheme.of(context).error,
                                    icon: Icon(
                                      Icons.delete_outline,
                                      color: FlutterFlowTheme.of(context).info,
                                      size: 18.0,
                                    ),
                                    onPressed: () async {
                                      await _confirmarExclusaoItem(row.id);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _qtyLabel('Util. Un'),
                                        wrapWithModel(
                                          model: _model
                                              .qtdFieldEquipamentoAtividadeRelatorioModels
                                              .getModel(
                                            row.id.toString(),
                                            listViewIndex,
                                          ),
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child:
                                              QtdFieldEquipamentoAtividadeRelatorioWidget(
                                            key: Key('Keyq86_${row.id}'),
                                            uuid: row.uuid!,
                                            valor: valueOrDefault<int>(
                                              row.qtdUtilizada,
                                              0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12.0),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _qtyLabel('Real. HM'),
                                        wrapWithModel(
                                          model: _model
                                              .qtdFieldEquipamentoRealizadoAtividadeRelatorioModels
                                              .getModel(
                                            row.id.toString(),
                                            listViewIndex,
                                          ),
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child:
                                              QtdFieldEquipamentoRealizadoAtividadeRelatorioWidget(
                                            key: Key('Keylib_${row.id}'),
                                            uuid: row.uuid!,
                                            valor: valueOrDefault<int>(
                                              row.qtdRealizada,
                                              0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8.0),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _qtyLabel(
                                      'Prod. ${unidadeProd.toUpperCase()}'),
                                  wrapWithModel(
                                    model: _model
                                        .qtdFieldProduzidaItemAtividadeModels
                                        .getModel(
                                      'prod_${row.id}',
                                      listViewIndex,
                                    ),
                                    updateCallback: () => safeSetState(() {}),
                                    child: QtdFieldProduzidaItemAtividadeWidget(
                                      key: Key('Keyprod_eq_${row.id}'),
                                      uuid: row.uuid!,
                                      itemId: row.id,
                                      atividadeUuid: widget.atividadeUuid!,
                                      valor: row.qtdProduzida ?? 0,
                                      tipo: 'equipamento',
                                      unidade: unidadeProd,
                                      onSaved: _recarregarLista,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    if (itens.isNotEmpty) ...[
                      const SizedBox(height: 8.0),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12.0,
                          vertical: 10.0,
                        ),
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context)
                              .primary
                              .withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Wrap(
                          spacing: 16.0,
                          runSpacing: 4.0,
                          children: [
                            Text(
                              'Itens ${itens.length}',
                              style: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    letterSpacing: 0.0,
                                  ),
                            ),
                            Text(
                              'Prod. total ${_fmtProd(totalProd)} / ${_fmtProd(limiteProd)} $unidadeProd',
                              style: FlutterFlowTheme.of(context)
                                  .labelMedium
                                  .override(
                                    font: GoogleFonts.inter(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    color: excede
                                        ? FlutterFlowTheme.of(context).error
                                        : null,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

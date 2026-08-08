import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/includes/atividade_produtividade.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_mao_obra_atividade_relatorio/qtd_field_mao_obra_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_mao_obra_realizado_atividade_relatorio/qtd_field_mao_obra_realizado_atividade_relatorio_widget.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_produzida_item_atividade/qtd_field_produzida_item_atividade_widget.dart';
import '/componentes/dialogs/cofirma_exclusao_item_atividade/cofirma_exclusao_item_atividade_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'mao_obra_atividade_relatorio_model.dart';
export 'mao_obra_atividade_relatorio_model.dart';

class _MaoObraListaData {
  const _MaoObraListaData(this.itens, this.atividade);
  final List<GetItensAtividadeRow> itens;
  final GetDadosAtividadeRow? atividade;
}

class MaoObraAtividadeRelatorioWidget extends StatefulWidget {
  const MaoObraAtividadeRelatorioWidget({
    super.key,
    required this.relatorioUuid,
    required this.atividadeUuid,
    this.listRefreshToken = 0,
    this.qtdRealizadaAtividade,
  });

  final String? relatorioUuid;
  final String? atividadeUuid;
  final int listRefreshToken;

  /// Valor digitado no topo do formulário da atividade (teto da Prod.).
  final ValueGetter<num?>? qtdRealizadaAtividade;

  @override
  State<MaoObraAtividadeRelatorioWidget> createState() =>
      _MaoObraAtividadeRelatorioWidgetState();
}

class _MaoObraAtividadeRelatorioWidgetState
    extends State<MaoObraAtividadeRelatorioWidget> {
  late MaoObraAtividadeRelatorioModel _model;
  int _listReloadToken = 0;
  late Future<_MaoObraListaData> _itensFuture;

  Future<_MaoObraListaData> _loadItens() async {
    final itens = await SQLiteManager.instance.getItensAtividade(
      atividadeUuid: widget.atividadeUuid!,
      tipo: 'mao_obra',
    );
    final ativRows = await SQLiteManager.instance.getDadosAtividade(
      uuid: widget.atividadeUuid!,
    );
    return _MaoObraListaData(itens, ativRows.firstOrNull);
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
    _model = createModel(context, () => MaoObraAtividadeRelatorioModel());
    _itensFuture = _loadItens();
  }

  @override
  void didUpdateWidget(covariant MaoObraAtividadeRelatorioWidget oldWidget) {
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 3.0),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: rdoColumnLabelStyle(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<_MaoObraListaData>(
              key: ValueKey('mao_obra_ativ_list_$_listReloadToken'),
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
                final limiteProd = limiteProdutividadeEfetivo(
                  atividade: atividade,
                  qtdRealizadaFormulario: widget.qtdRealizadaAtividade?.call(),
                );
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
                      separatorBuilder: (_, __) => const SizedBox(height: 6.0),
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
                          padding:
                              const EdgeInsets.fromLTRB(8.0, 4.0, 4.0, 8.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          valueOrDefault<String>(
                                            row.descricao,
                                            'N/A',
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.inter(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.2,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                          ),
                                        ),
                                        if ((row.cargoFuncao ?? '')
                                            .trim()
                                            .isNotEmpty)
                                          Text(
                                            row.cargoFuncao!.trim(),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.inter(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w500,
                                              height: 1.25,
                                              color: FlutterFlowTheme.of(context)
                                                  .secondaryText,
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  FlutterFlowIconButton(
                                    borderColor: Colors.transparent,
                                    borderRadius: 16.0,
                                    buttonSize: 30.0,
                                    fillColor: Colors.transparent,
                                    icon: Icon(
                                      Icons.delete_outline_rounded,
                                      color: FlutterFlowTheme.of(context).error,
                                      size: 18.0,
                                    ),
                                    onPressed: () async {
                                      await _confirmarExclusaoItem(row.id);
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4.0),
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
                                              .qtdFieldMaoObraAtividadeRelatorioModels
                                              .getModel(
                                            row.id.toString(),
                                            listViewIndex,
                                          ),
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child:
                                              QtdFieldMaoObraAtividadeRelatorioWidget(
                                            key: Key('Key5qv_${row.id}'),
                                            uuid: row.uuid!,
                                            valor: valueOrDefault<int>(
                                              row.qtdUtilizada?.round(),
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
                                        _qtyLabel('Real. HH'),
                                        wrapWithModel(
                                          model: _model
                                              .qtdFieldMaoObraRealizadoAtividadeRelatorioModels
                                              .getModel(
                                            row.id.toString(),
                                            listViewIndex,
                                          ),
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child:
                                              QtdFieldMaoObraRealizadoAtividadeRelatorioWidget(
                                            key: Key('Key9fm_${row.id}'),
                                            uuid: row.uuid!,
                                            valor: valueOrDefault<int>(
                                              row.qtdRealizada?.round(),
                                              0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6.0),
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
                                      key: Key('Keyprod_mo_${row.id}'),
                                      uuid: row.uuid!,
                                      itemId: row.id,
                                      atividadeUuid: widget.atividadeUuid!,
                                      valor: row.qtdProduzida ?? 0,
                                      tipo: 'mao_obra',
                                      unidade: unidadeProd,
                                      qtdRealizadaAtividade:
                                          widget.qtdRealizadaAtividade,
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

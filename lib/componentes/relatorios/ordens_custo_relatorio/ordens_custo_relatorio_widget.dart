import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_custo_relatorio/cofirma_exclusao_custo_relatorio_widget.dart';
import '/componentes/forms/qtd_custo_item_ordem_relatorio/qtd_custo_item_ordem_relatorio_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'ordens_custo_relatorio_model.dart';
export 'ordens_custo_relatorio_model.dart';

String _formatarDataOrdemServico(String? raw) {
  if (raw == null || raw.trim().isEmpty) {
    return '—';
  }
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed != null) {
    return dateTimeFormat('dd/MM/yyyy', parsed);
  }
  return raw.trim();
}

String _formatarQuantidadeCusto(num? v) {
  if (v == null) return '0';
  final d = v.toDouble();
  if (d == d.roundToDouble()) {
    return d.toInt().toString();
  }
  return d.toStringAsFixed(2);
}

String _labelNomeOrdem(GetOrdensServicoRelatorioRow r) {
  final n = r.nome?.trim();
  if (n != null && n.isNotEmpty) return n;
  final o = r.observacoes?.trim();
  if (o != null && o.isNotEmpty) return o;
  return 'Ordem de serviço';
}

/// crie para mim um componente de listagem de ordens de serviço vinculadas a
/// um relatorio, na ordem coloquei o codigo, o nome, o periodo dela e status
/// e para cada ordem tem a lsitagem dos itens de custos previstos da ordem,
/// com nome do item qtd planejada, saldo e um text para inserir a qtd
/// realizada no dia
class OrdensCustoRelatorioWidget extends StatefulWidget {
  const OrdensCustoRelatorioWidget({
    super.key,
    required this.relatorioId,
    required this.relatorioUuid,
  });

  final int? relatorioId;
  final String? relatorioUuid;

  @override
  State<OrdensCustoRelatorioWidget> createState() =>
      _OrdensCustoRelatorioWidgetState();
}

class _OrdensCustoRelatorioWidgetState
    extends State<OrdensCustoRelatorioWidget> {
  late OrdensCustoRelatorioModel _model;

  /// Quantidade digitada no campo (por id do item em `relatorio_custos`) para recalcular saldo ao vivo.
  final Map<int, int> _qtdRealizadaDigitadaPorItemId = {};

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OrdensCustoRelatorioModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          boxShadow: [
            BoxShadow(
              blurRadius: 4.0,
              color: Color(0x33000000),
              offset: Offset(
                0.0,
                2.0,
              ),
              spreadRadius: 0.0,
            )
          ],
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<List<GetOrdensServicoRelatorioRow>>(
                    future: SQLiteManager.instance.getOrdensServicoRelatorio(
                      relatorioUuid: widget!.relatorioUuid!,
                    ),
                    builder: (context, snapshot) {
                      // Customize what your widget looks like when it's loading.
                      if (!snapshot.hasData) {
                        return Center(
                          child: LinearProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        );
                      }
                      final listViewGetOrdensServicoRelatorioRowList =
                          snapshot.data!;

                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        scrollDirection: Axis.vertical,
                        itemCount:
                            listViewGetOrdensServicoRelatorioRowList.length,
                        itemBuilder: (context, listViewIndex) {
                          final listViewGetOrdensServicoRelatorioRow =
                              listViewGetOrdensServicoRelatorioRowList[
                                  listViewIndex];
                          return Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 8.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(8.0),
                                border: Border.all(
                                  color: FlutterFlowTheme.of(context).alternate,
                                  width: 1.0,
                                ),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(4.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                valueOrDefault<String>(
                                                  listViewGetOrdensServicoRelatorioRow
                                                      .codigo,
                                                  'N/A',
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .titleSmall
                                                        .override(
                                                          font: GoogleFonts
                                                              .interTight(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .titleSmall
                                                                    .fontStyle,
                                                          ),
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primary,
                                                          letterSpacing: 0.0,
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .titleSmall
                                                                  .fontStyle,
                                                        ),
                                              ),
                                              Text(
                                                _labelNomeOrdem(
                                                  listViewGetOrdensServicoRelatorioRow,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .override(
                                                          font:
                                                              GoogleFonts.inter(
                                                            fontWeight:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontWeight,
                                                            fontStyle:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodySmall
                                                                    .fontStyle,
                                                          ),
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontWeight,
                                                          fontStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodySmall
                                                                  .fontStyle,
                                                        ),
                                              ),
                                              Text(
                                                'Período: ${_formatarDataOrdemServico(listViewGetOrdensServicoRelatorioRow.dataInicio)} – ${_formatarDataOrdemServico(listViewGetOrdensServicoRelatorioRow.dataFim)}',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .labelSmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontWeight,
                                                        fontStyle:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .labelSmall
                                                                .fontStyle,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelSmall
                                                              .fontWeight,
                                                      fontStyle:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .labelSmall
                                                              .fontStyle,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.max,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Builder(
                                                builder: (context) =>
                                                    FlutterFlowIconButton(
                                                  borderRadius: 8.0,
                                                  buttonSize: 30.0,
                                                  icon: FaIcon(
                                                    FontAwesomeIcons.trashAlt,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primary,
                                                    size: 14.0,
                                                  ),
                                                  onPressed: () async {
                                                    await showDialog(
                                                      context: context,
                                                      builder: (dialogContext) {
                                                        return Dialog(
                                                          elevation: 0,
                                                          insetPadding:
                                                              EdgeInsets.zero,
                                                          backgroundColor:
                                                              Colors
                                                                  .transparent,
                                                          alignment: AlignmentDirectional(
                                                                  0.0, 0.0)
                                                              .resolve(
                                                                  Directionality.of(
                                                                      context)),
                                                          child:
                                                              CofirmaExclusaoCustoRelatorioWidget(
                                                            uuid:
                                                                listViewGetOrdensServicoRelatorioRow
                                                                    .uuid!,
                                                          ),
                                                        );
                                                      },
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Itens de Custo Previstos',
                                          style: FlutterFlowTheme.of(context)
                                              .bodySmall
                                              .override(
                                                font: GoogleFonts.inter(
                                                  fontWeight: FontWeight.bold,
                                                  fontStyle:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodySmall
                                                          .fontStyle,
                                                ),
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.bold,
                                                fontStyle:
                                                    FlutterFlowTheme.of(context)
                                                        .bodySmall
                                                        .fontStyle,
                                              ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            FutureBuilder<
                                                List<
                                                    GetCustosOrdensRelatoriosRow>>(
                                              future: SQLiteManager.instance
                                                  .getCustosOrdensRelatorios(
                                                ordemRelatorioUuid:
                                                    listViewGetOrdensServicoRelatorioRow
                                                        .uuid!,
                                              ),
                                              builder: (context, snapshot) {
                                                // Customize what your widget looks like when it's loading.
                                                if (!snapshot.hasData) {
                                                  return Center(
                                                    child:
                                                        LinearProgressIndicator(
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                    ),
                                                  );
                                                }
                                                final listViewGetCustosOrdensRelatoriosRowList =
                                                    snapshot.data!;

                                                return ListView.builder(
                                                  padding: EdgeInsets.zero,
                                                  shrinkWrap: true,
                                                  scrollDirection:
                                                      Axis.vertical,
                                                  itemCount:
                                                      listViewGetCustosOrdensRelatoriosRowList
                                                          .length,
                                                  itemBuilder:
                                                      (context, listViewIndex) {
                                                    final listViewGetCustosOrdensRelatoriosRow =
                                                        listViewGetCustosOrdensRelatoriosRowList[
                                                            listViewIndex];
                                                    final custoItemId =
                                                        listViewGetCustosOrdensRelatoriosRow
                                                            .id;
                                                    final qtdPrevista =
                                                        listViewGetCustosOrdensRelatoriosRow
                                                                .qtdPrevista ??
                                                            0.0;
                                                    final qtdDigitada =
                                                        _qtdRealizadaDigitadaPorItemId
                                                                .containsKey(
                                                                    custoItemId)
                                                            ? _qtdRealizadaDigitadaPorItemId[
                                                                custoItemId]!
                                                            : (listViewGetCustosOrdensRelatoriosRow
                                                                    .qtdRealizada ??
                                                                0);
                                                    final saldoCusto =
                                                        qtdPrevista -
                                                            qtdDigitada;
                                                    final unidadeStr =
                                                        valueOrDefault<String>(
                                                      listViewGetCustosOrdensRelatoriosRow
                                                          .unidade,
                                                      '',
                                                    );
                                                    return Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0, 0, 0, 0),
                                                      child: Container(
                                                        decoration:
                                                            BoxDecoration(
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryBackground,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(
                                                                      4.0),
                                                        ),
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      4.0,
                                                                      4.0,
                                                                      4.0,
                                                                      4.0),
                                                          child: Row(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            mainAxisAlignment:
                                                                MainAxisAlignment
                                                                    .spaceBetween,
                                                            children: [
                                                              Expanded(
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      valueOrDefault<
                                                                          String>(
                                                                        listViewGetCustosOrdensRelatoriosRow
                                                                            .descricao,
                                                                        'N/A',
                                                                      ),
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            font:
                                                                                GoogleFonts.inter(
                                                                              fontWeight: FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                              fontStyle: FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                            ),
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                                                                            fontStyle:
                                                                                FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                                                                          ),
                                                                    ),
                                                                    Row(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      children:
                                                                          [
                                                                        Text(
                                                                          'Qtd planejada: ${_formatarQuantidadeCusto(qtdPrevista)}${unidadeStr.isNotEmpty ? ' $unidadeStr' : ''}',
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .labelSmall
                                                                              .override(
                                                                                font: GoogleFonts.inter(
                                                                                  fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                                                                                ),
                                                                                color: FlutterFlowTheme.of(context).secondaryText,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                                                                              ),
                                                                        ),
                                                                        Text(
                                                                          'Saldo: ${_formatarQuantidadeCusto(saldoCusto)}${unidadeStr.isNotEmpty ? ' $unidadeStr' : ''}',
                                                                          style: FlutterFlowTheme.of(context)
                                                                              .labelSmall
                                                                              .override(
                                                                                font: GoogleFonts.inter(
                                                                                  fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                                                                                  fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                                                                                ),
                                                                                color: FlutterFlowTheme.of(context).tertiary,
                                                                                letterSpacing: 0.0,
                                                                                fontWeight: FlutterFlowTheme.of(context).labelSmall.fontWeight,
                                                                                fontStyle: FlutterFlowTheme.of(context).labelSmall.fontStyle,
                                                                              ),
                                                                        ),
                                                                      ].divide(SizedBox(
                                                                              width: 8.0)),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                              Row(
                                                                mainAxisSize:
                                                                    MainAxisSize
                                                                        .max,
                                                                children: [
                                                                  wrapWithModel(
                                                                    model: _model
                                                                        .qtdCustoItemOrdemRelatorioModels
                                                                        .getModel(
                                                                      listViewGetCustosOrdensRelatoriosRow
                                                                          .id
                                                                          .toString(),
                                                                      listViewIndex,
                                                                    ),
                                                                    updateCallback: () =>
                                                                        safeSetState(
                                                                            () {}),
                                                                    child:
                                                                        QtdCustoItemOrdemRelatorioWidget(
                                                                      key: Key(
                                                                        'Keyglh_${listViewGetCustosOrdensRelatoriosRow.id.toString()}',
                                                                      ),
                                                                      uuid: listViewGetCustosOrdensRelatoriosRow
                                                                          .uuid!,
                                                                      relatorioUuid:
                                                                          widget!
                                                                              .relatorioUuid!,
                                                                      valor: valueOrDefault<
                                                                          int>(
                                                                        listViewGetCustosOrdensRelatoriosRow
                                                                            .qtdRealizada,
                                                                        0,
                                                                      ),
                                                                      onQuantidadeChanged:
                                                                          (v) {
                                                                        safeSetState(
                                                                            () {
                                                                          _qtdRealizadaDigitadaPorItemId[custoItemId] =
                                                                              v ?? 0;
                                                                        });
                                                                      },
                                                                    ),
                                                                  ),
                                                                ].divide(SizedBox(
                                                                    width:
                                                                        8.0)),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          ].divide(SizedBox(height: 4.0)),
                                        ),
                                      ].divide(SizedBox(height: 6.0)),
                                    ),
                                  ].divide(SizedBox(height: 8.0)),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ].divide(SizedBox(height: 12.0)),
              ),
            ].divide(SizedBox(height: 16.0)),
          ),
        ),
      ),
    );
  }
}

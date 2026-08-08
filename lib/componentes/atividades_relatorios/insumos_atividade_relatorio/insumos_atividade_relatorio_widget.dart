import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/atividades_relatorios/includes/qtd_field_insumo_atividade_relatorio/qtd_field_insumo_atividade_relatorio_widget.dart';
import '/componentes/dialogs/cofirma_exclusao_item_atividade/cofirma_exclusao_item_atividade_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'insumos_atividade_relatorio_model.dart';
export 'insumos_atividade_relatorio_model.dart';

/// crie para mim um componente chamado insumos nele vai ser listado os
/// insumos utilizados em uma atividade de uma obra eu preciso que em cada
/// item da listagem tenha o nome do insumo, a quantidade utilizada em
/// textfield o valor do estoque disponivel e uma barra de progresso que vai
/// mostrar o tanto do estoque utilizado de acordo com o preenchido no
/// textfield que vai calcular com o estoque tbm preciso que coloque um botão
/// de exclusão e acima de toda listagem colocar um contador mostrando a
/// quantidade total de itens que foi lançado
class InsumosAtividadeRelatorioWidget extends StatefulWidget {
  const InsumosAtividadeRelatorioWidget({
    super.key,
    required this.relatorioUuid,
    required this.atividadeUuid,
    this.listRefreshToken = 0,
  });

  final String? relatorioUuid;
  final String? atividadeUuid;
  final int listRefreshToken;

  @override
  State<InsumosAtividadeRelatorioWidget> createState() =>
      _InsumosAtividadeRelatorioWidgetState();
}

class _InsumosAtividadeRelatorioWidgetState
    extends State<InsumosAtividadeRelatorioWidget> {
  late InsumosAtividadeRelatorioModel _model;
  int _listReloadToken = 0;
  late Future<List<GetItensAtividadeRow>> _itensFuture;

  Future<List<GetItensAtividadeRow>> _loadItens() {
    return SQLiteManager.instance.getItensAtividade(
      atividadeUuid: widget.atividadeUuid!,
      tipo: 'insumo',
    );
  }

  void _recarregarLista() {
    setState(() {
      _listReloadToken++;
      _itensFuture = _loadItens();
    });
    _model.onUpdate();
  }

  Future<void> _confirmarExclusaoItem(int itemId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          alignment: AlignmentDirectional(0.0, 0.0)
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
    _model = createModel(context, () => InsumosAtividadeRelatorioModel());
    _itensFuture = _loadItens();
  }

  @override
  void didUpdateWidget(covariant InsumosAtividadeRelatorioWidget oldWidget) {
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.transparent,
        ),
        child: Padding(
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FutureBuilder<List<GetItensAtividadeRow>>(
                    key: ValueKey('insumos_ativ_list_$_listReloadToken'),
                    future: _itensFuture,
                    builder: (context, snapshot) {
                      // Customize what your widget looks like when it's loading.
                      if (!snapshot.hasData) {
                        return Center(
                          child: LinearProgressIndicator(
                            color: FlutterFlowTheme.of(context).primary,
                          ),
                        );
                      }
                      final listViewGetItensAtividadeRowList = snapshot.data!;

                      return ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        scrollDirection: Axis.vertical,
                        itemCount: listViewGetItensAtividadeRowList.length,
                        itemBuilder: (context, listViewIndex) {
                          final listViewGetItensAtividadeRow =
                              listViewGetItensAtividadeRowList[listViewIndex];
                          final saldoObra =
                              listViewGetItensAtividadeRow.obraItemQtd;
                          final unidadeObra = valueOrDefault<String>(
                            listViewGetItensAtividadeRow.obraItemUnidade,
                            '',
                          );
                          final qtdUsada =
                              listViewGetItensAtividadeRow.qtdUtilizada ?? 0;
                          final unidadeSuffix =
                              unidadeObra.isNotEmpty ? ' $unidadeObra' : '';
                          final temSaldo =
                              saldoObra != null && saldoObra > 0;
                          final fracaoUso = temSaldo
                              ? (qtdUsada / saldoObra!).clamp(0.0, 1.0)
                              : 0.0;
                          final pctUso = (fracaoUso * 100).round();

                          return Container(
                            margin: const EdgeInsets.only(bottom: 6.0),
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: FlutterFlowTheme.of(context).alternate,
                                width: 1.0,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  8.0, 4.0, 4.0, 6.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          valueOrDefault<String>(
                                            listViewGetItensAtividadeRow
                                                .descricao,
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
                                      ),
                                      Builder(
                                        builder: (context) =>
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
                                            await _confirmarExclusaoItem(
                                              listViewGetItensAtividadeRow.id,
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Expanded(
                                        flex: 7,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                  bottom: 3),
                                              child: Text(
                                                'QTD. UTILIZADA',
                                                style: rdoColumnLabelStyle(
                                                    context),
                                              ),
                                            ),
                                            wrapWithModel(
                                              model: _model
                                                  .qtdFieldInsumoAtividadeRelatorioModels
                                                  .getModel(
                                                listViewGetItensAtividadeRow.id
                                                    .toString(),
                                                listViewIndex,
                                              ),
                                              updateCallback: () =>
                                                  safeSetState(() {}),
                                              child:
                                                  QtdFieldInsumoAtividadeRelatorioWidget(
                                                key: Key(
                                                  'Keyv5i_${listViewGetItensAtividadeRow.id.toString()}',
                                                ),
                                                uuid:
                                                    listViewGetItensAtividadeRow
                                                        .uuid!,
                                                valor: listViewGetItensAtividadeRow
                                                        .qtdUtilizada ??
                                                    0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 13,
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 14.0, 0.0, 0.0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        8.0, 0.0, 8.0, 0.0),
                                                child: Text(
                                                  temSaldo
                                                      ? 'Saldo na obra: $saldoObra$unidadeSuffix'
                                                      : 'Saldo na obra: não informado',
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
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
                                              ),
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        8.0, 0.0, 8.0, 0.0),
                                                child: Container(
                                                  width: double.infinity,
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Row(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .spaceBetween,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              temSaldo
                                                                  ? 'Uso na atividade: $pctUso%'
                                                                  : 'Uso na atividade: —',
                                                              maxLines: 1,
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .labelSmall
                                                                  .override(
                                                                    font:
                                                                        GoogleFonts
                                                                            .inter(
                                                                      fontWeight: FlutterFlowTheme.of(
                                                                              context)
                                                                          .labelSmall
                                                                          .fontWeight,
                                                                      fontStyle: FlutterFlowTheme.of(
                                                                              context)
                                                                          .labelSmall
                                                                          .fontStyle,
                                                                    ),
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                          .fontStyle,
                                                                  ),
                                                            ),
                                                          ),
                                                          Text(
                                                            '$qtdUsada$unidadeSuffix',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .labelSmall
                                                                .override(
                                                                  font:
                                                                      GoogleFonts
                                                                          .inter(
                                                                    fontWeight: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                        .fontWeight,
                                                                    fontStyle: FlutterFlowTheme.of(
                                                                            context)
                                                                        .labelSmall
                                                                        .fontStyle,
                                                                  ),
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .primary,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontWeight,
                                                                  fontStyle: FlutterFlowTheme.of(
                                                                          context)
                                                                      .labelSmall
                                                                      .fontStyle,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(3.0),
                                                        child: SizedBox(
                                                          width:
                                                              double.infinity,
                                                          height: 6.0,
                                                          child:
                                                              LinearProgressIndicator(
                                                            value: temSaldo
                                                                ? fracaoUso
                                                                : 0,
                                                            backgroundColor:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .alternate,
                                                            color:
                                                                FlutterFlowTheme.of(
                                                                        context)
                                                                    .primary,
                                                            minHeight: 6.0,
                                                          ),
                                                        ),
                                                      ),
                                                    ].divide(
                                                        SizedBox(height: 4.0)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 8.0)),
                                  ),
                                ].divide(SizedBox(height: 2.0)),
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

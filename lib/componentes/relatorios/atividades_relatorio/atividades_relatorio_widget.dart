import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_atividade_relatorio/cofirma_exclusao_atividade_relatorio_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:ui';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'atividades_relatorio_model.dart';
export 'atividades_relatorio_model.dart';

String _statusAtividadeLabel(int situacao) {
  switch (situacao) {
    case 1:
      return 'Em andamento';
    case 0:
      return 'Paralizada';
    case 2:
      return 'Concluída';
    default:
      return 'Status ($situacao)';
  }
}

/// crie para mim um componente chamado atividades, ele vai listar atividades
/// realizadas de um relatorio de rdo, cada atividade vai ter um titulo
/// algumas vão ter como referencia uma etapa as que nao tiverem etapa serão
/// avulsas preciso que apareça a quantidade realizada da atividade a situação
/// dela e botões para editar, ver e apagar atividade
class AtividadesRelatorioWidget extends StatefulWidget {
  const AtividadesRelatorioWidget({
    super.key,
    required this.relatorioId,
    required this.relatorioUuid,
    required this.obraUuid,
  });

  final int? relatorioId;
  final String? relatorioUuid;
  final String? obraUuid;

  @override
  State<AtividadesRelatorioWidget> createState() =>
      _AtividadesRelatorioWidgetState();
}

class _AtividadesRelatorioWidgetState extends State<AtividadesRelatorioWidget> {
  late AtividadesRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AtividadesRelatorioModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
      ),
      child: FutureBuilder<List<RelatorioDetalhesRow>>(
        future: SQLiteManager.instance.relatorioDetalhes(
          uuid: widget!.relatorioId!.toString(),
          userUuid: FFAppState().creatorId.toString(),
          accountOwnerUuid: FFAppState().creatorUuid,
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
          final containerRelatorioDetalhesRowList = snapshot.data!;

          return Container(
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0, 0, 0, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FutureBuilder<List<GetAtividadesRelatorioRow>>(
                        future: SQLiteManager.instance.getAtividadesRelatorio(
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
                          final listViewGetAtividadesRelatorioRowList =
                              snapshot.data!;

                          final theme = FlutterFlowTheme.of(context);
                          final linhas = listViewGetAtividadesRelatorioRowList;
                          if (linhas.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Nenhuma atividade lançada',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: theme.secondaryText,
                                ),
                              ),
                            );
                          }

                          return Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: theme.alternate),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding:
                                      const EdgeInsets.fromLTRB(10, 7, 10, 7),
                                  decoration: BoxDecoration(
                                    color: theme.primaryBackground
                                        .withValues(alpha: 0.6),
                                    border: Border(
                                      bottom:
                                          BorderSide(color: theme.alternate),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 18,
                                        child: Text(
                                          '#',
                                          style: rdoColumnLabelStyle(context),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          'ATIVIDADE',
                                          style: rdoColumnLabelStyle(context),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 84,
                                        child: Text(
                                          'REALIZADO',
                                          textAlign: TextAlign.end,
                                          style: rdoColumnLabelStyle(context),
                                        ),
                                      ),
                                      const SizedBox(width: 64),
                                    ],
                                  ),
                                ),
                                for (var i = 0; i < linhas.length; i++)
                                  Container(
                                    padding:
                                        const EdgeInsets.fromLTRB(10, 6, 6, 6),
                                    decoration: BoxDecoration(
                                      border: i == linhas.length - 1
                                          ? null
                                          : Border(
                                              bottom: BorderSide(
                                                color: theme.alternate,
                                              ),
                                            ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          child: Text(
                                            '${i + 1}',
                                            style: rdoColumnLabelStyle(context),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                valueOrDefault<String>(
                                                  linhas[i].descricao,
                                                  'N/A',
                                                ),
                                                style: GoogleFonts.inter(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: theme.primaryText,
                                                ),
                                              ),
                                              const SizedBox(height: 3),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: theme.success
                                                          .withValues(
                                                              alpha: 0.12),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6),
                                                    ),
                                                    child: Text(
                                                      _statusAtividadeLabel(
                                                        linhas[i].situacao,
                                                      ),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 9.5,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.3,
                                                        color: theme.success,
                                                      ),
                                                    ),
                                                  ),
                                                  if ((linhas[i].local ?? '')
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                    const SizedBox(width: 6),
                                                    Flexible(
                                                      child: Text(
                                                        linhas[i].local!.trim(),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            GoogleFonts.inter(
                                                          fontSize: 11,
                                                          color: theme
                                                              .secondaryText,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        SizedBox(
                                          width: 84,
                                          child: Text(
                                            '${formatQuantidadeRelatorio(linhas[i].qtdRealizada)} ${linhas[i].unidade ?? ''}'
                                                .trim(),
                                            textAlign: TextAlign.end,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: theme.primaryText,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          tooltip: 'Editar',
                                          icon: Icon(
                                            Icons.edit_outlined,
                                            size: 16,
                                            color: theme.secondaryText,
                                          ),
                                          onPressed: () async {
                                            context.pushNamed(
                                              AddAtividadeRelatorioWidget
                                                  .routeName,
                                              queryParameters: {
                                                'relatorioId': serializeParam(
                                                  widget!.relatorioId,
                                                  ParamType.int,
                                                ),
                                                'obraId': serializeParam(
                                                  containerRelatorioDetalhesRowList
                                                      .firstOrNull?.obraId,
                                                  ParamType.int,
                                                ),
                                                'atividadeId': serializeParam(
                                                  linhas[i].id,
                                                  ParamType.int,
                                                ),
                                                'atividadeUuid': serializeParam(
                                                  linhas[i].uuid,
                                                  ParamType.String,
                                                ),
                                                'relatorioUuid': serializeParam(
                                                  widget!.relatorioUuid,
                                                  ParamType.String,
                                                ),
                                                'obraUuid': serializeParam(
                                                  widget!.obraUuid,
                                                  ParamType.String,
                                                ),
                                              }.withoutNulls,
                                            );
                                          },
                                        ),
                                        IconButton(
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          constraints: const BoxConstraints(
                                            minWidth: 32,
                                            minHeight: 32,
                                          ),
                                          tooltip: 'Excluir',
                                          icon: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 16,
                                            color: theme.error,
                                          ),
                                          onPressed: () async {
                                            await showDialog(
                                              context: context,
                                              builder: (dialogContext) {
                                                return Dialog(
                                                  elevation: 0,
                                                  insetPadding: EdgeInsets.zero,
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  alignment:
                                                      const AlignmentDirectional(
                                                              0.0, 0.0)
                                                          .resolve(
                                                    Directionality.of(context),
                                                  ),
                                                  child:
                                                      CofirmaExclusaoAtividadeRelatorioWidget(
                                                    itemID: linhas[i].id,
                                                  ),
                                                );
                                              },
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ].divide(SizedBox(height: 12.0)),
                  ),
                ].divide(SizedBox(height: 16.0)),
              ),
            ),
          );
        },
      ),
    );
  }
}

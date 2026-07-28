import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_material_recebido/cofirma_exclusao_material_recebido_widget.dart';
import '/componentes/forms/qtd_material_recebido_text/qtd_material_recebido_text_widget.dart';
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'materiais_recebidos_relatorio_model.dart';
export 'materiais_recebidos_relatorio_model.dart';

/// Lista materiais recebidos no dia de um relatório de RDO (nome, unidade, qtd, excluir).
class MateriaisRecebidosRelatorioWidget extends StatefulWidget {
  const MateriaisRecebidosRelatorioWidget({
    super.key,
    required this.relatorioId,
    required this.relatorioUuid,
  });

  final int? relatorioId;
  final String? relatorioUuid;

  @override
  State<MateriaisRecebidosRelatorioWidget> createState() =>
      _MateriaisRecebidosRelatorioWidgetState();
}

class _MateriaisRecebidosRelatorioWidgetState
    extends State<MateriaisRecebidosRelatorioWidget> {
  late MateriaisRecebidosRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MateriaisRecebidosRelatorioModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    return FutureBuilder<List<EquipamentosRecebidosObraRow>>(
      future: SQLiteManager.instance.equipamentosRecebidosObra(
        relatorioUuid: widget!.relatorioUuid!,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: LinearProgressIndicator(
              color: theme.primary,
            ),
          );
        }
        final listViewEquipamentosRecebidosObraRowList = snapshot.data!;

        return ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: listViewEquipamentosRecebidosObraRowList.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, listViewIndex) {
            final listViewEquipamentosRecebidosObraRow =
                listViewEquipamentosRecebidosObraRowList[listViewIndex];
            return Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.primaryBackground,
                borderRadius: BorderRadius.circular(8.0),
                border: Border.all(
                  color: theme.alternate,
                  width: 1.0,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(8.0, 4.0, 8.0, 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            valueOrDefault<String>(
                              listViewEquipamentosRecebidosObraRow.descricao,
                              'ND',
                            ),
                            style: theme.bodyMedium.override(
                              font: GoogleFonts.inter(
                                fontWeight: FontWeight.w600,
                                fontStyle: theme.bodyMedium.fontStyle,
                              ),
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                              fontStyle: theme.bodyMedium.fontStyle,
                            ),
                          ),
                          Text(
                            valueOrDefault<String>(
                              'Unidade: ${valueOrDefault<String>(
                                listViewEquipamentosRecebidosObraRow.unidade,
                                'Un',
                              )}',
                              'ND',
                            ),
                            style: theme.labelSmall.override(
                              font: GoogleFonts.inter(
                                fontWeight: theme.labelSmall.fontWeight,
                                fontStyle: theme.labelSmall.fontStyle,
                              ),
                              color: theme.secondaryText,
                              letterSpacing: 0.0,
                              fontWeight: theme.labelSmall.fontWeight,
                              fontStyle: theme.labelSmall.fontStyle,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 80.0,
                      child: wrapWithModel(
                        model: _model.qtdMaterialRecebidoTextModels.getModel(
                          listViewEquipamentosRecebidosObraRow.id.toString(),
                          listViewIndex,
                        ),
                        updateCallback: () => safeSetState(() {}),
                        child: QtdMaterialRecebidoTextWidget(
                          key: Key(
                            'Keyti3_${listViewEquipamentosRecebidosObraRow.id}',
                          ),
                          uuid: valueOrDefault<String>(
                            listViewEquipamentosRecebidosObraRow.uuid,
                            'gfd',
                          ),
                          relatorioUuid: valueOrDefault<String>(
                            widget!.relatorioUuid,
                            'fd',
                          ),
                          valor: parseQuantidadeRelatorio(
                            listViewEquipamentosRecebidosObraRow.quantidade,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: 'Excluir',
                      icon: FaIcon(
                        FontAwesomeIcons.trashCan,
                        size: 14,
                        color: theme.error,
                      ),
                      onPressed: () async {
                        await showDialog(
                          context: context,
                          builder: (dialogContext) {
                            return Dialog(
                              elevation: 0,
                              insetPadding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              alignment: AlignmentDirectional(0.0, 0.0)
                                  .resolve(Directionality.of(context)),
                              child: CofirmaExclusaoMaterialRecebidoWidget(
                                uuid: valueOrDefault<String>(
                                  listViewEquipamentosRecebidosObraRow.uuid,
                                  'jg',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

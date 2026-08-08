import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_material_recebido/cofirma_exclusao_material_recebido_widget.dart';
import '/componentes/forms/qtd_material_recebido_text/qtd_material_recebido_text_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
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
        final linhas = snapshot.data!;
        if (linhas.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Nenhum material recebido',
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
                padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
                decoration: BoxDecoration(
                  color: theme.primaryBackground.withValues(alpha: 0.6),
                  border: Border(bottom: BorderSide(color: theme.alternate)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: Text('#', style: rdoColumnLabelStyle(context)),
                    ),
                    Expanded(
                      child:
                          Text('MATERIAL', style: rdoColumnLabelStyle(context)),
                    ),
                    SizedBox(
                      width: 54,
                      child: Text(
                        'UNID.',
                        textAlign: TextAlign.center,
                        style: rdoColumnLabelStyle(context),
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: Text(
                        'QTD',
                        textAlign: TextAlign.center,
                        style: rdoColumnLabelStyle(context),
                      ),
                    ),
                    const SizedBox(width: 32),
                  ],
                ),
              ),
              for (var i = 0; i < linhas.length; i++)
                Container(
                  padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                  decoration: BoxDecoration(
                    border: i == linhas.length - 1
                        ? null
                        : Border(
                            bottom: BorderSide(color: theme.alternate),
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
                        child: Text(
                          valueOrDefault<String>(linhas[i].descricao, 'ND'),
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: theme.primaryText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 54,
                        child: Text(
                          valueOrDefault<String>(linhas[i].unidade, 'Un'),
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: theme.secondaryText,
                          ),
                        ),
                      ),
                      SizedBox(
                        width: 80,
                        child: wrapWithModel(
                          model: _model.qtdMaterialRecebidoTextModels.getModel(
                            linhas[i].id.toString(),
                            i,
                          ),
                          updateCallback: () => safeSetState(() {}),
                          child: QtdMaterialRecebidoTextWidget(
                            key: Key('Keyti3_${linhas[i].id}'),
                            uuid: valueOrDefault<String>(linhas[i].uuid, 'gfd'),
                            relatorioUuid: valueOrDefault<String>(
                              widget!.relatorioUuid,
                              'fd',
                            ),
                            valor: parseQuantidadeRelatorio(
                              linhas[i].quantidade,
                            ),
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
                                    linhas[i].uuid,
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
            ],
          ),
        );
      },
    );
  }
}

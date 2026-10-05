import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_custo_relatorio/cofirma_exclusao_custo_relatorio_widget.dart';
import '/componentes/forms/qtd_custo_item_ordem_relatorio/qtd_custo_item_ordem_relatorio_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
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

  Future<List<GetOrdensServicoRelatorioRow>> _carregarOrdens() async {
    await SQLiteManager.instance.sincronizarCustosOsComUsoAtividades(
      relatorioUuid: widget.relatorioUuid,
    );
    return SQLiteManager.instance.getOrdensServicoRelatorio(
      relatorioUuid: widget.relatorioUuid!,
    );
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return FutureBuilder<List<GetOrdensServicoRelatorioRow>>(
      future: _carregarOrdens(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: LinearProgressIndicator(color: theme.primary),
          );
        }
        final ordens = snapshot.data!;
        if (ordens.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Nenhuma ordem de serviço vinculada',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < ordens.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  bottom: i == ordens.length - 1 ? 0 : 10,
                ),
                child: _buildOrdemCard(context, ordens[i]),
              ),
          ],
        );
      },
    );
  }

  Widget _buildOrdemCard(
    BuildContext context,
    GetOrdensServicoRelatorioRow ordem,
  ) {
    final theme = FlutterFlowTheme.of(context);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(10, 6, 4, 6),
            decoration: BoxDecoration(
              color: theme.primaryBackground.withValues(alpha: 0.5),
              border: Border(bottom: BorderSide(color: theme.alternate)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              valueOrDefault<String>(ordem.codigo, 'N/A'),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                                color: theme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _labelNomeOrdem(ordem),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Período: ${_formatarDataOrdemServico(ordem.dataInicio)} – ${_formatarDataOrdemServico(ordem.dataFim)}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: theme.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                  tooltip: 'Desvincular ordem',
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
                          alignment: const AlignmentDirectional(0.0, 0.0)
                              .resolve(Directionality.of(context)),
                          child: CofirmaExclusaoCustoRelatorioWidget(
                            uuid: ordem.uuid!,
                          ),
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
          FutureBuilder<List<GetCustosOrdensRelatoriosRow>>(
            future: SQLiteManager.instance.getCustosOrdensRelatorios(
              ordemRelatorioUuid: ordem.uuid!,
            ),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: LinearProgressIndicator(color: theme.primary),
                );
              }
              final itens =
                  snapshot.data!.where((item) => !item.isFixo).toList();
              if (itens.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(
                    'Nenhum custo variável para lançar. Insumos, mão de obra e equipamentos vêm das atividades; avulsos você informa aqui.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: theme.secondaryText,
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: theme.alternate),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'ITEM DE CUSTO',
                            style: rdoColumnLabelStyle(context),
                          ),
                        ),
                        SizedBox(
                          width: 66,
                          child: Text(
                            'PLANEJ.',
                            textAlign: TextAlign.end,
                            style: rdoColumnLabelStyle(context),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            'SALDO',
                            textAlign: TextAlign.end,
                            style: rdoColumnLabelStyle(context),
                          ),
                        ),
                        SizedBox(
                          width: 84,
                          child: Text(
                            'REALIZADO',
                            textAlign: TextAlign.center,
                            style: rdoColumnLabelStyle(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < itens.length; i++)
                    _buildCustoRow(
                      context,
                      itens[i],
                      i,
                      i == itens.length - 1,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCustoRow(
    BuildContext context,
    GetCustosOrdensRelatoriosRow item,
    int index,
    bool ultimo,
  ) {
    final theme = FlutterFlowTheme.of(context);
    final custoItemId = item.id;
    final qtdPrevista = item.qtdPrevista ?? 0.0;
    final qtdDigitada = _qtdRealizadaDigitadaPorItemId.containsKey(custoItemId)
        ? (_qtdRealizadaDigitadaPorItemId[custoItemId] ?? 0).toDouble()
        : item.qtdRealizadaNum;
    final acumulado = item.qtdAcumuladaNum;
    final saldo = qtdPrevista - acumulado - qtdDigitada;
    final unidade = valueOrDefault<String>(item.unidade, '');
    final sufixo = unidade.isNotEmpty ? ' $unidade' : '';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      decoration: BoxDecoration(
        border:
            ultimo ? null : Border(bottom: BorderSide(color: theme.alternate)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueOrDefault<String>(item.descricao, 'N/A'),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                Text(
                  item.isVinculadoAtividade
                      ? (item.qtdManual
                          ? 'Editado manualmente'
                          : 'Da atividade — editável')
                      : 'Avulso — informe a quantidade',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: theme.secondaryText,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 66,
            child: Text(
              '${_formatarQuantidadeCusto(qtdPrevista)}$sufixo',
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ),
          SizedBox(
            width: 60,
            child: Text(
              '${_formatarQuantidadeCusto(saldo)}$sufixo',
              textAlign: TextAlign.end,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: saldo < 0 ? theme.error : theme.tertiary,
              ),
            ),
          ),
          SizedBox(
            width: 84,
            child: wrapWithModel(
              model: _model.qtdCustoItemOrdemRelatorioModels.getModel(
                item.id.toString(),
                index,
              ),
              updateCallback: () => safeSetState(() {}),
              child: QtdCustoItemOrdemRelatorioWidget(
                key: Key('Keyglh_${item.id}'),
                uuid: item.uuid!,
                relatorioUuid: widget.relatorioUuid!,
                valor: valueOrDefault<int>(
                  item.qtdRealizadaNum.round(),
                  0,
                ),
                hintText: item.isVinculadoAtividade ? 'Da atividade' : 'Qtd',
                onQuantidadeChanged: (v) {
                  safeSetState(() {
                    _qtdRealizadaDigitadaPorItemId[custoItemId] = v ?? 0;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

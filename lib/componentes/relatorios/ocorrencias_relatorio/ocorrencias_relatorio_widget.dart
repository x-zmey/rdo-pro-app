import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_ocorrencia_relatorio/cofirma_exclusao_ocorrencia_relatorio_widget.dart';
import '/componentes/dialogs/editar_ocorrencia_relatorio_modal/editar_ocorrencia_relatorio_modal_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'ocorrencias_relatorio_model.dart';
export 'ocorrencias_relatorio_model.dart';

/// Lista ocorrências do relatório (texto, horários, tipo, situação, autor).
/// Exclusão é lógica (`situacao = -2`); itens excluídos não aparecem na lista.
class OcorrenciasRelatorioWidget extends StatefulWidget {
  const OcorrenciasRelatorioWidget({
    super.key,
    required this.relatoioId,
    required this.relatorioUuid,
  });

  final int? relatoioId;
  final String? relatorioUuid;

  @override
  State<OcorrenciasRelatorioWidget> createState() =>
      _OcorrenciasRelatorioWidgetState();
}

class _OcorrenciasRelatorioWidgetState extends State<OcorrenciasRelatorioWidget> {
  late OcorrenciasRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OcorrenciasRelatorioModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  String _situacaoLabel(int? s) {
    switch (s) {
      case 1:
        return 'Em andamento';
      case 2:
        return 'Em análise';
      case 3:
        return 'Resolvida';
      case 4:
        return 'Não resolvida';
      default:
        return 'Em andamento';
    }
  }

  Color _situacaoAccent(BuildContext context, int? s) {
    final t = FlutterFlowTheme.of(context);
    switch (s) {
      case 2:
        return t.warning;
      case 3:
        return t.success;
      case 4:
        return t.error;
      case 1:
      default:
        return t.primary;
    }
  }

  /// Chips compactos (tipo / status).
  Widget _tipoChip(BuildContext context, String? tipoNome) {
    final t = FlutterFlowTheme.of(context);
    final label = (tipoNome != null && tipoNome.trim().isNotEmpty)
        ? tipoNome.trim()
        : 'Sem tipo';
    final muted = tipoNome == null || tipoNome.trim().isEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: muted
            ? t.alternate.withValues(alpha: 0.45)
            : t.secondary.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: t.alternate,
          width: 1.0,
        ),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: muted ? t.secondaryText : t.primaryText,
        ),
      ),
    );
  }

  Widget _situacaoChip(BuildContext context, int? situacao) {
    final accent = _situacaoAccent(context, situacao);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.55), width: 1.0),
      ),
      child: Text(
        _situacaoLabel(situacao),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);

    return FutureBuilder<List<CarregaOcorrenciasRelatorioRow>>(
      future: SQLiteManager.instance.carregaOcorrenciasRelatorio(
        relatorioUuid: widget.relatorioUuid!,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Center(
            child: LinearProgressIndicator(
              color: theme.primary,
            ),
          );
        }
        final rows = snapshot.data!;

        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(0.0, 8.0, 0.0, 8.0),
            child: Text(
              'Nenhuma ocorrência registrada.',
              style: theme.bodySmall.override(
                font: GoogleFonts.inter(
                  fontWeight: theme.bodySmall.fontWeight,
                  fontStyle: theme.bodySmall.fontStyle,
                ),
                color: theme.secondaryText,
                letterSpacing: 0.0,
              ),
            ),
          );
        }

        return ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final row = rows[index];
            return Material(
              color: Colors.transparent,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.primaryBackground,
                  borderRadius: BorderRadius.circular(10.0),
                  border: Border.all(
                    color: theme.alternate,
                    width: 1.0,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      10.0, 8.0, 10.0, 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6.0,
                              runSpacing: 4.0,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                _tipoChip(context, row.tipoNome),
                                _situacaoChip(context, row.situacao),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (MembershipAccess.canPermission(
                                  'edit_ocorrencias'))
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                  tooltip: 'Editar',
                                  icon: Icon(
                                    Icons.edit_outlined,
                                    color: theme.primary,
                                    size: 16,
                                  ),
                                  onPressed: () async {
                                    if (!MembershipAccess.canPermission(
                                        'edit_ocorrencias')) {
                                      MembershipAccess.showDenied(
                                        context,
                                        'Sem permissão para editar ocorrências.',
                                      );
                                      return;
                                    }
                                    await showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        return Dialog(
                                          elevation: 0,
                                          insetPadding: EdgeInsets.zero,
                                          backgroundColor: Colors.transparent,
                                          alignment: const AlignmentDirectional(
                                                  0.0, 0.0)
                                              .resolve(
                                                  Directionality.of(context)),
                                          child: EditarOcorrenciaRelatorioModalWidget(
                                            relatorioId: widget.relatoioId!,
                                            id: row.id,
                                            relatorioUuid: widget.relatorioUuid!,
                                            uuid: row.uuid,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              if (MembershipAccess.canPermission(
                                  'delete_ocorrencias'))
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
                                    if (!MembershipAccess.canPermission(
                                        'delete_ocorrencias')) {
                                      MembershipAccess.showDenied(
                                        context,
                                        'Sem permissão para excluir ocorrências.',
                                      );
                                      return;
                                    }
                                    await showDialog(
                                      context: context,
                                      builder: (dialogContext) {
                                        return Dialog(
                                          elevation: 0,
                                          insetPadding: EdgeInsets.zero,
                                          backgroundColor: Colors.transparent,
                                          alignment: const AlignmentDirectional(
                                                  0.0, 0.0)
                                              .resolve(
                                                  Directionality.of(context)),
                                          child:
                                              CofirmaExclusaoOcorrenciaRelatorioWidget(
                                            uuid: row.uuid,
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8.0),
                      Text(
                        row.descricao,
                        style: theme.bodyMedium.override(
                          font: GoogleFonts.inter(
                            fontWeight: theme.bodyMedium.fontWeight,
                            fontStyle: theme.bodyMedium.fontStyle,
                          ),
                          letterSpacing: 0.0,
                          fontWeight: theme.bodyMedium.fontWeight,
                          fontStyle: theme.bodyMedium.fontStyle,
                        ),
                      ),
                      const SizedBox(height: 8.0),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 12.0,
                              runSpacing: 4.0,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 14.0,
                                      color: theme.secondaryText,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      'Início ${row.horaInicio ?? '—'}',
                                      style: theme.labelSmall.override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              theme.labelSmall.fontWeight,
                                          fontStyle:
                                              theme.labelSmall.fontStyle,
                                        ),
                                        color: theme.secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_outlined,
                                      size: 14.0,
                                      color: theme.secondaryText,
                                    ),
                                    const SizedBox(width: 4.0),
                                    Text(
                                      'Fim ${row.horaSaida?.trim().isNotEmpty == true ? row.horaSaida! : '—'}',
                                      style: theme.labelSmall.override(
                                        font: GoogleFonts.inter(
                                          fontWeight:
                                              theme.labelSmall.fontWeight,
                                          fontStyle:
                                              theme.labelSmall.fontStyle,
                                        ),
                                        color: theme.secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if ((row.autorNome ?? '').trim().isNotEmpty)
                            Flexible(
                              child: Text(
                                row.autorNome!.trim(),
                                textAlign: TextAlign.end,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.labelSmall.override(
                                  font: GoogleFonts.inter(
                                    fontWeight: FontWeight.w500,
                                    fontStyle: theme.labelSmall.fontStyle,
                                  ),
                                  color: theme.primary,
                                  letterSpacing: 0.0,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

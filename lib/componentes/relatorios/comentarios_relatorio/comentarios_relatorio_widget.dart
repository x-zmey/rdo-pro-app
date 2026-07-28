import '/auth/membership_access.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/dialogs/cofirma_exclusao_comentario_relatorio/cofirma_exclusao_comentario_relatorio_widget.dart';
import '/componentes/dialogs/editar_comentario_relatorio_modal/editar_comentario_relatorio_modal_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'comentarios_relatorio_model.dart';
export 'comentarios_relatorio_model.dart';

String _formatarDataHoraComentario(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final parsed = DateTime.tryParse(raw.trim());
  if (parsed != null) {
    return dateTimeFormat('dd/MM/yyyy HH:mm', parsed);
  }
  return raw.trim();
}

/// Comentários do relatório RDO: texto, data e ações (editar / excluir).
class ComentariosRelatorioWidget extends StatefulWidget {
  const ComentariosRelatorioWidget({
    super.key,
    required this.relatorioId,
    required this.relatorioUuid,
  });

  final int? relatorioId;
  final String? relatorioUuid;

  @override
  State<ComentariosRelatorioWidget> createState() =>
      _ComentariosRelatorioWidgetState();
}

class _ComentariosRelatorioWidgetState
    extends State<ComentariosRelatorioWidget> {
  late ComentariosRelatorioModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ComentariosRelatorioModel());
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

    return FutureBuilder<List<ListaComentariosRelatoriosRow>>(
      future: SQLiteManager.instance.listaComentariosRelatorios(
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
        final list = snapshot.data!;

        return ListView.separated(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, listViewIndex) {
            final row = list[listViewIndex];
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
                padding: const EdgeInsetsDirectional.fromSTEB(
                    10.0, 8.0, 10.0, 8.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _formatarDataHoraComentario(row.createdAt),
                            style: theme.labelSmall.override(
                              font: GoogleFonts.inter(
                                fontWeight: theme.labelSmall.fontWeight,
                                fontStyle: theme.labelSmall.fontStyle,
                              ),
                              color: theme.secondaryText,
                              letterSpacing: 0.0,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (MembershipAccess.canPermission(
                                'edit_comentarios'))
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
                                      'edit_comentarios')) {
                                    MembershipAccess.showDenied(
                                      context,
                                      'Sem permissão para editar comentários.',
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
                                        alignment: AlignmentDirectional(0.0, 0.0)
                                            .resolve(Directionality.of(context)),
                                        child: EditarComentarioRelatorioModalWidget(
                                          relatorioId: widget.relatorioId!,
                                          comentarioId: row.id,
                                          comentarioUuid: row.uuid,
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                            if (MembershipAccess.canPermission(
                                'delete_comentarios'))
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
                                      'delete_comentarios')) {
                                    MembershipAccess.showDenied(
                                      context,
                                      'Sem permissão para excluir comentários.',
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
                                        alignment: AlignmentDirectional(0.0, 0.0)
                                            .resolve(Directionality.of(context)),
                                        child:
                                            CofirmaExclusaoComentarioRelatorioWidget(
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
                    const SizedBox(height: 6),
                    Text(
                      valueOrDefault<String>(
                        row.texto,
                        'Sem texto',
                      ),
                      style: theme.bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight: theme.bodySmall.fontWeight,
                          fontStyle: theme.bodySmall.fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: theme.bodySmall.fontWeight,
                        fontStyle: theme.bodySmall.fontStyle,
                      ),
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

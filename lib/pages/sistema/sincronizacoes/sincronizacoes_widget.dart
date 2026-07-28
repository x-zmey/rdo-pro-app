import '/backend/sqlite/sqlite_manager.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sincronizacoes_model.dart';
export 'sincronizacoes_model.dart';

/// Histórico das últimas sincronizações registradas localmente.
class SincronizacoesWidget extends StatefulWidget {
  const SincronizacoesWidget({super.key});

  static String routeName = 'sincronizacoes';
  static String routePath = '/sincronizacoes';

  @override
  State<SincronizacoesWidget> createState() => _SincronizacoesWidgetState();
}

class _SincronizacoesWidgetState extends State<SincronizacoesWidget> {
  late SincronizacoesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SincronizacoesModel());
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
        appBar: AppBar(
          backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
          automaticallyImplyLeading: false,
          leading: FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 30.0,
            borderWidth: 1.0,
            buttonSize: 60.0,
            icon: Icon(
              Icons.arrow_back_rounded,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 24.0,
            ),
            onPressed: () {
              print('IconButton pressed ...');
            },
          ),
          title: Text(
            'Sincronização',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  fontSize: 18.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w600,
                  fontStyle:
                      FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                ),
          ),
          actions: [],
          centerTitle: false,
          elevation: 0.0,
        ),
        body: SafeArea(
          top: true,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20.0, 24.0, 20.0, 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Últimas Sincronizações',
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .titleMedium
                              .fontStyle,
                        ),
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(context)
                            .titleMedium
                            .fontStyle,
                      ),
                ),
                const SizedBox(height: 16.0),
                Expanded(
                  child: FutureBuilder<List<SyncHistoryRecentRow>>(
                          future: SQLiteManager.instance.syncHistoryRecent(
                            userUuid: FFAppState().creatorUuid,
                            userId: FFAppState().creatorId,
                            limit: 10,
                          ),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return Center(
                                child: LinearProgressIndicator(
                                  color: FlutterFlowTheme.of(context).primary,
                                ),
                              );
                            }
                            final rows = snapshot.data!;
                            if (rows.isEmpty) {
                              return Center(
                                child: Text(
                                  'Nenhuma sincronização registrada.',
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        font: GoogleFonts.inter(),
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              );
                            }
                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              itemCount: rows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10.0),
                              itemBuilder: (context, index) {
                                final row = rows[index];
                                final status = (row.status ?? '').toLowerCase();
                                final isSuccess = status.contains('success') ||
                                    status.contains('sucesso') ||
                                    status.contains('completed') ||
                                    status.contains('ok');
                                final isError = status.contains('erro') ||
                                    status.contains('error') ||
                                    status.contains('fail');
                                final color = isSuccess
                                    ? FlutterFlowTheme.of(context).success
                                    : isError
                                        ? FlutterFlowTheme.of(context).error
                                        : FlutterFlowTheme.of(context).warning;
                                final icon = isSuccess
                                    ? Icons.check_rounded
                                    : isError
                                        ? Icons.error_outline_rounded
                                        : Icons.sync_rounded;
                                final started = row.startedAt ?? row.createdAt;
                                final completed = row.completedAt;
                                final when = completed ?? started ?? '—';
                                final whenFmt = _formatDateTime(when);
                                final subtitle = completed != null
                                    ? 'Início: ${_formatDateTime(started ?? when)}'
                                    : 'Sincronização em andamento';

                                return Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(8.0),
                                    border: Border.all(
                                      color:
                                          FlutterFlowTheme.of(context).alternate,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(10.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36.0,
                                          height: 36.0,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.15),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            icon,
                                            color: color,
                                            size: 18.0,
                                          ),
                                        ),
                                        const SizedBox(width: 10.0),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Status: ${row.status ?? '—'}',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w600),
                                                      letterSpacing: 0.0,
                                                    ),
                                              ),
                                              Text(
                                                subtitle,
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodySmall
                                                    .override(
                                                      font: GoogleFonts.inter(),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                      letterSpacing: 0.0,
                                                    ),
                                              ),
                                              Text(
                                                whenFmt,
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodySmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                          fontWeight:
                                                              FontWeight.w500),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primary,
                                                      letterSpacing: 0.0,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dt.toLocal());
  }
}

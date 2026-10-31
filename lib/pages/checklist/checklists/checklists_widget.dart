import 'dart:convert';

import '/backend/sqlite/sqlite_manager.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'checklists_model.dart';
export 'checklists_model.dart';

class ChecklistsWidget extends StatefulWidget {
  const ChecklistsWidget({
    super.key,
    required this.obraId,
  });

  final int? obraId;

  static String routeName = 'checklists';
  static String routePath = '/checklists';

  @override
  State<ChecklistsWidget> createState() => _ChecklistsWidgetState();
}

class _ChecklistsWidgetState extends State<ChecklistsWidget> {
  late ChecklistsModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  Future<List<GetChecklistsPreenchidosRow>>? _listaFuture;
  String _filtro = 'todos'; // todos | preenchendo | respondido
  final _buscaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChecklistsModel());
    _listaFuture = _carregarLista();
  }

  Future<List<GetChecklistsPreenchidosRow>> _carregarLista() {
    return SQLiteManager.instance.getChecklistsPreenchidos(
      obraId: widget.obraId,
      accountOwnerUuid: FFAppState().creatorUuid,
    );
  }

  void _recarregar() {
    setState(() {
      _listaFuture = _carregarLista();
    });
  }

  Future<void> _abrirPreenchido(GetChecklistsPreenchidosRow row) async {
    final loaded = await actions.carregarChecklistPreenchido(row.uuid);
    final decoded = jsonDecode(loaded);
    if (decoded is Map && decoded['erro'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decoded['mensagem']?.toString() ?? 'Erro ao abrir checklist',
          ),
        ),
      );
      return;
    }
    if (!mounted) return;
    await context.pushNamed(ChecklistRespondendoWidget.routeName);
    if (mounted) _recarregar();
  }

  String _formatarData(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    final local = dt.toLocal();
    final d =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    final h =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$d às $h';
  }

  String _statusLabel(GetChecklistsPreenchidosRow row) {
    if (row.isRespondido) {
      final nota = row.notaFinal;
      if (nota != null) {
        return 'Respondido · nota ${nota.toStringAsFixed(0)}%';
      }
      return 'Respondido';
    }
    return 'Rascunho · preenchendo';
  }

  List<GetChecklistsPreenchidosRow> _filtrar(
    List<GetChecklistsPreenchidosRow> all,
  ) {
    final q = _buscaCtrl.text.trim().toLowerCase();
    return all.where((row) {
      if (_filtro == 'preenchendo' && !row.isRascunho) return false;
      if (_filtro == 'respondido' && !row.isRespondido) return false;
      if (q.isEmpty) return true;
      return row.templateNome.toLowerCase().contains(q) ||
          row.uuid.toLowerCase().contains(q);
    }).toList();
  }

  @override
  void dispose() {
    _buscaCtrl.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
              size: 30.0,
            ),
            onPressed: () => context.safePop(),
          ),
          title: Text(
            'Checklists',
            style: FlutterFlowTheme.of(context).headlineMedium.override(
                  font: GoogleFonts.interTight(
                    fontWeight: FontWeight.w600,
                    fontStyle:
                        FlutterFlowTheme.of(context).headlineMedium.fontStyle,
                  ),
                  color: FlutterFlowTheme.of(context).primaryText,
                  fontSize: 22.0,
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
            padding: const EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FFButtonWidget(
                  onPressed: () async {
                    await context.pushNamed(
                      AplicarChecklistWidget.routeName,
                      queryParameters: {
                        'obraId': serializeParam(
                          widget.obraId,
                          ParamType.int,
                        ),
                      }.withoutNulls,
                      extra: <String, dynamic>{
                        '__transition_info__': const TransitionInfo(
                          hasTransition: true,
                          transitionType: PageTransitionType.bottomToTop,
                        ),
                      },
                    );
                    if (mounted) _recarregar();
                  },
                  text: 'Aplicar Checklist',
                  icon: const Icon(Icons.add_rounded, size: 20.0),
                  options: FFButtonOptions(
                    width: double.infinity,
                    height: 50.0,
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        24.0, 0.0, 24.0, 0.0),
                    iconPadding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 0.0, 0.0, 0.0),
                    iconColor: Colors.white,
                    color: FlutterFlowTheme.of(context).primary,
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.interTight(
                            fontWeight: FontWeight.w600,
                            fontStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .fontStyle,
                          ),
                          color: Colors.white,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w600,
                          fontStyle:
                              FlutterFlowTheme.of(context).titleSmall.fontStyle,
                        ),
                    elevation: 2.0,
                    borderSide: const BorderSide(
                      color: Colors.transparent,
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                const SizedBox(height: 10.0),
                FFButtonWidget(
                  onPressed: () async {
                    await context.pushNamed(
                      PlanosAcaoListaWidget.routeName,
                      queryParameters: {
                        'obraId': serializeParam(
                          widget.obraId,
                          ParamType.int,
                        ),
                      }.withoutNulls,
                    );
                  },
                  text: 'Planos de ação',
                  icon: const Icon(Icons.assignment_late_outlined, size: 18.0),
                  options: FFButtonOptions(
                    width: double.infinity,
                    height: 44.0,
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                    textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                          font: GoogleFonts.interTight(
                            fontWeight: FontWeight.w600,
                          ),
                          color: FlutterFlowTheme.of(context).primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                    elevation: 0,
                    borderSide: BorderSide(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                const SizedBox(height: 16.0),
                Text(
                  'Checklists Aplicados',
                  style: FlutterFlowTheme.of(context).titleMedium.override(
                        font: GoogleFonts.interTight(
                          fontWeight: FontWeight.w600,
                          fontStyle: FlutterFlowTheme.of(context)
                              .titleMedium
                              .fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).primaryText,
                        fontSize: 18.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                        fontStyle: FlutterFlowTheme.of(context)
                            .titleMedium
                            .fontStyle,
                      ),
                ),
                Text(
                  'Retome rascunhos ou veja os já respondidos',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        font: GoogleFonts.inter(
                          fontWeight:
                              FlutterFlowTheme.of(context).bodySmall.fontWeight,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodySmall.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).secondaryText,
                        letterSpacing: 0.0,
                      ),
                ),
                const SizedBox(height: 8.0),
                TextField(
                  controller: _buscaCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar modelo...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8.0),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final e in [
                        ('todos', 'Todos'),
                        ('preenchendo', 'Rascunhos'),
                        ('respondido', 'Respondidos'),
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(e.$2),
                            selected: _filtro == e.$1,
                            onSelected: (_) =>
                                setState(() => _filtro = e.$1),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 12.0),
                Expanded(
                  child: FutureBuilder<List<GetChecklistsPreenchidosRow>>(
                    future: _listaFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Erro ao carregar: ${snapshot.error}',
                            style: FlutterFlowTheme.of(context).bodyMedium,
                          ),
                        );
                      }
                      final items = _filtrar(snapshot.data ?? []);
                      if (items.isEmpty) {
                        return Center(
                          child: Text(
                            'Nenhum checklist aplicado nesta obra.',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  font: GoogleFonts.inter(),
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                ),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () async => _recarregar(),
                        child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          itemCount: items.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12.0),
                          itemBuilder: (context, index) {
                            final row = items[index];
                            final isDone = row.isRespondido;
                            final accent = isDone
                                ? FlutterFlowTheme.of(context).success
                                : FlutterFlowTheme.of(context).warning;
                            return Material(
                              color: Colors.transparent,
                              elevation: 1.0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12.0),
                                onTap: () => _abrirPreenchido(row),
                                child: Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(12.0),
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .alternate,
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48.0,
                                          height: 48.0,
                                          decoration: BoxDecoration(
                                            color: accent,
                                            borderRadius:
                                                BorderRadius.circular(8.0),
                                          ),
                                          child: Icon(
                                            isDone
                                                ? Icons.check_rounded
                                                : Icons.schedule_rounded,
                                            color: Colors.white,
                                            size: 24.0,
                                          ),
                                        ),
                                        const SizedBox(width: 16.0),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                row.templateNome,
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .titleSmall
                                                    .override(
                                                      font: GoogleFonts
                                                          .interTight(
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      fontSize: 16.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 4.0),
                                              Text(
                                                'Atualizado em ${_formatarData(row.updatedAt ?? row.createdAt)}',
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodySmall
                                                    .override(
                                                      font: GoogleFonts.inter(),
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .secondaryText,
                                                    ),
                                              ),
                                              const SizedBox(height: 4.0),
                                              Text(
                                                _statusLabel(row),
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodySmall
                                                    .override(
                                                      font: GoogleFonts.inter(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      color: accent,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Icon(
                                          Icons.chevron_right_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          size: 20.0,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
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
}

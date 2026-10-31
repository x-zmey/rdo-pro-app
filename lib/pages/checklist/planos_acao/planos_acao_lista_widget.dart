import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

class PlanosAcaoListaWidget extends StatefulWidget {
  const PlanosAcaoListaWidget({
    super.key,
    required this.obraId,
  });

  final int? obraId;

  static String routeName = 'planosAcaoLista';
  static String routePath = '/planosAcaoLista';

  @override
  State<PlanosAcaoListaWidget> createState() => _PlanosAcaoListaWidgetState();
}

class _PlanosAcaoListaWidgetState extends State<PlanosAcaoListaWidget> {
  String _filtro = 'todos'; // todos | abertos | concluidos | atrasados
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = _carregar();
  }

  void _recarregar() {
    setState(() => _future = _carregar());
  }

  Future<List<Map<String, dynamic>>> _carregar() async {
    final db = await SQLiteManager.instance.database;
    final obraId = widget.obraId;
    final rows = await db.rawQuery('''
      SELECT p.*,
             cp.obra_id AS checklist_obra_id,
             cp.uuid AS checklist_uuid
      FROM planos_acoes p
      LEFT JOIN checklists_preenchidos cp
        ON cp.id = p.checklist_preenchido_id
        OR (p.checklist_preenchido_uuid IS NOT NULL
            AND cp.uuid = p.checklist_preenchido_uuid)
      WHERE (? IS NULL OR cp.obra_id = ? OR p.checklist_preenchido_id IN (
        SELECT id FROM checklists_preenchidos WHERE obra_id = ?
      ))
      ORDER BY COALESCE(p.updated_at, p.created_at) DESC
    ''', [obraId, obraId, obraId]);
    return rows.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  bool _isAtrasado(Map<String, dynamic> row) {
    final status = (row['status'] ?? '').toString().toLowerCase();
    if (status.contains('conclu') || status.contains('cancel')) return false;
    final prazo = (row['prazo'] ?? '').toString().trim();
    if (prazo.isEmpty) return false;
    final dt = DateTime.tryParse(prazo);
    if (dt == null) return false;
    final hoje = DateTime.now();
    final onlyDay = DateTime(hoje.year, hoje.month, hoje.day);
    return dt.isBefore(onlyDay);
  }

  bool _isAberto(Map<String, dynamic> row) {
    final status = (row['status'] ?? '').toString().toLowerCase();
    return !status.contains('conclu') && !status.contains('cancel');
  }

  bool _isConcluido(Map<String, dynamic> row) {
    final status = (row['status'] ?? '').toString().toLowerCase();
    return status.contains('conclu');
  }

  List<Map<String, dynamic>> _filtrar(List<Map<String, dynamic>> all) {
    switch (_filtro) {
      case 'abertos':
        return all.where(_isAberto).toList();
      case 'concluidos':
        return all.where(_isConcluido).toList();
      case 'atrasados':
        return all.where(_isAtrasado).toList();
      default:
        return all;
    }
  }

  Color _statusColor(BuildContext context, Map<String, dynamic> row) {
    if (_isAtrasado(row)) return FlutterFlowTheme.of(context).error;
    if (_isConcluido(row)) return FlutterFlowTheme.of(context).success;
    return FlutterFlowTheme.of(context).warning;
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        backgroundColor: theme.primaryBackground,
        elevation: 0,
        leading: FlutterFlowIconButton(
          borderColor: Colors.transparent,
          borderRadius: 30,
          buttonSize: 60,
          icon: Icon(Icons.arrow_back_rounded, color: theme.primaryText),
          onPressed: () => context.safePop(),
        ),
        title: Text(
          'Planos de ação',
          style: theme.headlineMedium.override(
            font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
            color: theme.primaryText,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  for (final e in [
                    ('todos', 'Todos'),
                    ('abertos', 'Abertos'),
                    ('atrasados', 'Atrasados'),
                    ('concluidos', 'Concluídos'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(e.$2),
                        selected: _filtro == e.$1,
                        onSelected: (_) => setState(() => _filtro = e.$1),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(child: Text('Erro: ${snap.error}'));
                  }
                  final items = _filtrar(snap.data ?? []);
                  if (items.isEmpty) {
                    return Center(
                      child: Text(
                        'Nenhum plano de ação neste filtro.',
                        style: theme.bodyMedium.override(
                          font: GoogleFonts.inter(),
                          color: theme.secondaryText,
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _recarregar(),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final row = items[i];
                        final accent = _statusColor(context, row);
                        return Material(
                          color: theme.secondaryBackground,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await context.pushNamed(
                                PlanoAcaoDetalheWidget.routeName,
                                queryParameters: {
                                  'planoId': serializeParam(
                                    row['id'] as int?,
                                    ParamType.int,
                                  ),
                                  'planoUuid': serializeParam(
                                    row['uuid']?.toString(),
                                    ParamType.String,
                                  ),
                                }.withoutNulls,
                              );
                              if (mounted) _recarregar();
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          (row['descricao'] ?? 'Plano')
                                              .toString(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.titleSmall.override(
                                            font: GoogleFonts.interTight(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          [
                                            if ((row['area'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              row['area'].toString(),
                                            (row['status'] ?? 'Em andamento')
                                                .toString(),
                                            if ((row['prazo'] ?? '')
                                                .toString()
                                                .isNotEmpty)
                                              'Prazo ${row['prazo']}',
                                          ].join(' · '),
                                          style: theme.bodySmall.override(
                                            font: GoogleFonts.inter(),
                                            color: theme.secondaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: theme.secondaryText,
                                  ),
                                ],
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
    );
  }
}

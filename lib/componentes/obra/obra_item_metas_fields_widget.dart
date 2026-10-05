import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '/app_state.dart';
import '/flutter_flow/brazilian_currency_input_formatter.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/backend/api_requests/api_config.dart';

class ObraItemMetaRow {
  ObraItemMetaRow({this.tarefaId, this.metaText = ''});

  int? tarefaId;
  String metaText;
}

/// Controller online-first (sem SQLite) para metas de item da obra.
class ObraItemMetasController extends ChangeNotifier {
  ObraItemMetasController() {
    rows = [ObraItemMetaRow()];
  }

  List<ObraItemMetaRow> rows = [];
  List<_TarefaOption> tarefas = [];
  bool loadingTarefas = false;
  String? _obraId;
  String? _error;

  String? get error => _error;

  void reset() {
    rows = [ObraItemMetaRow()];
    _error = null;
    notifyListeners();
  }

  void addRow() {
    rows = [...rows, ObraItemMetaRow()];
    notifyListeners();
  }

  void removeRow(int index) {
    if (rows.length <= 1) {
      rows = [ObraItemMetaRow()];
    } else {
      rows = [
        for (var i = 0; i < rows.length; i++)
          if (i != index) rows[i],
      ];
    }
    notifyListeners();
  }

  void setTarefa(int index, int? tarefaId) {
    if (index < 0 || index >= rows.length) return;
    rows[index].tarefaId = tarefaId;
    notifyListeners();
  }

  void setMetaText(int index, String text) {
    if (index < 0 || index >= rows.length) return;
    rows[index].metaText = text;
    // Sem notify: evita rebuild a cada dígito (cursor/teclado).
  }

  /// Payload API: `[{ tarefa_id, meta }]` — omite linhas sem meta.
  List<Map<String, dynamic>> toPayload() {
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      final meta = parseBrazilianCurrencyInput(r.metaText);
      // 0,00 digitado ainda conta se houver dígitos; vazio = sem meta
      final digits = r.metaText.replaceAll(RegExp(r'\D'), '');
      if (digits.isEmpty) continue;
      out.add({
        'tarefa_id': r.tarefaId,
        'meta': meta,
      });
    }
    return out;
  }

  Future<void> loadTarefas(String obraId, {bool force = false}) async {
    if (obraId.trim().isEmpty) return;
    if (!force && _obraId == obraId && tarefas.isNotEmpty) return;

    loadingTarefas = true;
    _error = null;
    notifyListeners();

    try {
      final token = FFAppState().UserToken;
      final response = await http.get(
        Uri.parse(
          '$kApiBaseUrl/api/obras/$obraId/list-apenas-tarefas',
        ),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Falha ao carregar tarefas (${response.statusCode})');
      }
      final body =
          response.body.isNotEmpty ? jsonDecode(response.body) : null;
      final list = body is Map && body['tarefasResult'] is List
          ? body['tarefasResult'] as List
          : const [];
      tarefas = list.map((raw) {
        final m = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
        final id = int.tryParse('${m['id'] ?? ''}');
        return _TarefaOption(id: id, title: _tituloTarefa(m));
      }).where((o) => o.id != null).toList();
      _obraId = obraId;
    } catch (e) {
      _error = e.toString();
      tarefas = [];
    } finally {
      loadingTarefas = false;
      notifyListeners();
    }
  }
}

class _TarefaOption {
  const _TarefaOption({required this.id, required this.title});
  final int? id;
  final String title;
}

String _tituloTarefa(Map<String, dynamic> t) {
  final etapa = t['etapa'];
  final etapaNome = etapa is Map ? (etapa['nome']?.toString() ?? '') : '';
  final item = t['item']?.toString() ?? '';
  final desc = (t['descricao']?.toString() ?? '').trim();
  final etapaPart = etapaNome.isNotEmpty ? '$etapaNome · ' : '';
  final itemPart = item.isNotEmpty ? '$item - ' : '';
  final descPart =
      desc.isNotEmpty ? desc : (item.isNotEmpty ? item : 'Tarefa #${t['id']}');
  return '$etapaPart$itemPart$descPart';
}

/// UI de metas por tarefa — apenas online (API), sem persistência local.
class ObraItemMetasFieldsWidget extends StatefulWidget {
  const ObraItemMetasFieldsWidget({
    super.key,
    required this.obraId,
    required this.controller,
  });

  final String? obraId;
  final ObraItemMetasController controller;

  @override
  State<ObraItemMetasFieldsWidget> createState() =>
      _ObraItemMetasFieldsWidgetState();
}

class _ObraItemMetasFieldsWidgetState extends State<ObraItemMetasFieldsWidget> {
  final Map<int, TextEditingController> _metaCtrls = {};

  TextEditingController _ctrlFor(int index, String text) {
    final existing = _metaCtrls[index];
    if (existing != null) {
      if (existing.text != text && existing.selection.baseOffset < 0) {
        existing.text = text;
      }
      return existing;
    }
    final c = TextEditingController(text: text);
    _metaCtrls[index] = c;
    return c;
  }

  void _pruneCtrls(int length) {
    final keys = _metaCtrls.keys.where((k) => k >= length).toList();
    for (final k in keys) {
      _metaCtrls.remove(k)?.dispose();
    }
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onCtrl);
    final id = widget.obraId;
    if (id != null && id.isNotEmpty) {
      widget.controller.loadTarefas(id);
    }
  }

  @override
  void didUpdateWidget(covariant ObraItemMetasFieldsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onCtrl);
      widget.controller.addListener(_onCtrl);
    }
    final id = widget.obraId;
    if (id != null &&
        id.isNotEmpty &&
        id != oldWidget.obraId) {
      widget.controller.loadTarefas(id, force: true);
    }
  }

  void _onCtrl() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onCtrl);
    for (final c in _metaCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  InputDecoration _deco({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 20),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.alternate),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.primary, width: 1.5),
      ),
      filled: true,
      fillColor: theme.primaryBackground,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final c = widget.controller;
    _pruneCtrls(c.rows.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Metas por tarefa',
                style: theme.titleSmall.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  letterSpacing: 0,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: c.addRow,
              icon: Icon(Icons.add, size: 18, color: theme.primary),
              label: Text(
                'Adicionar meta',
                style: theme.labelMedium.override(
                  font: GoogleFonts.inter(fontWeight: FontWeight.w600),
                  color: theme.primary,
                  letterSpacing: 0,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: theme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ],
        ),
        Text(
          'Vincule uma ou mais metas (valor decimal) a tarefas da obra. A tarefa é opcional.',
          style: theme.bodySmall.override(
            font: GoogleFonts.inter(),
            color: theme.secondaryText,
            letterSpacing: 0,
          ),
        ),
        if (c.loadingTarefas) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(color: theme.primary),
        ],
        if (c.error != null) ...[
          const SizedBox(height: 6),
          Text(
            'Não foi possível carregar tarefas. Verifique a conexão.',
            style: theme.bodySmall.override(
              font: GoogleFonts.inter(),
              color: theme.error,
              letterSpacing: 0,
            ),
          ),
        ],
        const SizedBox(height: 10),
        for (var i = 0; i < c.rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.alternate),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        key: ValueKey('meta_tarefa_${i}_${c.rows[i].tarefaId}'),
                        initialValue: c.rows[i].tarefaId,
                        isExpanded: true,
                        decoration: _deco(
                          label: 'Tarefa',
                          hint: 'Opcional',
                          icon: Icons.account_tree_outlined,
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('— Sem tarefa —'),
                          ),
                          ...c.tarefas.map(
                            (t) => DropdownMenuItem<int?>(
                              value: t.id,
                              child: Text(
                                t.title,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (v) => c.setTarefa(i, v),
                      ),
                    ),
                    IconButton(
                      onPressed: () => c.removeRow(i),
                      icon: Icon(Icons.delete_outline, color: theme.error),
                      tooltip: 'Remover',
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _ctrlFor(i, c.rows[i].metaText),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    BrazilianCurrencyInputFormatter(),
                  ],
                  onChanged: (v) => c.setMetaText(i, v),
                  decoration: _deco(label: 'Meta', hint: '0,00'),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

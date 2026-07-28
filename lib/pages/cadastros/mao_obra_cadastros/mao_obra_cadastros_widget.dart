import 'dart:convert';
import 'dart:io';

import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/custom_code/actions/index.dart' as custom_actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'mao_obra_cadastros_model.dart';
export 'mao_obra_cadastros_model.dart';

double _moDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

/// pt-BR: milhar (.) e decimal (,) — aceita também `R$ 1.234,56`.
double _parseDecimalBr(String s) {
  if (s.trim().isEmpty) return 0;
  var t = s.trim();
  if (t.toUpperCase().startsWith('R')) {
    final i = t.indexOf(r'$');
    if (i >= 0) t = t.substring(i + 1).trim();
  }
  t = t.replaceAll(RegExp(r'\s'), '');
  t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t) ?? 0;
}

String _formatPrecoFieldBr(double v) {
  return NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(v);
}

String _onlyDigits(String input) => input.replaceAll(RegExp(r'[^0-9]'), '');

String _formatDateBr(String raw) {
  final d = _onlyDigits(raw);
  if (d.isEmpty) return '';
  final digits = d.length > 8 ? d.substring(0, 8) : d;
  if (digits.length <= 2) return digits;
  if (digits.length <= 4) {
    return '${digits.substring(0, 2)}/${digits.substring(2)}';
  }
  return '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
}

/// API `Y-m-d` a partir de `dd/mm/aaaa` ou já ISO.
String? _toApiDateFromBr(String? brOrIso) {
  final t = brOrIso?.trim() ?? '';
  if (t.isEmpty) return null;
  final head = t.split('T').first.split(' ').first;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(head)) return head;
  final d = _onlyDigits(t);
  if (d.length != 8) return null;
  return '${d.substring(4)}-${d.substring(2, 4)}-${d.substring(0, 2)}';
}

/// Exibe data ISO do servidor no campo (dd/mm/aaaa).
String _isoDateToBrField(dynamic v) {
  if (v == null) return '';
  final raw = v.toString().trim();
  if (raw.isEmpty) return '';
  final p = raw.split('T').first.split(' ').first;
  final parts = p.split('-');
  if (parts.length == 3) {
    return '${parts[2].padLeft(2, '0')}/${parts[1].padLeft(2, '0')}/${parts[0]}';
  }
  return '';
}

String _formatDateTimeBrFromIso(dynamic v) {
  if (v == null) return '—';
  final s = v.toString().trim();
  if (s.isEmpty) return '—';
  try {
    final dt = DateTime.parse(s.replaceFirst(' ', 'T'));
    return DateFormat('dd/MM/yyyy HH:mm', 'pt_BR').format(dt.toLocal());
  } catch (_) {
    return s;
  }
}

String _formatCpfDisplay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length != 11) return raw.trim();
  return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
}

String _formatTelDisplay(String? raw) {
  if (raw == null || raw.trim().isEmpty) return '—';
  final d = raw.replaceAll(RegExp(r'\D'), '');
  if (d.length == 11) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 7)}-${d.substring(7)}';
  }
  if (d.length == 10) {
    return '(${d.substring(0, 2)}) ${d.substring(2, 6)}-${d.substring(6)}';
  }
  return raw.trim();
}

String _formatDataAdm(dynamic v) {
  if (v == null) return '—';
  final s = v.toString().trim();
  if (s.isEmpty) return '—';
  final p = s.split('T').first.split(' ').first;
  final parts = p.split('-');
  if (parts.length == 3) {
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }
  return s;
}

String _statusMoLabel(String situacao) {
  switch (situacao) {
    case 'ativo':
      return 'Ativo';
    case 'inativo':
      return 'Inativo';
    case 'ferias':
      return 'Férias';
    case 'afastado':
      return 'Afastado';
    default:
      return situacao;
  }
}

Color _situacaoMoColor(BuildContext context, String s) {
  switch (s) {
    case 'ativo':
      return Colors.green.shade700;
    case 'ferias':
      return Colors.orange.shade800;
    case 'afastado':
      return Colors.deepOrange.shade800;
    case 'inativo':
      return Colors.grey.shade700;
    default:
      return FlutterFlowTheme.of(context).secondaryText;
  }
}

/// Profissionais: CRUD na API, depois `syncMaoObra()`; listagem e filtros vêm do SQLite.
class MaoObraCadastrosWidget extends StatefulWidget {
  const MaoObraCadastrosWidget({super.key});

  static String routeName = 'maoObraCadastros';
  static String routePath = '/maoObraCadastros';

  @override
  State<MaoObraCadastrosWidget> createState() => _MaoObraCadastrosWidgetState();
}

class _MaoObraCadastrosWidgetState extends State<MaoObraCadastrosWidget> {
  late MaoObraCadastrosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredAll = [];
  int _total = 0;
  int _page = 1;
  int _perPage = 10;
  String _sortBy = 'nome_completo';
  String _sortOrder = 'asc';
  String _filterSituacao = '';
  String _filterCargo = '';
  List<String> _cargos = [];
  List<String> _funcoesMaoObra = [];

  static const _debounceTag = 'mao-obra-search';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MaoObraCadastrosModel());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Faça login para ver os profissionais.';
          _items = [];
          _filteredAll = [];
          _total = 0;
        });
      }
      return;
    }
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Listagem offline (SQLite) não está disponível na versão web. Use o app mobile.';
          _items = [];
          _filteredAll = [];
          _total = 0;
        });
      }
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await custom_actions.syncFuncoesMaoObra();
      await custom_actions.syncMaoObra();
    } catch (_) {}
    await _loadFuncoesFromSqlite();
    await _loadCargosFromSqlite();
    await _fetchProfissionais();
  }

  Future<void> _syncAndReloadList() async {
    if (kIsWeb) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    setState(() => _loading = true);
    try {
      await custom_actions.syncFuncoesMaoObra();
      await custom_actions.syncMaoObra();
    } catch (_) {}
    await _loadFuncoesFromSqlite();
    await _loadCargosFromSqlite();
    await _fetchProfissionais();
  }

  Future<void> _loadFuncoesFromSqlite() async {
    if (kIsWeb) return;
    try {
      final rows = await SQLiteManager.instance.getFuncoesMaoObra(
        userUuid: FFAppState().creatorUuid,
      );
      final list = <String>[];
      for (final r in rows) {
        final nome = (r.nome ?? '').trim();
        if (nome.isNotEmpty) list.add(nome);
      }
      if (mounted) {
        setState(() => _funcoesMaoObra = list.toSet().toList()..sort());
      }
    } catch (_) {
      if (mounted) setState(() => _funcoesMaoObra = []);
    }
  }

  Future<void> _loadCargosFromSqlite() async {
    if (kIsWeb) return;
    try {
      final db = SQLiteManager.instance.database;
      final rows = await db.rawQuery(
        "SELECT DISTINCT cargo_funcao FROM mao_obra_profissionais WHERE cargo_funcao IS NOT NULL AND TRIM(cargo_funcao) != '' ORDER BY cargo_funcao COLLATE NOCASE",
      );
      final list = <String>[];
      for (final r in rows) {
        final c = '${r['cargo_funcao'] ?? ''}'.trim();
        if (c.isNotEmpty) list.add(c);
      }
      if (mounted) setState(() => _cargos = list);
    } catch (_) {
      if (mounted) setState(() => _cargos = []);
    }
  }

  Map<String, dynamic> _displayRowFromSqlite(
    Map<String, dynamic> row,
    int? serverId,
  ) {
    final vh = _moDouble(row['valor_hora']);
    final vd = _moDouble(row['valor_diaria']);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    final situacao = '${row['situacao'] ?? 'ativo'}';
    final cpfRaw = row['cpf']?.toString();
    return {
      ...row,
      'id': serverId ?? 0,
      'cpf_formatado': _formatCpfDisplay(cpfRaw),
      'telefone_formatado': _formatTelDisplay(row['telefone']?.toString()),
      'valor_hora_formatado': currency.format(vh),
      'valor_diaria_formatado': currency.format(vd),
      'data_admissao_formatada': _formatDataAdm(row['data_admissao']),
      'status_texto': _statusMoLabel(situacao),
    };
  }

  bool _rowMatchesFilters(Map<String, dynamic> m) {
    if (_filterSituacao.isNotEmpty &&
        '${m['situacao'] ?? ''}' != _filterSituacao) {
      return false;
    }
    if (_filterCargo.isNotEmpty &&
        '${m['cargo_funcao'] ?? ''}' != _filterCargo) {
      return false;
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final nome = '${m['nome_completo'] ?? ''}'.toLowerCase();
    final cpf = '${m['cpf'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
    final qDigits = q.replaceAll(RegExp(r'\D'), '');
    final cargo = '${m['cargo_funcao'] ?? ''}'.toLowerCase();
    final email = '${m['email'] ?? ''}'.toLowerCase();
    if (nome.contains(q)) return true;
    if (cargo.contains(q)) return true;
    if (email.contains(q)) return true;
    if (qDigits.isNotEmpty && cpf.contains(qDigits)) return true;
    return false;
  }

  void _sortFiltered(List<Map<String, dynamic>> list) {
    final asc = _sortOrder == 'asc' ? 1 : -1;
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      switch (_sortBy) {
        case 'cpf':
          return asc * '${a['cpf'] ?? ''}'.compareTo('${b['cpf'] ?? ''}');
        case 'cargo_funcao':
          return asc *
              '${a['cargo_funcao'] ?? ''}'
                  .compareTo('${b['cargo_funcao'] ?? ''}');
        case 'valor_hora':
          return asc *
              _moDouble(a['valor_hora']).compareTo(_moDouble(b['valor_hora']));
        case 'valor_diaria':
          return asc *
              _moDouble(a['valor_diaria'])
                  .compareTo(_moDouble(b['valor_diaria']));
        case 'data_admissao':
          return asc * '${a['data_admissao'] ?? ''}'
              .compareTo('${b['data_admissao'] ?? ''}');
        case 'situacao':
          return asc *
              '${a['situacao'] ?? ''}'.compareTo('${b['situacao'] ?? ''}');
        case 'nome_completo':
        default:
          return asc *
              '${a['nome_completo'] ?? ''}'.toLowerCase().compareTo(
                    '${b['nome_completo'] ?? ''}'.toLowerCase(),
                  );
      }
    }

    list.sort(cmp);
  }

  Future<void> _fetchProfissionais() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login para ver os profissionais.';
        _items = [];
        _filteredAll = [];
        _total = 0;
      });
      return;
    }
    if (kIsWeb) {
      setState(() {
        _loading = false;
        _error =
            'Listagem offline (SQLite) não está disponível na versão web. Use o app mobile.';
        _items = [];
        _filteredAll = [];
        _total = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final db = SQLiteManager.instance.database;
      final mappingRows = await db.query(
        'sync_id_mapping',
        columns: ['uuid', 'id_servidor'],
        where: 'tabela = ?',
        whereArgs: ['mao_obra_profissionais'],
      );
      final idByUuid = <String, int>{};
      for (final mr in mappingRows) {
        final u = mr['uuid']?.toString();
        final sid = mr['id_servidor'];
        if (u != null && u.isNotEmpty && sid is int) {
          idByUuid[u] = sid;
        }
      }

      final rawAll = await db.query('mao_obra_profissionais');
      final raw = rawAll.where((r) {
        final d = r['deleted_at'];
        if (d == null) return true;
        return d.toString().trim().isEmpty;
      }).toList();

      final mapped = <Map<String, dynamic>>[];
      for (final r in raw) {
        final row = Map<String, dynamic>.from(r);
        final uuid = row['uuid']?.toString() ?? '';
        final serverId = idByUuid[uuid];
        mapped.add(_displayRowFromSqlite(row, serverId));
      }

      final filtered = mapped.where(_rowMatchesFilters).toList();
      _sortFiltered(filtered);

      final total = filtered.length;
      final start = ((_page - 1) * _perPage).clamp(0, 1 << 30);
      final pageItems = filtered.skip(start).take(_perPage).toList();

      if (!mounted) return;
      setState(() {
        _loading = false;
        _filteredAll = filtered;
        _items = pageItems;
        _total = total;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Erro ao ler profissionais locais: $e';
        _items = [];
        _filteredAll = [];
        _total = 0;
      });
    }
  }

  Future<void> _afterMutation(String? snackMsg) async {
    if (snackMsg != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(snackMsg),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    }
    try {
      await custom_actions.syncFuncoesMaoObra();
      await custom_actions.syncMaoObra();
    } catch (_) {}
    if (mounted) await _loadFuncoesFromSqlite();
    if (mounted) await _loadCargosFromSqlite();
    if (mounted) await _fetchProfissionais();
  }

  Future<void> _exportLocalCsv() async {
    if (kIsWeb) return;
    if (_filteredAll.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dado para exportar (filtros).')),
        );
      }
      return;
    }

    const keys = [
      'nome_completo',
      'cpf',
      'cargo_funcao',
      'telefone',
      'email',
      'valor_hora',
      'valor_diaria',
      'data_admissao',
      'situacao',
    ];
    final buf = StringBuffer();
    buf.writeln(keys.join(';'));
    for (final row in _filteredAll) {
      final cells = keys.map((k) {
        final v = row[k];
        final s = v == null ? '' : v.toString().replaceAll(';', ',');
        return '"$s"';
      });
      buf.writeln(cells.join(';'));
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/mao_obra_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString('\uFEFF${buf.toString()}', encoding: utf8);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Mão de obra',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('CSV gerado (dados locais / filtros atuais).'),
      ),
    );
  }

  void _onSearchChanged(String _) {
    EasyDebounce.debounce(
      _debounceTag,
      const Duration(milliseconds: 450),
      () {
        _page = 1;
        _fetchProfissionais();
      },
    );
  }

  @override
  void dispose() {
    EasyDebounce.cancel(_debounceTag);
    _searchController.dispose();
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
          backgroundColor: FlutterFlowTheme.of(context).primary,
          automaticallyImplyLeading: true,
          title: Text(
            'Mão de obra',
            style: FlutterFlowTheme.of(context).titleLarge.override(
                  font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
                  color: Colors.white,
                  fontSize: 20,
                ),
          ),
          actions: [
            IconButton(
              tooltip: 'Sincronizar e atualizar',
              onPressed: _loading ? null : _syncAndReloadList,
              icon: _loading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: FlutterFlowTheme.of(context).info,
                      ),
                    )
                  : Icon(Icons.refresh, color: FlutterFlowTheme.of(context).info),
            ),
            PopupMenuButton<String>(
              tooltip: 'Exportar',
              icon: Icon(Icons.ios_share, color: FlutterFlowTheme.of(context).info),
              onSelected: (v) {
                if (v == 'csv') _exportLocalCsv();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'csv',
                  child: Text('CSV (SQLite / filtros)'),
                ),
              ],
            ),
          ],
          elevation: 0,
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(context, null),
          backgroundColor: FlutterFlowTheme.of(context).primary,
          icon: Icon(Icons.add, color: FlutterFlowTheme.of(context).info),
          label: Text(
            'Novo profissional',
            style: TextStyle(color: FlutterFlowTheme.of(context).info),
          ),
        ),
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildFilters(context),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _error!,
                    style: TextStyle(color: FlutterFlowTheme.of(context).error),
                  ),
                ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.groups_outlined,
                color: FlutterFlowTheme.of(context).primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mão de obra',
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                ),
                Text(
                  'Lista no SQLite; alterações vão à API e em seguida sincronizam o cadastro.',
                  style: FlutterFlowTheme.of(context).bodySmall.override(
                        color: FlutterFlowTheme.of(context).secondaryText,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: FlutterFlowTheme.of(context).alternate,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar por nome, CPF, cargo ou e-mail...',
                prefixIcon: Icon(Icons.search,
                    color: FlutterFlowTheme.of(context).secondaryText),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('f_sit_$_filterSituacao'),
                    initialValue: _filterSituacao,
                    decoration: InputDecoration(
                      labelText: 'Situação',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: const [
                      DropdownMenuItem(value: '', child: Text('Todas')),
                      DropdownMenuItem(value: 'ativo', child: Text('Ativo')),
                      DropdownMenuItem(value: 'inativo', child: Text('Inativo')),
                      DropdownMenuItem(value: 'ferias', child: Text('Férias')),
                      DropdownMenuItem(value: 'afastado', child: Text('Afastado')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterSituacao = v ?? '';
                        _page = 1;
                      });
                      _fetchProfissionais();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('f_car_$_filterCargo'),
                    initialValue: _filterCargo,
                    decoration: InputDecoration(
                      labelText: 'Cargo / função',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todos')),
                      ..._cargos.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                      if (_filterCargo.isNotEmpty && !_cargos.contains(_filterCargo))
                        DropdownMenuItem(
                          value: _filterCargo,
                          child: Text(_filterCargo),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterCargo = v ?? '';
                        _page = 1;
                      });
                      _fetchProfissionais();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('Ordenar:', style: FlutterFlowTheme.of(context).labelMedium),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sortBy,
                  items: const [
                    DropdownMenuItem(
                        value: 'nome_completo', child: Text('Nome')),
                    DropdownMenuItem(value: 'cpf', child: Text('CPF')),
                    DropdownMenuItem(
                        value: 'cargo_funcao', child: Text('Cargo')),
                    DropdownMenuItem(
                        value: 'valor_hora', child: Text('Valor hora')),
                    DropdownMenuItem(
                        value: 'valor_diaria', child: Text('Valor diária')),
                    DropdownMenuItem(
                        value: 'data_admissao', child: Text('Admissão')),
                    DropdownMenuItem(value: 'situacao', child: Text('Situação')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sortBy = v;
                      _page = 1;
                    });
                    _fetchProfissionais();
                  },
                ),
                IconButton(
                  tooltip: _sortOrder == 'asc' ? 'Crescente' : 'Decrescente',
                  onPressed: () {
                    setState(() {
                      _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                      _page = 1;
                    });
                    _fetchProfissionais();
                  },
                  icon: Icon(
                    _sortOrder == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (_filterSituacao.isNotEmpty || _filterCargo.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Limpar filtros'),
                    onPressed: () {
                      setState(() {
                        _filterSituacao = '';
                        _filterCargo = '';
                        _page = 1;
                      });
                      _fetchProfissionais();
                    },
                  ),
                const Spacer(),
                Chip(
                  label: Text(
                    '$_total ${_total == 1 ? 'profissional' : 'profissionais'}',
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_total == 0 && _error == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Nenhum profissional encontrado',
                style: FlutterFlowTheme.of(context).titleMedium,
              ),
              const SizedBox(height: 8),
              FFButtonWidget(
                onPressed: () => _openForm(context, null),
                text: 'Novo profissional',
                options: FFButtonOptions(
                  color: FlutterFlowTheme.of(context).primary,
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        color: FlutterFlowTheme.of(context).info,
                      ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lastPage = (_total / _perPage).ceil().clamp(1, 99999);

    return Column(
      children: [
        Expanded(
          child: Scrollbar(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SingleChildScrollView(
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    FlutterFlowTheme.of(context).primary.withValues(alpha: 0.06),
                  ),
                  columns: [
                    DataColumn(label: Text('Profissional', style: _th(context))),
                    DataColumn(label: Text('CPF', style: _th(context))),
                    DataColumn(label: Text('Cargo', style: _th(context))),
                    DataColumn(label: Text('Contato', style: _th(context))),
                    DataColumn(label: Text('Valores', style: _th(context))),
                    DataColumn(label: Text('Admissão', style: _th(context))),
                    DataColumn(label: Text('Situação', style: _th(context))),
                    DataColumn(label: Text('Ações', style: _th(context))),
                  ],
                  rows: _items.map((m) => _buildRow(context, m)).toList(),
                ),
              ),
            ),
          ),
        ),
        _buildPagination(context, lastPage),
      ],
    );
  }

  TextStyle _th(BuildContext context) => FlutterFlowTheme.of(context).labelLarge
      .override(fontWeight: FontWeight.w700, fontSize: 11);

  DataRow _buildRow(BuildContext context, Map<String, dynamic> m) {
    final id = m['id'];
    final idInt = id is int ? id : int.tryParse('$id') ?? 0;
    final situacao = '${m['situacao'] ?? ''}';
    final chipColor = _situacaoMoColor(context, situacao);
    final tel = '${m['telefone_formatado'] ?? '—'}';
    final email = '${m['email'] ?? ''}';

    return DataRow(
      cells: [
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${m['nome_completo'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                ),
                if (email.isNotEmpty)
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).labelSmall,
                  ),
              ],
            ),
          ),
        ),
        DataCell(Text('${m['cpf_formatado'] ?? '—'}',
            style: const TextStyle(fontSize: 12))),
        DataCell(Text('${m['cargo_funcao'] ?? '—'}')),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (tel != '—')
                Text(tel, style: const TextStyle(fontSize: 12)),
              if (tel == '—' && email.isEmpty)
                Text(
                  'Sem contato',
                  style: TextStyle(
                    fontSize: 11,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
            ],
          ),
        ),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_moDouble(m['valor_hora']) > 0)
                Text('H: ${m['valor_hora_formatado']}/h',
                    style: const TextStyle(fontSize: 12)),
              if (_moDouble(m['valor_diaria']) > 0)
                Text('D: ${m['valor_diaria_formatado']}/dia',
                    style: const TextStyle(fontSize: 12)),
              if (_moDouble(m['valor_hora']) <= 0 &&
                  _moDouble(m['valor_diaria']) <= 0)
                Text(
                  '—',
                  style: TextStyle(
                    fontSize: 11,
                    color: FlutterFlowTheme.of(context).secondaryText,
                  ),
                ),
            ],
          ),
        ),
        DataCell(Text('${m['data_admissao_formatada'] ?? '—'}',
            style: const TextStyle(fontSize: 12))),
        DataCell(
          Chip(
            label: Text(
              '${m['status_texto'] ?? _statusMoLabel(situacao)}',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            backgroundColor: chipColor.withValues(alpha: 0.9),
          ),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Ver',
                icon: Icon(Icons.visibility_outlined,
                    color: FlutterFlowTheme.of(context).primary, size: 20),
                onPressed: () => _showView(context, m),
              ),
              IconButton(
                tooltip: 'Editar',
                icon: Icon(Icons.edit_outlined,
                    color: Colors.orange.shade700, size: 20),
                onPressed: () => _openForm(context, m),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'ativo' ||
                      v == 'ferias' ||
                      v == 'afastado' ||
                      v == 'inativo') {
                    _patchSituacao(idInt, v);
                  } else if (v == 'del') {
                    _confirmDelete(context, idInt);
                  }
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(value: 'ativo', child: Text('Ativar')),
                  const PopupMenuItem(
                      value: 'ferias', child: Text('Colocar em férias')),
                  const PopupMenuItem(value: 'afastado', child: Text('Afastar')),
                  const PopupMenuItem(value: 'inativo', child: Text('Inativar')),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'del',
                    child: Text('Excluir',
                        style:
                            TextStyle(color: FlutterFlowTheme.of(context).error)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPagination(BuildContext context, int lastPage) {
    return Material(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          children: [
            DropdownButton<int>(
              value: _perPage,
              items: const [10, 25, 50]
                  .map((e) => DropdownMenuItem(value: e, child: Text('$e / página')))
                  .toList(),
              onChanged: (v) {
                if (v == null) return;
                setState(() {
                  _perPage = v;
                  _page = 1;
                });
                _fetchProfissionais();
              },
            ),
            const Spacer(),
            IconButton(
              onPressed: _page > 1
                  ? () {
                      setState(() => _page--);
                      _fetchProfissionais();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página $_page / $lastPage'),
            IconButton(
              onPressed: _page < lastPage
                  ? () {
                      setState(() => _page++);
                      _fetchProfissionais();
                    }
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
    );
  }

  void _showView(BuildContext context, Map<String, dynamic> m) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${m['nome_completo']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('CPF', '${m['cpf_formatado'] ?? '—'}'),
              _kv('RG', '${m['rg'] ?? '—'}'),
              _kv('Cargo', '${m['cargo_funcao'] ?? '—'}'),
              _kv('Telefone', '${m['telefone_formatado'] ?? '—'}'),
              _kv('E-mail', '${m['email'] ?? '—'}'),
              _kv('Valor hora', '${m['valor_hora_formatado'] ?? '—'}'),
              _kv('Valor diária', '${m['valor_diaria_formatado'] ?? '—'}'),
              _kv('Admissão', '${m['data_admissao_formatada'] ?? '—'}'),
              _kv('Situação', '${m['status_texto'] ?? m['situacao']}'),
              _kv('Criado em', _formatDateTimeBrFromIso(m['created_at'])),
              _kv('Atualizado em', _formatDateTimeBrFromIso(m['updated_at'])),
              if ('${m['observacoes'] ?? ''}'.isNotEmpty)
                _kv('Observações', '${m['observacoes']}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 110,
              child: Text(k,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ),
            Expanded(child: Text(v, style: const TextStyle(fontSize: 13))),
          ],
        ),
      );

  Future<void> _openForm(BuildContext context, Map<String, dynamic>? existing) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ProfissionalFormDialog(
        existing: existing,
        funcoes: _funcoesMaoObra,
      ),
    );

    if (result == null || !mounted || !context.mounted) return;

    final nomeVal = (result['nome_completo'] as String?)?.trim() ?? '';
    final cpfVal = (result['cpf'] as String?)?.trim() ?? '';
    final rgVal = (result['rg'] as String?)?.trim() ?? '';
    final telVal = (result['telefone'] as String?)?.trim() ?? '';
    final emailVal = (result['email'] as String?)?.trim() ?? '';
    final cargoVal = (result['cargo_funcao'] as String?)?.trim() ?? '';
    final vhVal = result['valor_hora'] as String? ?? '';
    final vdVal = result['valor_diaria'] as String? ?? '';
    final admVal = (result['data_admissao'] as String?)?.trim() ?? '';
    final obsVal = (result['observacoes'] as String?)?.trim() ?? '';
    final situacao = result['situacao'] as String? ?? 'ativo';

    if (nomeVal.isEmpty || cargoVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha nome completo e cargo/função.'),
        ),
      );
      return;
    }

    final body = <String, dynamic>{
      'nome_completo': nomeVal,
      'cpf': cpfVal.isEmpty ? null : cpfVal,
      'rg': rgVal.isEmpty ? null : rgVal,
      'telefone': telVal.isEmpty ? null : telVal,
      'email': emailVal.isEmpty ? null : emailVal,
      'cargo_funcao': cargoVal,
      'valor_hora': vhVal.trim().isEmpty ? null : _parseDecimalBr(vhVal),
      'valor_diaria': vdVal.trim().isEmpty ? null : _parseDecimalBr(vdVal),
      'data_admissao': _toApiDateFromBr(admVal),
      'observacoes': obsVal.isEmpty ? null : obsVal,
      'situacao': situacao,
    };

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;

    if (existing == null) {
      final r = await MaoObraProfissionalCreateCall.call(token: token, body: body);
      if (r.succeeded) {
        await _afterMutation('Profissional cadastrado.');
      } else {
        _showApiError(r);
      }
    } else {
      final id = existing['id'];
      final idInt = id is int ? id : int.tryParse('$id') ?? 0;
      if (idInt <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'ID do servidor indisponível. Toque em atualizar (sincronizar) e tente de novo.',
              ),
            ),
          );
        }
        return;
      }
      final r = await MaoObraProfissionalUpdateCall.call(
        token: token,
        id: idInt,
        body: body,
      );
      if (r.succeeded) {
        await _afterMutation('Profissional atualizado.');
      } else {
        _showApiError(r);
      }
    }
  }

  void _showApiError(ApiCallResponse r) {
    var msg = 'Falha na operação.';
    final jb = r.jsonBody;
    if (jb is Map && jb['message'] != null) msg = '${jb['message']}';
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _patchSituacao(int id, String situacao) async {
    if (id <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sincronize (ícone atualizar) para obter o ID do servidor neste aparelho.',
            ),
          ),
        );
      }
      return;
    }
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    final r = await MaoObraProfissionalPatchSituacaoCall.call(
      token: token,
      id: id,
      situacao: situacao,
    );
    if (r.succeeded) {
      await _afterMutation('Situação atualizada.');
    } else {
      _showApiError(r);
    }
  }

  Future<void> _confirmDelete(BuildContext context, int id) async {
    if (id <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sincronize (ícone atualizar) para obter o ID do servidor neste aparelho.',
            ),
          ),
        );
      }
      return;
    }
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir profissional?'),
        content: const Text('Esta ação não pode ser desfeita.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (go != true || !mounted) return;
    final token = FFAppState().UserToken.trim();
    final r = await MaoObraProfissionalDeleteCall.call(token: token, id: id);
    if (r.succeeded) {
      await _afterMutation('Profissional excluído.');
    } else {
      _showApiError(r);
    }
  }
}

class _ProfissionalFormDialog extends StatefulWidget {
  const _ProfissionalFormDialog({this.existing, required this.funcoes});

  final Map<String, dynamic>? existing;
  final List<String> funcoes;

  @override
  State<_ProfissionalFormDialog> createState() => _ProfissionalFormDialogState();
}

class _ProfissionalFormDialogState extends State<_ProfissionalFormDialog> {
  late final TextEditingController nomeCompleto;
  late final TextEditingController cpf;
  late final TextEditingController rg;
  late final TextEditingController telefone;
  late final TextEditingController email;
  late final TextEditingController cargoFuncao;
  late final TextEditingController valorHora;
  late final TextEditingController valorDiaria;
  late final TextEditingController dataAdmissao;
  late final TextEditingController observacoes;
  late final FocusNode _valorHoraFocus;
  late final FocusNode _valorDiariaFocus;
  late final FocusNode _dataAdmissaoFocus;
  late String situacao;

  void _setMaskedValue(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _formatPrecoOnBlur(TextEditingController c) {
    if (c.text.trim().isEmpty) return;
    final v = _parseDecimalBr(c.text);
    _setMaskedValue(c, _formatPrecoFieldBr(v));
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nomeCompleto =
        TextEditingController(text: e?['nome_completo']?.toString() ?? '');
    cpf = TextEditingController(text: e?['cpf']?.toString() ?? '');
    rg = TextEditingController(text: e?['rg']?.toString() ?? '');
    telefone = TextEditingController(text: e?['telefone']?.toString() ?? '');
    email = TextEditingController(text: e?['email']?.toString() ?? '');
    cargoFuncao =
        TextEditingController(text: e?['cargo_funcao']?.toString() ?? '');
    final vh = e != null ? _moDouble(e['valor_hora']) : 0.0;
    final vd = e != null ? _moDouble(e['valor_diaria']) : 0.0;
    valorHora = TextEditingController(
      text: e != null && vh > 0 ? _formatPrecoFieldBr(vh) : '',
    );
    valorDiaria = TextEditingController(
      text: e != null && vd > 0 ? _formatPrecoFieldBr(vd) : '',
    );
    dataAdmissao = TextEditingController(
      text: _isoDateToBrField(e?['data_admissao']),
    );
    observacoes = TextEditingController(text: e?['observacoes']?.toString() ?? '');
    situacao = '${e?['situacao'] ?? 'ativo'}';

    _valorHoraFocus = FocusNode();
    _valorDiariaFocus = FocusNode();
    _dataAdmissaoFocus = FocusNode();
    _valorHoraFocus.addListener(() {
      if (!_valorHoraFocus.hasFocus) _formatPrecoOnBlur(valorHora);
    });
    _valorDiariaFocus.addListener(() {
      if (!_valorDiariaFocus.hasFocus) _formatPrecoOnBlur(valorDiaria);
    });
  }

  @override
  void dispose() {
    _valorHoraFocus.dispose();
    _valorDiariaFocus.dispose();
    _dataAdmissaoFocus.dispose();
    nomeCompleto.dispose();
    cpf.dispose();
    rg.dispose();
    telefone.dispose();
    email.dispose();
    cargoFuncao.dispose();
    valorHora.dispose();
    valorDiaria.dispose();
    dataAdmissao.dispose();
    observacoes.dispose();
    super.dispose();
  }

  void _salvar() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context).pop(<String, dynamic>{
      'nome_completo': nomeCompleto.text,
      'cpf': cpf.text,
      'rg': rg.text,
      'telefone': telefone.text,
      'email': email.text,
      'cargo_funcao': cargoFuncao.text,
      'valor_hora': valorHora.text,
      'valor_diaria': valorDiaria.text,
      'data_admissao': dataAdmissao.text,
      'observacoes': observacoes.text,
      'situacao': situacao,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Novo profissional'
          : 'Editar profissional'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nomeCompleto,
                decoration: const InputDecoration(labelText: 'Nome completo *'),
              ),
              TextField(
                controller: cpf,
                decoration: const InputDecoration(labelText: 'CPF'),
              ),
              TextField(
                controller: rg,
                decoration: const InputDecoration(labelText: 'RG'),
              ),
              DropdownButtonFormField<String>(
                initialValue: widget.funcoes.contains(cargoFuncao.text.trim())
                    ? cargoFuncao.text.trim()
                    : null,
                decoration: const InputDecoration(labelText: 'Função predefinida'),
                items: [
                  const DropdownMenuItem<String>(
                    value: '',
                    child: Text('Selecionar (opcional)'),
                  ),
                  ...widget.funcoes.map(
                    (f) => DropdownMenuItem<String>(
                      value: f,
                      child: Text(f),
                    ),
                  ),
                ],
                onChanged: (v) {
                  if (v == null || v.isEmpty) return;
                  _setMaskedValue(cargoFuncao, v);
                },
              ),
              TextField(
                controller: cargoFuncao,
                decoration:
                    const InputDecoration(labelText: 'Cargo / função *'),
              ),
              TextField(
                controller: telefone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefone'),
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail'),
              ),
              TextField(
                controller: valorHora,
                focusNode: _valorHoraFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,R$\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor hora',
                  hintText: r'R$ 0,00',
                ),
              ),
              TextField(
                controller: valorDiaria,
                focusNode: _valorDiariaFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,R$\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor diária',
                  hintText: r'R$ 0,00',
                ),
              ),
              TextField(
                controller: dataAdmissao,
                focusNode: _dataAdmissaoFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (v) => _setMaskedValue(
                  dataAdmissao,
                  _formatDateBr(v),
                ),
                decoration: const InputDecoration(
                  labelText: 'Data de admissão',
                  hintText: 'dd/mm/aaaa',
                ),
              ),
              TextField(
                controller: observacoes,
                decoration: const InputDecoration(labelText: 'Observações'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(situacao),
                initialValue: situacao,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: const [
                  DropdownMenuItem(value: 'ativo', child: Text('Ativo')),
                  DropdownMenuItem(value: 'inativo', child: Text('Inativo')),
                  DropdownMenuItem(value: 'ferias', child: Text('Férias')),
                  DropdownMenuItem(value: 'afastado', child: Text('Afastado')),
                ],
                onChanged: (v) => setState(() => situacao = v ?? 'ativo'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _salvar,
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

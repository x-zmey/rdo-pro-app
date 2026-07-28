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

import 'equipamentos_cadastros_model.dart';
export 'equipamentos_cadastros_model.dart';

double _eqToDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

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

String? _toApiDateFromBr(String? brOrIso) {
  final t = brOrIso?.trim() ?? '';
  if (t.isEmpty) return null;
  final head = t.split('T').first.split(' ').first;
  if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(head)) return head;
  final d = _onlyDigits(t);
  if (d.length != 8) return null;
  return '${d.substring(4)}-${d.substring(2, 4)}-${d.substring(0, 2)}';
}

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

String _statusEquipLabel(String situacao) {
  switch (situacao) {
    case 'disponivel':
      return 'Disponível';
    case 'em_uso':
      return 'Em uso';
    case 'manutencao':
      return 'Manutenção';
    case 'inativo':
      return 'Inativo';
    default:
      return situacao;
  }
}

Color _situacaoChipColor(BuildContext context, String s) {
  switch (s) {
    case 'disponivel':
      return Colors.green.shade700;
    case 'em_uso':
      return Colors.blue.shade700;
    case 'manutencao':
      return Colors.orange.shade800;
    case 'inativo':
      return Colors.grey.shade700;
    default:
      return FlutterFlowTheme.of(context).secondaryText;
  }
}

/// Catálogo de equipamentos: CRUD na API, depois `syncEquipamentos()`; listagem e filtros vêm do SQLite.
class EquipamentosCadastrosWidget extends StatefulWidget {
  const EquipamentosCadastrosWidget({super.key});

  static String routeName = 'equipamentosCadastros';
  static String routePath = '/equipamentosCadastros';

  @override
  State<EquipamentosCadastrosWidget> createState() =>
      _EquipamentosCadastrosWidgetState();
}

class _EquipamentosCadastrosWidgetState extends State<EquipamentosCadastrosWidget> {
  late EquipamentosCadastrosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredAll = [];
  int _total = 0;
  int _page = 1;
  int _perPage = 10;
  String _sortBy = 'nome';
  String _sortOrder = 'asc';
  String _filterSituacao = '';
  String _filterCategoria = '';
  List<String> _categorias = [];

  static const _debounceTag = 'equipamentos-search';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EquipamentosCadastrosModel());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Faça login para ver os equipamentos.';
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
      await custom_actions.syncEquipamentos();
    } catch (_) {}
    await _loadCategoriasFromSqlite();
    await _fetchEquipamentos();
  }

  Future<void> _syncAndReloadList() async {
    if (kIsWeb) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    setState(() => _loading = true);
    try {
      await custom_actions.syncEquipamentos();
    } catch (_) {}
    await _loadCategoriasFromSqlite();
    await _fetchEquipamentos();
  }

  Future<void> _loadCategoriasFromSqlite() async {
    if (kIsWeb) return;
    try {
      final db = SQLiteManager.instance.database;
      final rows = await db.rawQuery(
        "SELECT DISTINCT categoria FROM equipamentos WHERE categoria IS NOT NULL AND TRIM(categoria) != '' ORDER BY categoria COLLATE NOCASE",
      );
      final list = <String>[];
      for (final r in rows) {
        final c = '${r['categoria'] ?? ''}'.trim();
        if (c.isNotEmpty) list.add(c);
      }
      if (mounted) setState(() => _categorias = list);
    } catch (_) {
      if (mounted) setState(() => _categorias = []);
    }
  }

  Map<String, dynamic> _displayRowFromSqlite(
    Map<String, dynamic> row,
    int? serverId,
  ) {
    final vh = _eqToDouble(row['valor_hora']);
    final vd = _eqToDouble(row['valor_diaria']);
    final vm = _eqToDouble(row['valor_mensal']);
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    final situacao = '${row['situacao'] ?? 'disponivel'}';
    return {
      ...row,
      'id': serverId ?? 0,
      'valor_hora_formatado': currency.format(vh),
      'valor_diaria_formatado': currency.format(vd),
      'valor_mensal_formatado': currency.format(vm),
      'status_texto': _statusEquipLabel(situacao),
    };
  }

  bool _rowMatchesFilters(Map<String, dynamic> m) {
    if (_filterSituacao.isNotEmpty &&
        '${m['situacao'] ?? ''}' != _filterSituacao) {
      return false;
    }
    if (_filterCategoria.isNotEmpty &&
        '${m['categoria'] ?? ''}' != _filterCategoria) {
      return false;
    }
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final nome = '${m['nome'] ?? ''}'.toLowerCase();
    final cod = '${m['codigo'] ?? ''}'.toLowerCase();
    final placa = '${m['placa_identificacao'] ?? ''}'.toLowerCase();
    final marca = '${m['marca'] ?? ''}'.toLowerCase();
    final modelo = '${m['modelo'] ?? ''}'.toLowerCase();
    return nome.contains(q) ||
        cod.contains(q) ||
        placa.contains(q) ||
        marca.contains(q) ||
        modelo.contains(q);
  }

  void _sortFiltered(List<Map<String, dynamic>> list) {
    final asc = _sortOrder == 'asc' ? 1 : -1;
    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      switch (_sortBy) {
        case 'codigo':
          return asc *
              '${a['codigo'] ?? ''}'.compareTo('${b['codigo'] ?? ''}');
        case 'categoria':
          return asc *
              '${a['categoria'] ?? ''}'.compareTo('${b['categoria'] ?? ''}');
        case 'marca':
          return asc * '${a['marca'] ?? ''}'.compareTo('${b['marca'] ?? ''}');
        case 'modelo':
          return asc *
              '${a['modelo'] ?? ''}'.compareTo('${b['modelo'] ?? ''}');
        case 'placa_identificacao':
          return asc *
              '${a['placa_identificacao'] ?? ''}'
                  .compareTo('${b['placa_identificacao'] ?? ''}');
        case 'valor_hora':
          return asc *
              _eqToDouble(a['valor_hora']).compareTo(_eqToDouble(b['valor_hora']));
        case 'valor_diaria':
          return asc *
              _eqToDouble(a['valor_diaria'])
                  .compareTo(_eqToDouble(b['valor_diaria']));
        case 'situacao':
          return asc *
              '${a['situacao'] ?? ''}'.compareTo('${b['situacao'] ?? ''}');
        case 'nome':
        default:
          return asc *
              '${a['nome'] ?? ''}'.toLowerCase().compareTo(
                    '${b['nome'] ?? ''}'.toLowerCase(),
                  );
      }
    }

    list.sort(cmp);
  }

  Future<void> _fetchEquipamentos() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login para ver os equipamentos.';
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
        whereArgs: ['equipamentos'],
      );
      final idByUuid = <String, int>{};
      for (final mr in mappingRows) {
        final u = mr['uuid']?.toString();
        final sid = mr['id_servidor'];
        if (u != null && u.isNotEmpty && sid is int) {
          idByUuid[u] = sid;
        }
      }

      final rawAll = await db.query('equipamentos');
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
        _error = 'Erro ao ler equipamentos locais: $e';
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
      await custom_actions.syncEquipamentos();
    } catch (_) {}
    if (mounted) await _loadCategoriasFromSqlite();
    if (mounted) await _fetchEquipamentos();
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
      'codigo',
      'nome',
      'descricao',
      'categoria',
      'marca',
      'modelo',
      'placa_identificacao',
      'unidade_medida',
      'valor_hora',
      'valor_diaria',
      'valor_mensal',
      'situacao',
      'localizacao',
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
        '${dir.path}/equipamentos_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString('\uFEFF${buf.toString()}', encoding: utf8);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Equipamentos',
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
        _fetchEquipamentos();
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
            'Equipamentos',
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
            'Novo equipamento',
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
            child: Icon(Icons.handyman_outlined,
                color: FlutterFlowTheme.of(context).primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipamentos',
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                ),
                Text(
                  'Lista no SQLite; alterações vão à API e em seguida sincronizam o catálogo.',
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
                hintText: 'Buscar por nome, código, placa, marca ou modelo...',
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
                      DropdownMenuItem(
                          value: 'disponivel', child: Text('Disponível')),
                      DropdownMenuItem(value: 'em_uso', child: Text('Em uso')),
                      DropdownMenuItem(
                          value: 'manutencao', child: Text('Manutenção')),
                      DropdownMenuItem(value: 'inativo', child: Text('Inativo')),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterSituacao = v ?? '';
                        _page = 1;
                      });
                      _fetchEquipamentos();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    key: ValueKey('f_cat_$_filterCategoria'),
                    initialValue: _filterCategoria,
                    decoration: InputDecoration(
                      labelText: 'Categoria',
                      isDense: true,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: [
                      const DropdownMenuItem(value: '', child: Text('Todas')),
                      ..._categorias.map(
                        (c) => DropdownMenuItem(value: c, child: Text(c)),
                      ),
                      if (_filterCategoria.isNotEmpty &&
                          !_categorias.contains(_filterCategoria))
                        DropdownMenuItem(
                          value: _filterCategoria,
                          child: Text(_filterCategoria),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterCategoria = v ?? '';
                        _page = 1;
                      });
                      _fetchEquipamentos();
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
                    DropdownMenuItem(value: 'nome', child: Text('Nome')),
                    DropdownMenuItem(value: 'codigo', child: Text('Código')),
                    DropdownMenuItem(value: 'categoria', child: Text('Categoria')),
                    DropdownMenuItem(value: 'marca', child: Text('Marca')),
                    DropdownMenuItem(value: 'modelo', child: Text('Modelo')),
                    DropdownMenuItem(
                        value: 'placa_identificacao', child: Text('Placa')),
                    DropdownMenuItem(value: 'valor_hora', child: Text('Valor hora')),
                    DropdownMenuItem(
                        value: 'valor_diaria', child: Text('Valor diária')),
                    DropdownMenuItem(value: 'situacao', child: Text('Situação')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sortBy = v;
                      _page = 1;
                    });
                    _fetchEquipamentos();
                  },
                ),
                IconButton(
                  tooltip: _sortOrder == 'asc' ? 'Crescente' : 'Decrescente',
                  onPressed: () {
                    setState(() {
                      _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                      _page = 1;
                    });
                    _fetchEquipamentos();
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
                if (_filterSituacao.isNotEmpty || _filterCategoria.isNotEmpty)
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Limpar filtros'),
                    onPressed: () {
                      setState(() {
                        _filterSituacao = '';
                        _filterCategoria = '';
                        _page = 1;
                      });
                      _fetchEquipamentos();
                    },
                  ),
                const Spacer(),
                Chip(
                  label: Text('$_total equipamento${_total == 1 ? '' : 's'}'),
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
              Icon(Icons.construction, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Nenhum equipamento encontrado',
                style: FlutterFlowTheme.of(context).titleMedium,
              ),
              const SizedBox(height: 8),
              FFButtonWidget(
                onPressed: () => _openForm(context, null),
                text: 'Novo equipamento',
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
                    DataColumn(label: Text('Código', style: _th(context))),
                    DataColumn(label: Text('Equipamento', style: _th(context))),
                    DataColumn(label: Text('Categoria', style: _th(context))),
                    DataColumn(label: Text('Marca/Modelo', style: _th(context))),
                    DataColumn(label: Text('Placa', style: _th(context))),
                    DataColumn(label: Text('Valores', style: _th(context))),
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
    final chipColor = _situacaoChipColor(context, situacao);

    return DataRow(
      cells: [
        DataCell(
          Chip(
            label: Text('${m['codigo'] ?? '—'}'),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            labelStyle: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${m['nome'] ?? ''}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                ),
                if ('${m['descricao'] ?? ''}'.isNotEmpty)
                  Text(
                    '${m['descricao']}'.length > 48
                        ? '${'${m['descricao']}'.substring(0, 48)}…'
                        : '${m['descricao']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).labelSmall,
                  ),
              ],
            ),
          ),
        ),
        DataCell(Text('${m['categoria'] ?? '—'}')),
        DataCell(
          Text(
            '${m['marca'] ?? '—'} / ${m['modelo'] ?? '—'}',
            style: const TextStyle(fontSize: 12),
          ),
        ),
        DataCell(Text('${m['placa_identificacao'] ?? '—'}')),
        DataCell(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_eqToDouble(m['valor_hora']) > 0)
                Text('H: ${m['valor_hora_formatado']}',
                    style: const TextStyle(fontSize: 12)),
              if (_eqToDouble(m['valor_diaria']) > 0)
                Text('D: ${m['valor_diaria_formatado']}',
                    style: const TextStyle(fontSize: 12)),
              if (_eqToDouble(m['valor_mensal']) > 0)
                Text('M: ${m['valor_mensal_formatado']}',
                    style: const TextStyle(fontSize: 11)),
              if (_eqToDouble(m['valor_hora']) <= 0 &&
                  _eqToDouble(m['valor_diaria']) <= 0 &&
                  _eqToDouble(m['valor_mensal']) <= 0)
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
        DataCell(
          Chip(
            label: Text(
              '${m['status_texto'] ?? _statusEquipLabel(situacao)}',
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
                  if (v == 'disponivel' ||
                      v == 'em_uso' ||
                      v == 'manutencao') {
                    _patchSituacao(idInt, v);
                  } else if (v == 'del') {
                    _confirmDelete(context, idInt);
                  }
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(
                      value: 'disponivel', child: Text('Disponível')),
                  const PopupMenuItem(value: 'em_uso', child: Text('Em uso')),
                  const PopupMenuItem(
                      value: 'manutencao', child: Text('Manutenção')),
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
                _fetchEquipamentos();
              },
            ),
            const Spacer(),
            IconButton(
              onPressed: _page > 1
                  ? () {
                      setState(() => _page--);
                      _fetchEquipamentos();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página $_page / $lastPage'),
            IconButton(
              onPressed: _page < lastPage
                  ? () {
                      setState(() => _page++);
                      _fetchEquipamentos();
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
        title: Text('${m['nome']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _kv('Código', '${m['codigo'] ?? '—'}'),
              _kv('Categoria', '${m['categoria'] ?? '—'}'),
              _kv('Marca', '${m['marca'] ?? '—'}'),
              _kv('Modelo', '${m['modelo'] ?? '—'}'),
              _kv('Placa', '${m['placa_identificacao'] ?? '—'}'),
              _kv('Unidade', '${m['unidade_medida'] ?? '—'}'),
              _kv('Valor hora', '${m['valor_hora_formatado'] ?? '—'}'),
              _kv('Valor diária', '${m['valor_diaria_formatado'] ?? '—'}'),
              _kv('Valor mensal', '${m['valor_mensal_formatado'] ?? '—'}'),
              _kv('Localização', '${m['localizacao'] ?? '—'}'),
              _kv('Situação', '${m['status_texto'] ?? m['situacao']}'),
              _kv('Criado em', _formatDateTimeBrFromIso(m['created_at'])),
              _kv('Atualizado em', _formatDateTimeBrFromIso(m['updated_at'])),
              if ('${m['descricao'] ?? ''}'.isNotEmpty)
                _kv('Descrição', '${m['descricao']}'),
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
      builder: (ctx) => _EquipamentoFormDialog(existing: existing),
    );

    if (result == null || !mounted || !context.mounted) return;

    final nomeVal = (result['nome'] as String?)?.trim() ?? '';
    final codigoVal = (result['codigo'] as String?)?.trim() ?? '';
    final descVal = (result['descricao'] as String?)?.trim() ?? '';
    final catVal = (result['categoria'] as String?)?.trim() ?? '';
    final unVal = (result['unidade'] as String?)?.trim() ?? '';
    final vhVal = result['valor_hora'] as String? ?? '';
    final vdVal = result['valor_diaria'] as String? ?? '';
    final vmVal = result['valor_mensal'] as String? ?? '';
    final marcaVal = (result['marca'] as String?)?.trim() ?? '';
    final modeloVal = (result['modelo'] as String?)?.trim() ?? '';
    final placaVal = (result['placa'] as String?)?.trim() ?? '';
    final serieVal = (result['numero_serie'] as String?)?.trim() ?? '';
    final anoVal = (result['ano_fabricacao'] as String?)?.trim() ?? '';
    final dataAqVal = (result['data_aquisicao'] as String?)?.trim() ?? '';
    final vidaVal = (result['vida_util'] as String?)?.trim() ?? '';
    final locVal = (result['local'] as String?)?.trim() ?? '';
    final obsVal = (result['observacoes'] as String?)?.trim() ?? '';
    final situacao = result['situacao'] as String? ?? 'disponivel';

    if (nomeVal.isEmpty || unVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha nome e unidade de medida.'),
        ),
      );
      return;
    }

    final body = <String, dynamic>{
      'nome': nomeVal,
      'codigo': codigoVal.isEmpty ? null : codigoVal,
      'descricao': descVal.isEmpty ? null : descVal,
      'categoria': catVal.isEmpty ? null : catVal,
      'unidade_medida': unVal,
      'valor_hora': vhVal.trim().isEmpty ? null : _parseDecimalBr(vhVal),
      'valor_diaria': vdVal.trim().isEmpty ? null : _parseDecimalBr(vdVal),
      'valor_mensal': vmVal.trim().isEmpty ? null : _parseDecimalBr(vmVal),
      'marca': marcaVal.isEmpty ? null : marcaVal,
      'modelo': modeloVal.isEmpty ? null : modeloVal,
      'placa_identificacao': placaVal.isEmpty ? null : placaVal,
      'numero_serie': serieVal.isEmpty ? null : serieVal,
      'ano_fabricacao': anoVal.isEmpty ? null : int.tryParse(anoVal),
      'data_aquisicao': _toApiDateFromBr(dataAqVal),
      'vida_util': vidaVal.isEmpty ? null : int.tryParse(vidaVal),
      'localizacao': locVal.isEmpty ? null : locVal,
      'observacoes': obsVal.isEmpty ? null : obsVal,
      'situacao': situacao,
    };

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;

    if (existing == null) {
      final r = await EquipamentoCreateCall.call(token: token, body: body);
      if (r.succeeded) {
        await _afterMutation('Equipamento cadastrado.');
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
      final r = await EquipamentoUpdateCall.call(token: token, id: idInt, body: body);
      if (r.succeeded) {
        await _afterMutation('Equipamento atualizado.');
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
    final r = await EquipamentoPatchSituacaoCall.call(
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
    if (!FFAppState().hasPermission('edit_insumos')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Você não tem permissão para excluir equipamentos.'),
          ),
        );
      }
      return;
    }
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
        title: const Text('Excluir equipamento?'),
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
    final r = await EquipamentoDeleteCall.call(token: token, id: id);
    if (r.succeeded) {
      await _afterMutation('Equipamento excluído.');
    } else {
      _showApiError(r);
    }
  }
}

/// Controllers vivem no State do diálogo até a rota ser descartada.
class _EquipamentoFormDialog extends StatefulWidget {
  const _EquipamentoFormDialog({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_EquipamentoFormDialog> createState() => _EquipamentoFormDialogState();
}

class _EquipamentoFormDialogState extends State<_EquipamentoFormDialog> {
  late final TextEditingController nome;
  late final TextEditingController codigo;
  late final TextEditingController descricao;
  late final TextEditingController categoria;
  late final TextEditingController unidade;
  late final TextEditingController valorHora;
  late final TextEditingController valorDiaria;
  late final TextEditingController valorMensal;
  late final TextEditingController marca;
  late final TextEditingController modelo;
  late final TextEditingController placa;
  late final TextEditingController numeroSerie;
  late final TextEditingController anoFab;
  late final TextEditingController dataAquisicao;
  late final TextEditingController vidaUtil;
  late final TextEditingController local;
  late final TextEditingController observacoes;
  late final FocusNode _valorHoraFocus;
  late final FocusNode _valorDiariaFocus;
  late final FocusNode _valorMensalFocus;
  late final FocusNode _dataAquisicaoFocus;
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
    nome = TextEditingController(text: e?['nome']?.toString() ?? '');
    codigo = TextEditingController(text: e?['codigo']?.toString() ?? '');
    descricao = TextEditingController(text: e?['descricao']?.toString() ?? '');
    categoria = TextEditingController(text: e?['categoria']?.toString() ?? '');
    unidade = TextEditingController(
      text: (e != null && '${e['unidade_medida'] ?? ''}'.trim().isNotEmpty)
          ? '${e['unidade_medida']}'
          : 'H',
    );
    final vh = e != null ? _eqToDouble(e['valor_hora']) : 0.0;
    final vd = e != null ? _eqToDouble(e['valor_diaria']) : 0.0;
    final vm = e != null ? _eqToDouble(e['valor_mensal']) : 0.0;
    valorHora = TextEditingController(
      text: e != null && vh > 0 ? _formatPrecoFieldBr(vh) : '',
    );
    valorDiaria = TextEditingController(
      text: e != null && vd > 0 ? _formatPrecoFieldBr(vd) : '',
    );
    valorMensal = TextEditingController(
      text: e != null && vm > 0 ? _formatPrecoFieldBr(vm) : '',
    );
    marca = TextEditingController(text: e?['marca']?.toString() ?? '');
    modelo = TextEditingController(text: e?['modelo']?.toString() ?? '');
    placa = TextEditingController(text: e?['placa_identificacao']?.toString() ?? '');
    numeroSerie = TextEditingController(text: e?['numero_serie']?.toString() ?? '');
    anoFab = TextEditingController(
      text: e != null && e['ano_fabricacao'] != null
          ? '${e['ano_fabricacao']}'
          : '',
    );
    dataAquisicao = TextEditingController(
      text: _isoDateToBrField(e?['data_aquisicao']),
    );
    vidaUtil = TextEditingController(
      text: e != null && e['vida_util'] != null ? '${e['vida_util']}' : '',
    );
    local = TextEditingController(text: e?['localizacao']?.toString() ?? '');
    observacoes = TextEditingController(text: e?['observacoes']?.toString() ?? '');
    situacao = '${e?['situacao'] ?? 'disponivel'}';

    _valorHoraFocus = FocusNode();
    _valorDiariaFocus = FocusNode();
    _valorMensalFocus = FocusNode();
    _dataAquisicaoFocus = FocusNode();
    _valorHoraFocus.addListener(() {
      if (!_valorHoraFocus.hasFocus) _formatPrecoOnBlur(valorHora);
    });
    _valorDiariaFocus.addListener(() {
      if (!_valorDiariaFocus.hasFocus) _formatPrecoOnBlur(valorDiaria);
    });
    _valorMensalFocus.addListener(() {
      if (!_valorMensalFocus.hasFocus) _formatPrecoOnBlur(valorMensal);
    });
  }

  @override
  void dispose() {
    _valorHoraFocus.dispose();
    _valorDiariaFocus.dispose();
    _valorMensalFocus.dispose();
    _dataAquisicaoFocus.dispose();
    nome.dispose();
    codigo.dispose();
    descricao.dispose();
    categoria.dispose();
    unidade.dispose();
    valorHora.dispose();
    valorDiaria.dispose();
    valorMensal.dispose();
    marca.dispose();
    modelo.dispose();
    placa.dispose();
    numeroSerie.dispose();
    anoFab.dispose();
    dataAquisicao.dispose();
    vidaUtil.dispose();
    local.dispose();
    observacoes.dispose();
    super.dispose();
  }

  void _salvar() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    Navigator.of(context).pop(<String, dynamic>{
      'nome': nome.text,
      'codigo': codigo.text,
      'descricao': descricao.text,
      'categoria': categoria.text,
      'unidade': unidade.text,
      'valor_hora': valorHora.text,
      'valor_diaria': valorDiaria.text,
      'valor_mensal': valorMensal.text,
      'marca': marca.text,
      'modelo': modelo.text,
      'placa': placa.text,
      'numero_serie': numeroSerie.text,
      'ano_fabricacao': anoFab.text,
      'data_aquisicao': dataAquisicao.text,
      'vida_util': vidaUtil.text,
      'local': local.text,
      'observacoes': observacoes.text,
      'situacao': situacao,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null
          ? 'Novo equipamento'
          : 'Editar equipamento'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nome,
                decoration: const InputDecoration(labelText: 'Nome *'),
              ),
              TextField(
                controller: codigo,
                decoration: const InputDecoration(labelText: 'Código'),
              ),
              TextField(
                controller: descricao,
                decoration: const InputDecoration(labelText: 'Descrição'),
                maxLines: 2,
              ),
              TextField(
                controller: categoria,
                decoration: const InputDecoration(labelText: 'Categoria'),
              ),
              TextField(
                controller: unidade,
                decoration: const InputDecoration(
                  labelText: 'Unidade de medida * (ex.: H, DIA)',
                ),
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
                controller: valorMensal,
                focusNode: _valorMensalFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,R$\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Valor mensal',
                  hintText: r'R$ 0,00',
                ),
              ),
              TextField(
                controller: marca,
                decoration: const InputDecoration(labelText: 'Marca'),
              ),
              TextField(
                controller: modelo,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              TextField(
                controller: placa,
                decoration: const InputDecoration(labelText: 'Placa / identificação'),
              ),
              TextField(
                controller: numeroSerie,
                decoration: const InputDecoration(labelText: 'Número de série'),
              ),
              TextField(
                controller: anoFab,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Ano fabricação'),
              ),
              TextField(
                controller: dataAquisicao,
                focusNode: _dataAquisicaoFocus,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                onChanged: (v) => _setMaskedValue(
                  dataAquisicao,
                  _formatDateBr(v),
                ),
                decoration: const InputDecoration(
                  labelText: 'Data de aquisição',
                  hintText: 'dd/mm/aaaa',
                ),
              ),
              TextField(
                controller: vidaUtil,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Vida útil (meses)'),
              ),
              TextField(
                controller: local,
                decoration: const InputDecoration(labelText: 'Localização'),
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
                  DropdownMenuItem(value: 'disponivel', child: Text('Disponível')),
                  DropdownMenuItem(value: 'em_uso', child: Text('Em uso')),
                  DropdownMenuItem(value: 'manutencao', child: Text('Manutenção')),
                  DropdownMenuItem(value: 'inativo', child: Text('Inativo')),
                ],
                onChanged: (v) => setState(() => situacao = v ?? 'disponivel'),
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

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

import 'insumos_cadastros_model.dart';
export 'insumos_cadastros_model.dart';

double _insumoToDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString().replaceAll(',', '.')) ?? 0;
}

/// pt-BR: remove milhar (.) e vírgula decimal → ponto (aceita também "R$ 1.234,56").
double _parseDecimalBr(String s) {
  if (s.trim().isEmpty) return 0;
  var t = s.trim();
  if (t.toUpperCase().startsWith('R')) {
    final i = t.indexOf(r'$');
    if (i >= 0) {
      t = t.substring(i + 1).trim();
    }
  }
  t = t.replaceAll(RegExp(r'\s'), '');
  t = t.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(t) ?? 0;
}

String _formatPrecoFieldBr(double v) {
  return NumberFormat.currency(locale: 'pt_BR', symbol: r'R$').format(v);
}

String _formatQtyFieldBr(double v) {
  return NumberFormat('#,##0.##', 'pt_BR').format(v);
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

/// Catálogo de insumos: CRUD na API, depois `syncInsumos()`; listagem e filtros vêm do SQLite.
class InsumosCadastrosWidget extends StatefulWidget {
  const InsumosCadastrosWidget({super.key});

  static String routeName = 'insumosCadastros';
  static String routePath = '/insumosCadastros';

  @override
  State<InsumosCadastrosWidget> createState() => _InsumosCadastrosWidgetState();
}

class _InsumosCadastrosWidgetState extends State<InsumosCadastrosWidget> {
  late InsumosCadastrosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  /// Todas as linhas após filtro/ordenação (export usa isto; `_items` é só a página atual).
  List<Map<String, dynamic>> _filteredAll = [];
  int _total = 0;
  int _page = 1;
  int _perPage = 10;
  String _sortBy = 'nome';
  String _sortOrder = 'asc';
  String _filterSituacao = '';
  String _filterCategoria = '';
  List<String> _categorias = [];

  static const _debounceTag = 'insumos-search';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InsumosCadastrosModel());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Faça login para ver os insumos.';
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
      await custom_actions.syncInsumos();
    } catch (_) {}
    await _loadCategoriasFromSqlite();
    await _fetchInsumos();
  }

  Future<void> _syncAndReloadList() async {
    if (kIsWeb) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    setState(() => _loading = true);
    try {
      await custom_actions.syncInsumos();
    } catch (_) {}
    await _loadCategoriasFromSqlite();
    await _fetchInsumos();
  }

  Future<void> _loadCategoriasFromSqlite() async {
    if (kIsWeb) return;
    try {
      final db = SQLiteManager.instance.database;
      final rows = await db.rawQuery(
        "SELECT DISTINCT categoria FROM insumos WHERE categoria IS NOT NULL AND TRIM(categoria) != '' ORDER BY categoria COLLATE NOCASE",
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
    final preco = _insumoToDouble(row['preco_unitario']);
    final estA = _insumoToDouble(row['estoque_atual']);
    final estM = _insumoToDouble(row['estoque_minimo']);
    final situacao = '${row['situacao'] ?? 'ativo'}';
    final currency = NumberFormat.currency(locale: 'pt_BR', symbol: r'R$');
    final qty = NumberFormat('#,##0.##', 'pt_BR');
    return {
      ...row,
      'id': serverId ?? 0,
      'preco_unitario_formatado': currency.format(preco),
      'estoque_atual_formatado': qty.format(estA),
      'estoque_minimo_formatado': qty.format(estM),
      'status_texto': situacao == 'ativo' ? 'Ativo' : 'Inativo',
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
    final cat = '${m['categoria'] ?? ''}'.toLowerCase();
    return nome.contains(q) || cod.contains(q) || cat.contains(q);
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
        case 'preco_unitario':
          return asc *
              _insumoToDouble(a['preco_unitario'])
                  .compareTo(_insumoToDouble(b['preco_unitario']));
        case 'estoque_atual':
          return asc *
              _insumoToDouble(a['estoque_atual'])
                  .compareTo(_insumoToDouble(b['estoque_atual']));
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

  Future<void> _fetchInsumos() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login para ver os insumos.';
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
        whereArgs: ['insumos'],
      );
      final idByUuid = <String, int>{};
      for (final mr in mappingRows) {
        final u = mr['uuid']?.toString();
        final sid = mr['id_servidor'];
        if (u != null && u.isNotEmpty && sid is int) {
          idByUuid[u] = sid;
        }
      }

      final rawAll = await db.query('insumos');
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
        _error = 'Erro ao ler insumos locais: $e';
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
      await custom_actions.syncInsumos();
    } catch (_) {}
    if (mounted) await _loadCategoriasFromSqlite();
    if (mounted) await _fetchInsumos();
  }

  bool _estoqueBaixo(Map<String, dynamic> m) {
    final ea = _toDouble(m['estoque_atual']);
    final em = _toDouble(m['estoque_minimo']);
    return em > 0 && ea <= em;
  }

  double _toDouble(dynamic v) => _insumoToDouble(v);

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
      'unidade_medida',
      'preco_unitario',
      'estoque_atual',
      'estoque_minimo',
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
        '${dir.path}/insumos_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString('\uFEFF${buf.toString()}', encoding: utf8);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Insumos',
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV gerado (dados locais / filtros atuais).')),
    );
  }

  void _onSearchChanged(String _) {
    EasyDebounce.debounce(
      _debounceTag,
      const Duration(milliseconds: 450),
      () {
        _page = 1;
        _fetchInsumos();
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
            'Insumos',
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
            'Novo insumo',
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
            child: Icon(Icons.inventory_2_outlined,
                color: FlutterFlowTheme.of(context).primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Insumos',
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
                hintText: 'Buscar por nome, código ou categoria...',
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
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterSituacao = v ?? '';
                        _page = 1;
                      });
                      _fetchInsumos();
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
                      _fetchInsumos();
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
                    DropdownMenuItem(value: 'preco_unitario', child: Text('Preço')),
                    DropdownMenuItem(value: 'estoque_atual', child: Text('Estoque')),
                    DropdownMenuItem(value: 'situacao', child: Text('Situação')),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _sortBy = v;
                      _page = 1;
                    });
                    _fetchInsumos();
                  },
                ),
                IconButton(
                  tooltip: _sortOrder == 'asc' ? 'Crescente' : 'Decrescente',
                  onPressed: () {
                    setState(() {
                      _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                      _page = 1;
                    });
                    _fetchInsumos();
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
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _filterSituacao = '';
                        _filterCategoria = '';
                        _page = 1;
                      });
                      _fetchInsumos();
                    },
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const Text('Limpar filtros'),
                  ),
                const Spacer(),
                Chip(
                  avatar: Icon(Icons.analytics_outlined,
                      size: 16, color: FlutterFlowTheme.of(context).primary),
                  label: Text('$_total insumo${_total == 1 ? '' : 's'}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _items.isEmpty) {
      return Center(
        child: CircularProgressIndicator(color: FlutterFlowTheme.of(context).primary),
      );
    }
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56, color: FlutterFlowTheme.of(context).alternate),
            const SizedBox(height: 12),
            Text(
              'Nenhum insumo encontrado',
              style: FlutterFlowTheme.of(context).titleMedium,
            ),
            const SizedBox(height: 8),
            FFButtonWidget(
              onPressed: () => _openForm(context, null),
              text: 'Novo insumo',
              options: FFButtonOptions(
                height: 40,
                color: FlutterFlowTheme.of(context).primary,
                textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                      color: FlutterFlowTheme.of(context).info,
                    ),
              ),
            ),
          ],
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
                    DataColumn(label: Text('Insumo', style: _th(context))),
                    DataColumn(label: Text('Categoria', style: _th(context))),
                    DataColumn(label: Text('Un', style: _th(context))),
                    DataColumn(
                      label: Text('Preço', style: _th(context)),
                      numeric: true,
                    ),
                    DataColumn(label: Text('Estoque', style: _th(context))),
                    DataColumn(label: Text('Estq. mín.', style: _th(context))),
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
    final ativo = situacao == 'ativo';

    return DataRow(
      cells: [
        DataCell(Text('${m['codigo'] ?? '—'}')),
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
        DataCell(Text('${m['unidade_medida'] ?? ''}'.toUpperCase())),
        DataCell(Text('${m['preco_unitario_formatado'] ?? '—'}',
            textAlign: TextAlign.end)),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${m['estoque_atual_formatado'] ?? '—'}',
                style: TextStyle(
                  color: _estoqueBaixo(m)
                      ? FlutterFlowTheme.of(context).error
                      : FlutterFlowTheme.of(context).primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (_estoqueBaixo(m)) ...[
                const SizedBox(width: 4),
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: FlutterFlowTheme.of(context).error),
              ],
            ],
          ),
        ),
        DataCell(Text('${m['estoque_minimo_formatado'] ?? '—'}')),
        DataCell(
          Chip(
            label: Text('${m['status_texto'] ?? situacao}'),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            labelStyle: const TextStyle(fontSize: 11),
            backgroundColor: ativo
                ? Colors.green.withValues(alpha: 0.15)
                : Colors.red.withValues(alpha: 0.12),
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
                  if (v == 'ativo' || v == 'inativo') {
                    _patchSituacao(idInt, v);
                  } else if (v == 'del') {
                    _confirmDelete(context, idInt);
                  }
                },
                itemBuilder: (c) => [
                  const PopupMenuItem(value: 'ativo', child: Text('Ativar')),
                  const PopupMenuItem(value: 'inativo', child: Text('Inativar')),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'del',
                    child: Text('Excluir',
                        style: TextStyle(color: FlutterFlowTheme.of(context).error)),
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
                _fetchInsumos();
              },
            ),
            const Spacer(),
            IconButton(
              onPressed: _page > 1
                  ? () {
                      setState(() => _page--);
                      _fetchInsumos();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página $_page / $lastPage'),
            IconButton(
              onPressed: _page < lastPage
                  ? () {
                      setState(() => _page++);
                      _fetchInsumos();
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
              _kv('Unidade', '${m['unidade_medida'] ?? '—'}'),
              _kv('Preço', '${m['preco_unitario_formatado'] ?? '—'}'),
              _kv('Estoque', '${m['estoque_atual_formatado'] ?? '—'}'),
              _kv('Estoque mín.', '${m['estoque_minimo_formatado'] ?? '—'}'),
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
      builder: (ctx) => _InsumoFormDialog(existing: existing),
    );

    if (result == null || !mounted || !context.mounted) return;

    final nomeVal = (result['nome'] as String?)?.trim() ?? '';
    final codigoVal = (result['codigo'] as String?)?.trim() ?? '';
    final descVal = (result['descricao'] as String?)?.trim() ?? '';
    final catVal = (result['categoria'] as String?)?.trim() ?? '';
    final unVal = (result['unidade'] as String?)?.trim() ?? '';
    final precoVal = result['preco'] as String? ?? '';
    final estVal = result['estoque'] as String? ?? '';
    final estMinVal = result['estMin'] as String? ?? '';
    final locVal = (result['local'] as String?)?.trim() ?? '';
    final situacao = result['situacao'] as String? ?? 'ativo';

    if (nomeVal.isEmpty || unVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha nome e unidade de medida.')),
      );
      return;
    }

    final body = <String, dynamic>{
      'nome': nomeVal,
      'codigo': codigoVal.isEmpty ? null : codigoVal,
      'descricao': descVal.isEmpty ? null : descVal,
      'categoria': catVal.isEmpty ? null : catVal,
      'unidade_medida': unVal,
      'preco_unitario': _parseDecimalBr(precoVal),
      'estoque_atual': _parseDecimalBr(estVal),
      'estoque_minimo': _parseDecimalBr(estMinVal),
      'localizacao': locVal.isEmpty ? null : locVal,
      'situacao': situacao,
    };

    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;

    if (existing == null) {
      final r = await InsumoCreateCall.call(token: token, body: body);
      if (r.succeeded) {
        await _afterMutation('Insumo cadastrado.');
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
      final r = await InsumoUpdateCall.call(token: token, id: idInt, body: body);
      if (r.succeeded) {
        await _afterMutation('Insumo atualizado.');
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
    final r = await InsumoPatchSituacaoCall.call(
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não tem permissão para excluir insumos.'),
        ),
      );
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
        title: const Text('Excluir insumo?'),
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
    final r = await InsumoDeleteCall.call(token: token, id: id);
    if (r.succeeded) {
      await _afterMutation('Insumo excluído.');
    } else {
      _showApiError(r);
    }
  }
}

/// Diálogo com controllers próprios: o `dispose` só roda quando a rota sai da árvore,
/// evitando "used after disposed" durante a animação de fechamento / IME.
class _InsumoFormDialog extends StatefulWidget {
  const _InsumoFormDialog({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_InsumoFormDialog> createState() => _InsumoFormDialogState();
}

class _InsumoFormDialogState extends State<_InsumoFormDialog> {
  late final TextEditingController nome;
  late final TextEditingController codigo;
  late final TextEditingController descricao;
  late final TextEditingController categoria;
  late final TextEditingController unidade;
  late final TextEditingController preco;
  late final TextEditingController estoque;
  late final TextEditingController estMin;
  late final TextEditingController local;
  late final FocusNode _precoFocus;
  late final FocusNode _estoqueFocus;
  late final FocusNode _estMinFocus;
  late String situacao;

  void _setMaskedValue(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  void _formatPrecoOnBlur() {
    if (preco.text.trim().isEmpty) return;
    final v = _parseDecimalBr(preco.text);
    _setMaskedValue(preco, _formatPrecoFieldBr(v));
  }

  void _formatQtyOnBlur(TextEditingController c) {
    if (c.text.trim().isEmpty) return;
    final v = _parseDecimalBr(c.text);
    _setMaskedValue(c, _formatQtyFieldBr(v));
  }

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    nome = TextEditingController(text: e?['nome']?.toString() ?? '');
    codigo = TextEditingController(text: e?['codigo']?.toString() ?? '');
    descricao = TextEditingController(text: e?['descricao']?.toString() ?? '');
    categoria = TextEditingController(text: e?['categoria']?.toString() ?? '');
    unidade = TextEditingController(text: e?['unidade_medida']?.toString() ?? 'UN');
    final p0 = e != null ? _insumoToDouble(e['preco_unitario']) : 0.0;
    final ea0 = e != null ? _insumoToDouble(e['estoque_atual']) : 0.0;
    final em0 = e != null ? _insumoToDouble(e['estoque_minimo']) : 0.0;
    preco = TextEditingController(
      text: e != null ? _formatPrecoFieldBr(p0) : '',
    );
    estoque = TextEditingController(
      text: e != null ? _formatQtyFieldBr(ea0) : '',
    );
    estMin = TextEditingController(
      text: e != null ? _formatQtyFieldBr(em0) : '',
    );
    local = TextEditingController(text: e?['localizacao']?.toString() ?? '');
    situacao = '${e?['situacao'] ?? 'ativo'}';

    _precoFocus = FocusNode();
    _estoqueFocus = FocusNode();
    _estMinFocus = FocusNode();
    _precoFocus.addListener(() {
      if (!_precoFocus.hasFocus) _formatPrecoOnBlur();
    });
    _estoqueFocus.addListener(() {
      if (!_estoqueFocus.hasFocus) _formatQtyOnBlur(estoque);
    });
    _estMinFocus.addListener(() {
      if (!_estMinFocus.hasFocus) _formatQtyOnBlur(estMin);
    });
  }

  @override
  void dispose() {
    _precoFocus.dispose();
    _estoqueFocus.dispose();
    _estMinFocus.dispose();
    nome.dispose();
    codigo.dispose();
    descricao.dispose();
    categoria.dispose();
    unidade.dispose();
    preco.dispose();
    estoque.dispose();
    estMin.dispose();
    local.dispose();
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
      'preco': preco.text,
      'estoque': estoque.text,
      'estMin': estMin.text,
      'local': local.text,
      'situacao': situacao,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Novo insumo' : 'Editar insumo'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 420,
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
                decoration: const InputDecoration(labelText: 'Unidade de medida *'),
              ),
              TextField(
                controller: preco,
                focusNode: _precoFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,R$\s]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Preço unitário',
                  hintText: r'R$ 0,00',
                ),
              ),
              TextField(
                controller: estoque,
                focusNode: _estoqueFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Estoque atual',
                  hintText: '0',
                ),
              ),
              TextField(
                controller: estMin,
                focusNode: _estMinFocus,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Estoque mínimo',
                  hintText: '0',
                ),
              ),
              TextField(
                controller: local,
                decoration: const InputDecoration(labelText: 'Localização'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(situacao),
                initialValue: situacao,
                decoration: const InputDecoration(labelText: 'Situação'),
                items: const [
                  DropdownMenuItem(value: 'ativo', child: Text('Ativo')),
                  DropdownMenuItem(value: 'inativo', child: Text('Inativo')),
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

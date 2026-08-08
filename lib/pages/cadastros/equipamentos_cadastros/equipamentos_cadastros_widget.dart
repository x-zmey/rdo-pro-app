import 'dart:convert';
import 'dart:io';

import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/custom_code/actions/index.dart' as custom_actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
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

Color _situacaoChipColor(String s) {
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
      return Colors.grey.shade600;
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

class _EquipamentosCadastrosWidgetState
    extends State<EquipamentosCadastrosWidget> {
  late EquipamentosCadastrosModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredAll = [];
  int _total = 0;
  String _sortBy = 'nome';
  String _sortOrder = 'asc';
  String _filterSituacao = '';
  String _filterCategoria = '';
  List<String> _categorias = [];
  String _busca = '';

  static const _debounceTag = 'equipamentos-search';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EquipamentosCadastrosModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_equipamentos')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar equipamentos.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
        return;
      }
      _bootstrap();
    });
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
      final owner = FFAppState().creatorUuid.trim();
      if (owner.isEmpty) {
        if (mounted) setState(() => _categorias = []);
        return;
      }
      final rows = await db.rawQuery(
        "SELECT DISTINCT categoria FROM equipamentos WHERE created_by = ? AND categoria IS NOT NULL AND TRIM(categoria) != '' ORDER BY categoria COLLATE NOCASE",
        [owner],
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
              _eqToDouble(a['valor_hora'])
                  .compareTo(_eqToDouble(b['valor_hora']));
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

      final owner = FFAppState().creatorUuid.trim();
      if (owner.isEmpty) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _filteredAll = [];
          _items = [];
          _total = 0;
        });
        return;
      }
      final rawAll = await db.query(
        'equipamentos',
        where: 'created_by = ?',
        whereArgs: [owner],
      );
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

      if (!mounted) return;
      setState(() {
        _loading = false;
        _filteredAll = filtered;
        _items = filtered;
        _total = filtered.length;
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

  int _serverId(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is int) return id;
    return int.tryParse('$id') ?? 0;
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

  void _onSearchChanged(String value) {
    setState(() => _busca = value);
    EasyDebounce.debounce(
      _debounceTag,
      const Duration(milliseconds: 450),
      () => _fetchEquipamentos(),
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
    final theme = FlutterFlowTheme.of(context);
    final canCreate = MembershipAccess.canPermission('create_equipamentos');
    final canEdit = MembershipAccess.canPermission('edit_equipamentos');
    final canDelete = MembershipAccess.canPermission('delete_equipamentos');

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primary,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
          titleSpacing: 0,
          toolbarHeight: 58,
          iconTheme: const IconThemeData(color: Colors.white),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => context.safePop(),
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Equipamentos',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Catálogo geral do sistema',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 11.5,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Sincronizar e atualizar',
              onPressed: _loading ? null : _syncAndReloadList,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded,
                      color: Colors.white, size: 21),
            ),
            PopupMenuButton<String>(
              tooltip: 'Mais opções',
              icon: const Icon(Icons.more_vert_rounded,
                  color: Colors.white, size: 22),
              onSelected: (v) {
                if (v == 'csv') {
                  _exportLocalCsv();
                  return;
                }
                if (v.startsWith('sort:')) {
                  setState(() => _sortBy = v.substring(5));
                  _fetchEquipamentos();
                  return;
                }
                if (v == 'order') {
                  setState(() {
                    _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                  });
                  _fetchEquipamentos();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'order',
                  child: Text(
                    _sortOrder == 'asc'
                        ? 'Ordenar decrescente'
                        : 'Ordenar crescente',
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'sort:nome', child: Text('Ordenar por nome')),
                const PopupMenuItem(
                    value: 'sort:codigo', child: Text('Ordenar por código')),
                const PopupMenuItem(
                    value: 'sort:categoria',
                    child: Text('Ordenar por categoria')),
                const PopupMenuItem(
                    value: 'sort:marca', child: Text('Ordenar por marca')),
                const PopupMenuItem(
                    value: 'sort:situacao',
                    child: Text('Ordenar por situação')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
              ],
            ),
            if (canCreate)
              IconButton(
                tooltip: 'Novo equipamento',
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
                onPressed: () => _openForm(null),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: theme.primary,
                onRefresh: _syncAndReloadList,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    10,
                    16,
                    kBarraNavegacaoPrincipalReservaScroll,
                  ),
                  children: [
                    if (canCreate)
                      RdoSectionCard(
                        title: 'Incluir equipamento',
                        icon: Icons.add_box_outlined,
                        subtitle: 'Cadastrar no catálogo',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: () => _openForm(null),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Novo equipamento',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 42),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    RdoSectionCard(
                      title: 'Buscar e filtrar',
                      icon: Icons.search_rounded,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: _onSearchChanged,
                            style: rdoFormFieldTextStyle(context),
                            decoration: rdoFormFieldDecoration(
                              context,
                              label: 'Nome, código, placa, marca ou modelo',
                              hint: 'Digite para filtrar',
                              suffixIcon: _busca.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Limpar',
                                      icon: Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                        color: theme.secondaryText,
                                      ),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() => _busca = '');
                                        _fetchEquipamentos();
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('f_sit_$_filterSituacao'),
                                  initialValue: _filterSituacao,
                                  isExpanded: true,
                                  style: rdoFormFieldTextStyle(context),
                                  decoration: rdoFormFieldDecoration(
                                    context,
                                    label: 'Situação',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: '', child: Text('Todas')),
                                    DropdownMenuItem(
                                        value: 'disponivel',
                                        child: Text('Disponível')),
                                    DropdownMenuItem(
                                        value: 'em_uso',
                                        child: Text('Em uso')),
                                    DropdownMenuItem(
                                        value: 'manutencao',
                                        child: Text('Manutenção')),
                                    DropdownMenuItem(
                                        value: 'inativo',
                                        child: Text('Inativo')),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _filterSituacao = v ?? '');
                                    _fetchEquipamentos();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('f_cat_$_filterCategoria'),
                                  initialValue: _filterCategoria,
                                  isExpanded: true,
                                  style: rdoFormFieldTextStyle(context),
                                  decoration: rdoFormFieldDecoration(
                                    context,
                                    label: 'Categoria',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '', child: Text('Todas')),
                                    ..._categorias.map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (_filterCategoria.isNotEmpty &&
                                        !_categorias
                                            .contains(_filterCategoria))
                                      DropdownMenuItem(
                                        value: _filterCategoria,
                                        child: Text(
                                          _filterCategoria,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    setState(
                                        () => _filterCategoria = v ?? '');
                                    _fetchEquipamentos();
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_filterSituacao.isNotEmpty ||
                              _filterCategoria.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _filterSituacao = '';
                                    _filterCategoria = '';
                                  });
                                  _fetchEquipamentos();
                                },
                                icon: Icon(
                                  Icons.filter_alt_off_rounded,
                                  size: 16,
                                  color: theme.secondaryText,
                                ),
                                label: Text(
                                  'Limpar filtros',
                                  style: GoogleFonts.inter(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: theme.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    RdoSectionCard(
                      title: 'Lista de equipamentos',
                      icon: Icons.handyman_outlined,
                      subtitle: _loading
                          ? 'Carregando…'
                          : _error != null
                              ? 'Falha ao carregar'
                              : _items.isEmpty
                                  ? 'Nenhum equipamento encontrado'
                                  : _busca.trim().isEmpty &&
                                          _filterSituacao.isEmpty &&
                                          _filterCategoria.isEmpty
                                      ? 'Catálogo sincronizado'
                                      : '$_total resultado${_total == 1 ? '' : 's'}',
                      margin: EdgeInsets.zero,
                      trailing:
                          _items.isEmpty ? null : RdoContadorChip('$_total'),
                      contentPadding: EdgeInsets.zero,
                      child: _buildLista(theme, canCreate, canEdit, canDelete),
                    ),
                  ],
                ),
              ),
            ),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _buildLista(
    FlutterFlowTheme theme,
    bool canCreate,
    bool canEdit,
    bool canDelete,
  ) {
    if (_loading && _items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 36),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }

    if (_error != null && _items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 28),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: theme.error),
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 13, color: theme.error),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _syncAndReloadList,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                'Tentar novamente',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(160, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
        child: Column(
          children: [
            Icon(
              Icons.handyman_outlined,
              size: 40,
              color: theme.secondaryText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _busca.trim().isEmpty &&
                      _filterSituacao.isEmpty &&
                      _filterCategoria.isEmpty
                  ? 'Nenhum equipamento cadastrado'
                  : 'Nenhum resultado nos filtros',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _busca.trim().isEmpty &&
                      _filterSituacao.isEmpty &&
                      _filterCategoria.isEmpty
                  ? (canCreate
                      ? 'Cadastre o primeiro equipamento do catálogo.'
                      : 'Não há equipamentos disponíveis.')
                  : 'Ajuste a busca ou limpe os filtros.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 12.5,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < _items.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, color: theme.alternate),
          _buildEquipamentoItem(theme, _items[i], canEdit, canDelete),
        ],
      ],
    );
  }

  Widget _buildEquipamentoItem(
    FlutterFlowTheme theme,
    Map<String, dynamic> m,
    bool canEdit,
    bool canDelete,
  ) {
    final nome = valueOrDefault<String>(
        m['nome']?.toString(), 'Equipamento sem nome');
    final codigo = '${m['codigo'] ?? ''}'.trim();
    final categoria = '${m['categoria'] ?? ''}'.trim();
    final marca = '${m['marca'] ?? ''}'.trim();
    final modelo = '${m['modelo'] ?? ''}'.trim();
    final placa = '${m['placa_identificacao'] ?? ''}'.trim();
    final situacao = '${m['situacao'] ?? 'disponivel'}';
    final statusCor = _situacaoChipColor(situacao);
    final sid = _serverId(m);
    final temAcoes = canEdit || canDelete;

    final marcaModelo = [
      if (marca.isNotEmpty) marca,
      if (modelo.isNotEmpty) modelo,
    ].join(' / ');

    final valores = <String>[];
    if (_eqToDouble(m['valor_hora']) > 0) {
      valores.add('H ${m['valor_hora_formatado']}');
    }
    if (_eqToDouble(m['valor_diaria']) > 0) {
      valores.add('D ${m['valor_diaria_formatado']}');
    }
    if (_eqToDouble(m['valor_mensal']) > 0) {
      valores.add('M ${m['valor_mensal_formatado']}');
    }

    final meta = [
      if (codigo.isNotEmpty) codigo,
      if (categoria.isNotEmpty) categoria,
      if (marcaModelo.isNotEmpty) marcaModelo,
      if (placa.isNotEmpty) placa,
      if (valores.isNotEmpty) valores.join(' · '),
    ].join(' · ');

    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: canEdit ? () => _openForm(m) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: statusCor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 10, temAcoes ? 4 : 12, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: statusCor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.handyman_rounded,
                          size: 18,
                          color: statusCor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    nome,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: statusCor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _statusEquipLabel(situacao),
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: statusCor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (meta.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                meta,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11.5,
                                  color: theme.secondaryText,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (canEdit)
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _openForm(m),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.edit_outlined,
                            size: 18,
                            color: theme.secondaryText,
                          ),
                        ),
                      if (canDelete)
                        IconButton(
                          tooltip: 'Excluir',
                          onPressed: () => _confirmDelete(sid),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: theme.error,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openForm(Map<String, dynamic>? existing) async {
    if (existing == null) {
      if (!MembershipAccess.canPermission('create_equipamentos')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para criar equipamentos.',
        );
        return;
      }
    } else if (!MembershipAccess.canPermission('edit_equipamentos')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar equipamentos.',
      );
      return;
    }

    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _EquipamentoFormSheet(existing: existing),
      ),
    );

    if (result == null || !mounted) return;

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
      final idInt = _serverId(existing);
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
      final r =
          await EquipamentoUpdateCall.call(token: token, id: idInt, body: body);
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

  Future<void> _confirmDelete(int id) async {
    if (!MembershipAccess.canPermission('delete_equipamentos')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir equipamentos.',
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

    final theme = FlutterFlowTheme.of(context);
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Excluir equipamento?',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        content: Text(
          'Esta ação não pode ser desfeita.',
          style: GoogleFonts.inter(fontSize: 13.5, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: theme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
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

class _EquipamentoFormSheet extends StatefulWidget {
  const _EquipamentoFormSheet({this.existing});

  final Map<String, dynamic>? existing;

  @override
  State<_EquipamentoFormSheet> createState() => _EquipamentoFormSheetState();
}

class _EquipamentoFormSheetState extends State<_EquipamentoFormSheet> {
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
    placa =
        TextEditingController(text: e?['placa_identificacao']?.toString() ?? '');
    numeroSerie =
        TextEditingController(text: e?['numero_serie']?.toString() ?? '');
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
    observacoes =
        TextEditingController(text: e?['observacoes']?.toString() ?? '');
    situacao = '${e?['situacao'] ?? 'disponivel'}';

    _valorHoraFocus = FocusNode();
    _valorDiariaFocus = FocusNode();
    _valorMensalFocus = FocusNode();
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
    final theme = FlutterFlowTheme.of(context);
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(kRdoRadius),
        border: Border.all(color: theme.alternate),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
            child: Row(
              children: [
                Icon(Icons.handyman_outlined,
                    size: 18, color: theme.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'Novo equipamento'
                        : 'Editar equipamento',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.primaryText,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded,
                      size: 20, color: theme.secondaryText),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Column(
                children: [
                  TextField(
                    controller: nome,
                    style: rdoFormFieldTextStyle(context),
                    decoration:
                        rdoFormFieldDecoration(context, label: 'Nome *'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: codigo,
                          style: rdoFormFieldTextStyle(context),
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'Código',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: unidade,
                          style: rdoFormFieldTextStyle(context),
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'Unidade *',
                            hint: 'H, DIA',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: categoria,
                    style: rdoFormFieldTextStyle(context),
                    decoration:
                        rdoFormFieldDecoration(context, label: 'Categoria'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descricao,
                    style: rdoFormFieldTextStyle(context),
                    maxLines: 2,
                    decoration:
                        rdoFormFieldDecoration(context, label: 'Descrição'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valorHora,
                          focusNode: _valorHoraFocus,
                          style: rdoFormFieldTextStyle(context),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,R$\s]')),
                          ],
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'Valor hora',
                            hint: r'R$ 0,00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: valorDiaria,
                          focusNode: _valorDiariaFocus,
                          style: rdoFormFieldTextStyle(context),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.,R$\s]')),
                          ],
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'Valor diária',
                            hint: r'R$ 0,00',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: valorMensal,
                    focusNode: _valorMensalFocus,
                    style: rdoFormFieldTextStyle(context),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'[0-9.,R$\s]')),
                    ],
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Valor mensal',
                      hint: r'R$ 0,00',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: marca,
                          style: rdoFormFieldTextStyle(context),
                          decoration:
                              rdoFormFieldDecoration(context, label: 'Marca'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: modelo,
                          style: rdoFormFieldTextStyle(context),
                          decoration:
                              rdoFormFieldDecoration(context, label: 'Modelo'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: placa,
                    style: rdoFormFieldTextStyle(context),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Placa / identificação',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: numeroSerie,
                    style: rdoFormFieldTextStyle(context),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Número de série',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: anoFab,
                          style: rdoFormFieldTextStyle(context),
                          keyboardType: TextInputType.number,
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'Ano fabricação',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: vidaUtil,
                          style: rdoFormFieldTextStyle(context),
                          keyboardType: TextInputType.number,
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'Vida útil (meses)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: dataAquisicao,
                    style: rdoFormFieldTextStyle(context),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (v) => _setMaskedValue(
                      dataAquisicao,
                      _formatDateBr(v),
                    ),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Data de aquisição',
                      hint: 'dd/mm/aaaa',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: local,
                    style: rdoFormFieldTextStyle(context),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Localização',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: observacoes,
                    style: rdoFormFieldTextStyle(context),
                    maxLines: 2,
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Observações',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    key: ValueKey(situacao),
                    initialValue: situacao,
                    style: rdoFormFieldTextStyle(context),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Situação',
                    ),
                    items: const [
                      DropdownMenuItem(
                          value: 'disponivel', child: Text('Disponível')),
                      DropdownMenuItem(value: 'em_uso', child: Text('Em uso')),
                      DropdownMenuItem(
                          value: 'manutencao', child: Text('Manutenção')),
                      DropdownMenuItem(
                          value: 'inativo', child: Text('Inativo')),
                    ],
                    onChanged: (v) =>
                        setState(() => situacao = v ?? 'disponivel'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.secondaryText,
                      side: BorderSide(color: theme.alternate),
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Cancelar',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _salvar,
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 42),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Salvar',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

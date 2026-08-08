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

Color _situacaoMoColor(String s) {
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
      return Colors.grey.shade600;
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
  String _sortBy = 'nome_completo';
  String _sortOrder = 'asc';
  String _filterSituacao = '';
  String _filterCargo = '';
  List<String> _cargos = [];
  List<String> _funcoesMaoObra = [];
  String _busca = '';

  static const _debounceTag = 'mao-obra-search';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MaoObraCadastrosModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_mao_obra')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar mão de obra.',
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
      final owner = FFAppState().creatorUuid.trim();
      if (owner.isEmpty) {
        if (mounted) setState(() => _cargos = []);
        return;
      }
      final rows = await db.rawQuery(
        "SELECT DISTINCT cargo_funcao FROM mao_obra_profissionais WHERE created_by = ? AND cargo_funcao IS NOT NULL AND TRIM(cargo_funcao) != '' ORDER BY cargo_funcao COLLATE NOCASE",
        [owner],
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
          return asc *
              '${a['data_admissao'] ?? ''}'
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
        'mao_obra_profissionais',
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

  void _onSearchChanged(String value) {
    setState(() => _busca = value);
    EasyDebounce.debounce(
      _debounceTag,
      const Duration(milliseconds: 450),
      () => _fetchProfissionais(),
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
    final canCreate = MembershipAccess.canPermission('create_mao_obra');
    final canEdit = MembershipAccess.canPermission('edit_mao_obra');
    final canDelete = MembershipAccess.canPermission('delete_mao_obra');

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
                  'Mão de obra',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Cadastro de profissionais',
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
                  _fetchProfissionais();
                  return;
                }
                if (v == 'order') {
                  setState(() {
                    _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                  });
                  _fetchProfissionais();
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
                    value: 'sort:nome_completo', child: Text('Ordenar por nome')),
                const PopupMenuItem(
                    value: 'sort:cpf', child: Text('Ordenar por CPF')),
                const PopupMenuItem(
                    value: 'sort:cargo_funcao', child: Text('Ordenar por cargo')),
                const PopupMenuItem(
                    value: 'sort:valor_hora',
                    child: Text('Ordenar por valor hora')),
                const PopupMenuItem(
                    value: 'sort:valor_diaria',
                    child: Text('Ordenar por valor diária')),
                const PopupMenuItem(
                    value: 'sort:data_admissao',
                    child: Text('Ordenar por admissão')),
                const PopupMenuItem(
                    value: 'sort:situacao',
                    child: Text('Ordenar por situação')),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'csv', child: Text('Exportar CSV')),
              ],
            ),
            if (canCreate)
              IconButton(
                tooltip: 'Novo profissional',
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
                        title: 'Incluir profissional',
                        icon: Icons.person_add_alt_1_outlined,
                        subtitle: 'Cadastrar no catálogo',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: () => _openForm(null),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Novo profissional',
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
                              label: 'Nome, CPF, cargo ou e-mail',
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
                                        _fetchProfissionais();
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
                                  style: rdoFormFieldTextStyle(context),
                                  decoration: rdoFormFieldDecoration(
                                    context,
                                    label: 'Situação',
                                  ),
                                  items: const [
                                    DropdownMenuItem(
                                        value: '', child: Text('Todas')),
                                    DropdownMenuItem(
                                        value: 'ativo', child: Text('Ativo')),
                                    DropdownMenuItem(
                                        value: 'inativo',
                                        child: Text('Inativo')),
                                    DropdownMenuItem(
                                        value: 'ferias', child: Text('Férias')),
                                    DropdownMenuItem(
                                        value: 'afastado',
                                        child: Text('Afastado')),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _filterSituacao = v ?? '');
                                    _fetchProfissionais();
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  key: ValueKey('f_car_$_filterCargo'),
                                  initialValue: _filterCargo,
                                  isExpanded: true,
                                  style: rdoFormFieldTextStyle(context),
                                  decoration: rdoFormFieldDecoration(
                                    context,
                                    label: 'Cargo / função',
                                  ),
                                  items: [
                                    const DropdownMenuItem(
                                        value: '', child: Text('Todos')),
                                    ..._cargos.map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(
                                          c,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    if (_filterCargo.isNotEmpty &&
                                        !_cargos.contains(_filterCargo))
                                      DropdownMenuItem(
                                        value: _filterCargo,
                                        child: Text(
                                          _filterCargo,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (v) {
                                    setState(() => _filterCargo = v ?? '');
                                    _fetchProfissionais();
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (_filterSituacao.isNotEmpty ||
                              _filterCargo.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _filterSituacao = '';
                                    _filterCargo = '';
                                  });
                                  _fetchProfissionais();
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
                      title: 'Lista de profissionais',
                      icon: Icons.groups_outlined,
                      subtitle: _loading
                          ? 'Carregando…'
                          : _error != null
                              ? 'Falha ao carregar'
                              : _items.isEmpty
                                  ? 'Nenhum profissional encontrado'
                                  : _busca.trim().isEmpty &&
                                          _filterSituacao.isEmpty &&
                                          _filterCargo.isEmpty
                                      ? 'Cadastro sincronizado'
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
              Icons.people_outline_rounded,
              size: 40,
              color: theme.secondaryText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _busca.trim().isEmpty &&
                      _filterSituacao.isEmpty &&
                      _filterCargo.isEmpty
                  ? 'Nenhum profissional cadastrado'
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
                      _filterCargo.isEmpty
                  ? (canCreate
                      ? 'Cadastre o primeiro profissional.'
                      : 'Não há profissionais disponíveis.')
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
          _buildItem(theme, _items[i], canEdit, canDelete),
        ],
      ],
    );
  }

  Widget _buildItem(
    FlutterFlowTheme theme,
    Map<String, dynamic> m,
    bool canEdit,
    bool canDelete,
  ) {
    final nome = valueOrDefault<String>(
        m['nome_completo']?.toString(), 'Profissional sem nome');
    final cargo = '${m['cargo_funcao'] ?? ''}'.trim();
    final cpf = '${m['cpf_formatado'] ?? '—'}';
    final tel = '${m['telefone_formatado'] ?? '—'}';
    final situacao = '${m['situacao'] ?? ''}';
    final statusLabel = '${m['status_texto'] ?? _statusMoLabel(situacao)}';
    final statusColor = _situacaoMoColor(situacao);
    final sid = _serverId(m);
    final temAcoes = canEdit || canDelete;

    final meta = [
      if (cargo.isNotEmpty) cargo,
      if (cpf != '—') cpf,
      if (tel != '—') tel,
    ].join(' · ');

    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: canEdit ? () => _openForm(m) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: statusColor),
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
                          color: theme.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          size: 18,
                          color: theme.primary,
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
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusLabel,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
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
      if (!MembershipAccess.canPermission('create_mao_obra')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para criar mão de obra.',
        );
        return;
      }
    } else if (!MembershipAccess.canPermission('edit_mao_obra')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar mão de obra.',
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
        child: _ProfissionalFormSheet(
          existing: existing,
          funcoes: _funcoesMaoObra,
        ),
      ),
    );

    if (result == null || !mounted) return;

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
      final r =
          await MaoObraProfissionalCreateCall.call(token: token, body: body);
      if (r.succeeded) {
        await _afterMutation('Profissional cadastrado.');
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

  Future<void> _confirmDelete(int id) async {
    if (!MembershipAccess.canPermission('delete_mao_obra')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir mão de obra.',
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
          'Excluir profissional?',
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
    final r = await MaoObraProfissionalDeleteCall.call(token: token, id: id);
    if (r.succeeded) {
      await _afterMutation('Profissional excluído.');
    } else {
      _showApiError(r);
    }
  }
}

class _ProfissionalFormSheet extends StatefulWidget {
  const _ProfissionalFormSheet({this.existing, required this.funcoes});

  final Map<String, dynamic>? existing;
  final List<String> funcoes;

  @override
  State<_ProfissionalFormSheet> createState() => _ProfissionalFormSheetState();
}

class _ProfissionalFormSheetState extends State<_ProfissionalFormSheet> {
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
    observacoes =
        TextEditingController(text: e?['observacoes']?.toString() ?? '');
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
    final theme = FlutterFlowTheme.of(context);
    final cargoAtual = cargoFuncao.text.trim();
    final funcaoSelecionada =
        widget.funcoes.contains(cargoAtual) ? cargoAtual : '';

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
                Icon(Icons.person_outline_rounded,
                    size: 18, color: theme.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.existing == null
                        ? 'Novo profissional'
                        : 'Editar profissional',
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
                    controller: nomeCompleto,
                    style: rdoFormFieldTextStyle(context),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Nome completo *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cpf,
                          style: rdoFormFieldTextStyle(context),
                          keyboardType: TextInputType.number,
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'CPF',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: rg,
                          style: rdoFormFieldTextStyle(context),
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'RG',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.funcoes.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: funcaoSelecionada,
                      isExpanded: true,
                      style: rdoFormFieldTextStyle(context),
                      decoration: rdoFormFieldDecoration(
                        context,
                        label: 'Função predefinida',
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: '',
                          child: Text('Selecionar (opcional)'),
                        ),
                        ...widget.funcoes.map(
                          (f) => DropdownMenuItem<String>(
                            value: f,
                            child: Text(f, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v == null || v.isEmpty) return;
                        setState(() => _setMaskedValue(cargoFuncao, v));
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: cargoFuncao,
                    style: rdoFormFieldTextStyle(context),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Cargo / função *',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: telefone,
                          style: rdoFormFieldTextStyle(context),
                          keyboardType: TextInputType.phone,
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'Telefone',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: email,
                          style: rdoFormFieldTextStyle(context),
                          keyboardType: TextInputType.emailAddress,
                          decoration: rdoFormFieldDecoration(
                            context,
                            label: 'E-mail',
                          ),
                        ),
                      ),
                    ],
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
                    controller: dataAdmissao,
                    focusNode: _dataAdmissaoFocus,
                    style: rdoFormFieldTextStyle(context),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (v) => _setMaskedValue(
                      dataAdmissao,
                      _formatDateBr(v),
                    ),
                    decoration: rdoFormFieldDecoration(
                      context,
                      label: 'Data de admissão',
                      hint: 'dd/mm/aaaa',
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
                      DropdownMenuItem(value: 'ativo', child: Text('Ativo')),
                      DropdownMenuItem(
                          value: 'inativo', child: Text('Inativo')),
                      DropdownMenuItem(value: 'ferias', child: Text('Férias')),
                      DropdownMenuItem(
                          value: 'afastado', child: Text('Afastado')),
                    ],
                    onChanged: (v) => setState(() => situacao = v ?? 'ativo'),
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

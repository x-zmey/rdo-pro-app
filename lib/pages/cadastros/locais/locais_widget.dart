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
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'locais_model.dart';
export 'locais_model.dart';

bool _localAtivo(Map<String, dynamic> m) {
  final s = m['situacao'];
  if (s == null) return true;
  if (s is int) return s != 0;
  if (s is bool) return s;
  final t = s.toString().trim().toLowerCase();
  if (t == '0' || t == 'inativo') return false;
  return true;
}

String _situacaoLabel(Map<String, dynamic> m) =>
    _localAtivo(m) ? 'Ativo' : 'Inativo';

/// Locais: CRUD na API (`nome`), depois `syncLocais()`; listagem e filtros no SQLite.
class LocaisWidget extends StatefulWidget {
  const LocaisWidget({super.key});

  static String routeName = 'locais';
  static String routePath = '/locais';

  @override
  State<LocaisWidget> createState() => _LocaisWidgetState();
}

class _LocaisWidgetState extends State<LocaisWidget> {
  late LocaisModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredAll = [];
  int _total = 0;
  String _sortOrder = 'asc';
  String _filterSituacao = '';
  String _busca = '';

  static const _debounceTag = 'locais-search';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LocaisModel());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_cadastros_gerais')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar cadastros gerais.',
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
          _error = 'Faça login para ver os locais.';
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
      await custom_actions.syncLocais();
    } catch (_) {}
    await _fetchLocais();
  }

  Future<void> _syncAndReloadList() async {
    if (kIsWeb) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    setState(() => _loading = true);
    try {
      await custom_actions.syncLocais();
    } catch (_) {}
    await _fetchLocais();
  }

  Map<String, dynamic> _displayRow(
    Map<String, dynamic> row,
    int? serverId,
  ) {
    return {
      ...row,
      'id': serverId ?? 0,
      'status_texto': _situacaoLabel(row),
    };
  }

  bool _rowMatchesFilters(Map<String, dynamic> m) {
    if (_filterSituacao == 'ativo' && !_localAtivo(m)) return false;
    if (_filterSituacao == 'inativo' && _localAtivo(m)) return false;

    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${m['nome'] ?? ''}'.toLowerCase().contains(q);
  }

  void _sortFiltered(List<Map<String, dynamic>> list) {
    final asc = _sortOrder == 'asc' ? 1 : -1;
    list.sort((a, b) =>
        asc *
        '${a['nome'] ?? ''}'.toLowerCase().compareTo(
              '${b['nome'] ?? ''}'.toLowerCase(),
            ));
  }

  Future<void> _fetchLocais() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login para ver os locais.';
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
        whereArgs: ['locais'],
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
        'locais',
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
        mapped.add(_displayRow(row, serverId));
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
        _error = 'Erro ao ler locais no SQLite: $e';
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
      await custom_actions.syncLocais();
    } catch (_) {}
    if (mounted) await _fetchLocais();
  }

  int _serverId(Map<String, dynamic> m) {
    final id = m['id'];
    if (id is int) return id;
    return int.tryParse('$id') ?? 0;
  }

  Future<void> _exportCsv() async {
    if (kIsWeb) return;
    if (_filteredAll.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nenhum dado para exportar (filtros).')),
        );
      }
      return;
    }

    const keys = ['nome', 'situacao', 'status_texto'];
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
        '${dir.path}/locais_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString('\uFEFF${buf.toString()}', encoding: utf8);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Locais',
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
      () => _fetchLocais(),
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
    final canCreate =
        MembershipAccess.canPermission('create_cadastros_gerais');
    final canEdit = MembershipAccess.canPermission('edit_cadastros_gerais');
    final canDelete =
        MembershipAccess.canPermission('delete_cadastros_gerais');

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
                  'Locais',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Cadastro de locais de obras',
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
                  _exportCsv();
                  return;
                }
                if (v == 'order') {
                  setState(() {
                    _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                  });
                  _fetchLocais();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'order',
                  child: Text(
                    _sortOrder == 'asc' ? 'Ordenar Z–A' : 'Ordenar A–Z',
                  ),
                ),
                const PopupMenuItem(
                  value: 'csv',
                  child: Text('Exportar CSV'),
                ),
              ],
            ),
            if (canCreate)
              IconButton(
                tooltip: 'Novo local',
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
                        title: 'Incluir local',
                        icon: Icons.place_outlined,
                        subtitle: 'Cadastrar local / ambiente',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: () => _openForm(null),
                          icon: const Icon(Icons.add_rounded, size: 18),
                          label: Text(
                            'Novo local',
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
                              label: 'Nome do local',
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
                                        _fetchLocais();
                                      },
                                    ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            key: ValueKey('loc_f_$_filterSituacao'),
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
                                  value: 'inativo', child: Text('Inativo')),
                            ],
                            onChanged: (v) {
                              setState(() => _filterSituacao = v ?? '');
                              _fetchLocais();
                            },
                          ),
                          if (_filterSituacao.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () {
                                  setState(() => _filterSituacao = '');
                                  _fetchLocais();
                                },
                                icon: Icon(
                                  Icons.filter_alt_off_rounded,
                                  size: 16,
                                  color: theme.secondaryText,
                                ),
                                label: Text(
                                  'Limpar filtro',
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
                      title: 'Lista de locais',
                      icon: Icons.place_outlined,
                      subtitle: _loading
                          ? 'Carregando…'
                          : _error != null
                              ? 'Falha ao carregar'
                              : _items.isEmpty
                                  ? 'Nenhum local encontrado'
                                  : _busca.trim().isEmpty &&
                                          _filterSituacao.isEmpty
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
              Icons.location_off_outlined,
              size: 40,
              color: theme.secondaryText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _busca.trim().isEmpty && _filterSituacao.isEmpty
                  ? 'Nenhum local cadastrado'
                  : 'Nenhum resultado nos filtros',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _busca.trim().isEmpty && _filterSituacao.isEmpty
                  ? (canCreate
                      ? 'Cadastre o primeiro local para usar nas obras.'
                      : 'Não há locais disponíveis.')
                  : 'Ajuste a busca ou limpe o filtro.',
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
    Map<String, dynamic> local,
    bool canEdit,
    bool canDelete,
  ) {
    final nome =
        valueOrDefault<String>(local['nome']?.toString(), 'Local sem nome');
    final ativo = _localAtivo(local);
    final sid = _serverId(local);
    final temAcoes = canEdit || canDelete;
    final statusColor =
        ativo ? Colors.green.shade700 : Colors.grey.shade700;

    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: canEdit ? () => _openForm(local) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: statusColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(12, 12, temAcoes ? 4 : 12, 12),
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
                          Icons.place_rounded,
                          size: 18,
                          color: theme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
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
                                ativo ? 'Ativo' : 'Inativo',
                                style: GoogleFonts.inter(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (canEdit)
                        IconButton(
                          tooltip: 'Editar',
                          onPressed: () => _openForm(local),
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
      if (!MembershipAccess.canPermission('create_cadastros_gerais')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para criar cadastros gerais.',
        );
        return;
      }
    } else if (!MembershipAccess.canPermission('edit_cadastros_gerais')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar cadastros gerais.',
      );
      return;
    }

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: _LocalNomeSheet(
          titulo: existing == null ? 'Novo local' : 'Editar local',
          nomeInicial: existing?['nome']?.toString() ?? '',
        ),
      ),
    );

    if (result == null || !mounted) return;
    final nomeVal = result.trim();
    if (nomeVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do local.')),
      );
      return;
    }

    final body = <String, dynamic>{'nome': nomeVal};
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;

    if (existing == null) {
      final r = await LocalCreateCall.call(token: token, body: body);
      if (r.succeeded) {
        await _afterMutation('Local cadastrado.');
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
      final r = await LocalUpdateCall.call(token: token, id: idInt, body: body);
      if (r.succeeded) {
        await _afterMutation('Local atualizado.');
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
    if (!MembershipAccess.canPermission('delete_cadastros_gerais')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir cadastros gerais.',
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
          'Excluir local?',
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
    final r = await LocalDeleteCall.call(token: token, id: id);
    if (r.succeeded) {
      await _afterMutation('Local excluído.');
    } else {
      _showApiError(r);
    }
  }
}

class _LocalNomeSheet extends StatefulWidget {
  const _LocalNomeSheet({
    required this.titulo,
    required this.nomeInicial,
  });

  final String titulo;
  final String nomeInicial;

  @override
  State<_LocalNomeSheet> createState() => _LocalNomeSheetState();
}

class _LocalNomeSheetState extends State<_LocalNomeSheet> {
  late final TextEditingController _nome;

  @override
  void initState() {
    super.initState();
    _nome = TextEditingController(text: widget.nomeInicial);
  }

  @override
  void dispose() {
    _nome.dispose();
    super.dispose();
  }

  void _salvar() {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(_nome.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(kRdoRadius),
        border: Border.all(color: theme.alternate),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.place_outlined,
                    size: 18, color: theme.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.titulo,
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
            const SizedBox(height: 8),
            TextField(
              controller: _nome,
              autofocus: true,
              style: rdoFormFieldTextStyle(context),
              decoration: rdoFormFieldDecoration(
                context,
                label: 'Nome do local *',
                hint: 'Ex.: Bloco A, Pavimento 2…',
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _salvar(),
            ),
            const SizedBox(height: 14),
            Row(
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
          ],
        ),
      ),
    );
  }
}

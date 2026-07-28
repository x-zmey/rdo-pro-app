import 'dart:convert';
import 'dart:io';

import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/situacao_soft_delete.dart';
import '/backend/sqlite/sqlite_manager.dart';
import '/custom_code/actions/index.dart' as custom_actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'grupos_obras_model.dart';
export 'grupos_obras_model.dart';

bool _grupoAtivo(Map<String, dynamic> m) {
  final s = m['situacao'];
  if (s == null) return true;
  if (s is int) return s != kSituacaoExcluidoLogico;
  final t = int.tryParse(s.toString());
  return t != kSituacaoExcluidoLogico;
}

/// Grupos de obras: CRUD na API (`nome`), depois `syncGruposObras()`; listagem no SQLite (como o list Vue).
class GruposObrasWidget extends StatefulWidget {
  const GruposObrasWidget({super.key});

  static String routeName = 'GruposObras';
  static String routePath = '/gruposObras';

  @override
  State<GruposObrasWidget> createState() => _GruposObrasWidgetState();
}

class _GruposObrasWidgetState extends State<GruposObrasWidget> {
  late GruposObrasModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  List<Map<String, dynamic>> _filteredAll = [];
  int _total = 0;
  int _page = 1;
  int _perPage = 10;
  String _sortOrder = 'asc';

  static const _debounceTag = 'grupos-obras-search';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => GruposObrasModel());
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Faça login para ver os grupos de obras.';
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
      await custom_actions.syncGruposObras();
    } catch (_) {}
    await _fetchGrupos();
  }

  Future<void> _syncAndReloadList() async {
    if (kIsWeb) return;
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;
    setState(() => _loading = true);
    try {
      await custom_actions.syncGruposObras();
    } catch (_) {}
    await _fetchGrupos();
  }

  Map<String, dynamic> _displayRow(
    Map<String, dynamic> row,
    int? serverId,
  ) {
    return {
      ...row,
      'id': serverId ?? 0,
    };
  }

  bool _rowMatchesSearch(Map<String, dynamic> m) {
    if (!_grupoAtivo(m)) return false;
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${m['nome'] ?? ''}'.toLowerCase().contains(q);
  }

  void _sortFiltered(List<Map<String, dynamic>> list) {
    final asc = _sortOrder == 'asc' ? 1 : -1;
    list.sort((a, b) => asc *
        '${a['nome'] ?? ''}'.toLowerCase().compareTo(
              '${b['nome'] ?? ''}'.toLowerCase(),
            ));
  }

  Future<void> _fetchGrupos() async {
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Faça login para ver os grupos de obras.';
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
        whereArgs: ['grupo_obra'],
      );
      final idByUuid = <String, int>{};
      for (final mr in mappingRows) {
        final u = mr['uuid']?.toString();
        final sid = mr['id_servidor'];
        if (u != null && u.isNotEmpty && sid is int) {
          idByUuid[u] = sid;
        }
      }

      final userUuid = FFAppState().creatorUuid;
      final rawAll = await db.query(
        'grupo_obra',
        where: 'user_uuid = ?',
        whereArgs: [userUuid],
      );

      final mapped = <Map<String, dynamic>>[];
      for (final r in rawAll) {
        final row = Map<String, dynamic>.from(r);
        final uuid = row['uuid']?.toString() ?? '';
        final serverId = idByUuid[uuid];
        mapped.add(_displayRow(row, serverId));
      }

      final filtered = mapped.where(_rowMatchesSearch).toList();
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
        _error = 'Erro ao ler grupos no SQLite: $e';
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
      await custom_actions.syncGruposObras();
    } catch (_) {}
    if (mounted) await _fetchGrupos();
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

    const keys = ['id', 'nome'];
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
        '${dir.path}/grupos_obras_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString('\uFEFF${buf.toString()}', encoding: utf8);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(path)],
        subject: 'Grupos de obras',
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
        _fetchGrupos();
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
            'Grupos de obras',
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
            'Novo grupo',
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
            child: Icon(Icons.folder_special_outlined,
                color: FlutterFlowTheme.of(context).primary, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Grupos de obras',
                  style: FlutterFlowTheme.of(context).headlineSmall.override(
                        font: GoogleFonts.interTight(fontWeight: FontWeight.bold),
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                ),
                Text(
                  'Cadastro (nome). Lista após sincronizar com o servidor.',
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
        side: BorderSide(color: FlutterFlowTheme.of(context).alternate),
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
                hintText: 'Buscar por nome...',
                prefixIcon: Icon(Icons.search,
                    color: FlutterFlowTheme.of(context).secondaryText),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Spacer(),
                IconButton(
                  tooltip: _sortOrder == 'asc' ? 'Nome A–Z' : 'Nome Z–A',
                  onPressed: () {
                    setState(() {
                      _sortOrder = _sortOrder == 'asc' ? 'desc' : 'asc';
                      _page = 1;
                    });
                    _fetchGrupos();
                  },
                  icon: Icon(
                    _sortOrder == 'asc'
                        ? Icons.arrow_downward
                        : Icons.arrow_upward,
                    color: FlutterFlowTheme.of(context).primary,
                  ),
                ),
                Chip(
                  label: Text(
                    '$_total ${_total == 1 ? 'grupo' : 'grupos'}',
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
              Icon(Icons.folder_off_outlined,
                  size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                'Nenhum grupo encontrado',
                style: FlutterFlowTheme.of(context).titleMedium,
              ),
              const SizedBox(height: 8),
              FFButtonWidget(
                onPressed: () => _openForm(context, null),
                text: 'Novo grupo',
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
                    DataColumn(label: Text('ID', style: _th(context))),
                    DataColumn(label: Text('Grupo de obra', style: _th(context))),
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

    return DataRow(
      cells: [
        DataCell(
          Text(
            idInt > 0 ? '$idInt' : '—',
            style: TextStyle(
              color: FlutterFlowTheme.of(context).secondaryText,
              fontSize: 13,
            ),
          ),
        ),
        DataCell(
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 280),
            child: Text(
              '${m['nome'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: FlutterFlowTheme.of(context).primary,
              ),
            ),
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
              IconButton(
                tooltip: 'Excluir',
                icon: Icon(Icons.delete_outline,
                    color: FlutterFlowTheme.of(context).error, size: 20),
                onPressed: () => _confirmDelete(context, idInt),
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
                _fetchGrupos();
              },
            ),
            const Spacer(),
            IconButton(
              onPressed: _page > 1
                  ? () {
                      setState(() => _page--);
                      _fetchGrupos();
                    }
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text('Página $_page / $lastPage'),
            IconButton(
              onPressed: _page < lastPage
                  ? () {
                      setState(() => _page++);
                      _fetchGrupos();
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
    final sid = m['id'];
    final sidInt = sid is int ? sid : int.tryParse('$sid') ?? 0;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${m['nome'] ?? 'Grupo'}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (sidInt > 0) Text('ID: $sidInt'),
            if ('${m['uuid'] ?? ''}'.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'UUID: ${m['uuid']}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
          ],
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

  Future<void> _openForm(BuildContext context, Map<String, dynamic>? existing) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GrupoNomeDialog(
        titulo: existing == null ? 'Novo grupo de obra' : 'Editar grupo de obra',
        nomeInicial: existing?['nome']?.toString() ?? '',
      ),
    );

    if (result == null || !mounted || !context.mounted) return;
    final nomeVal = result.trim();
    if (nomeVal.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe o nome do grupo.')),
      );
      return;
    }

    final body = <String, dynamic>{'nome': nomeVal};
    final token = FFAppState().UserToken.trim();
    if (token.isEmpty) return;

    if (existing == null) {
      final r = await GrupoObrasCreateCall.call(token: token, body: body);
      if (r.succeeded) {
        await _afterMutation('Grupo cadastrado.');
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
      final r = await GrupoObrasUpdateCall.call(token: token, id: idInt, body: body);
      if (r.succeeded) {
        await _afterMutation('Grupo atualizado.');
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
        title: const Text('Excluir grupo?'),
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
    final r = await GrupoObrasDeleteCall.call(token: token, id: id);
    if (r.succeeded) {
      await _afterMutation('Grupo excluído.');
    } else {
      _showApiError(r);
    }
  }
}

class _GrupoNomeDialog extends StatefulWidget {
  const _GrupoNomeDialog({
    required this.titulo,
    required this.nomeInicial,
  });

  final String titulo;
  final String nomeInicial;

  @override
  State<_GrupoNomeDialog> createState() => _GrupoNomeDialogState();
}

class _GrupoNomeDialogState extends State<_GrupoNomeDialog> {
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _nome,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Nome do grupo *',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) {
          FocusManager.instance.primaryFocus?.unfocus();
          Navigator.of(context).pop(_nome.text.trim());
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            FocusManager.instance.primaryFocus?.unfocus();
            Navigator.of(context).pop(_nome.text.trim());
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}

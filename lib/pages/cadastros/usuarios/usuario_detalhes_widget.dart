import '/backend/api_requests/api_calls.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// Detalhes do usuário — equivalente a `frontend/src/pages/usuarios/detalhes/[id].vue`.
/// Recebe [usuarioUuid] e chama a API (Bearer).
class UsuarioDetalhesWidget extends StatefulWidget {
  const UsuarioDetalhesWidget({
    super.key,
    this.usuarioUuid,
  });

  static String routeName = 'UsuarioDetalhes';
  static String routePath = '/usuarioDetalhes';

  final String? usuarioUuid;

  @override
  State<UsuarioDetalhesWidget> createState() => _UsuarioDetalhesWidgetState();
}

class _UsuarioDetalhesWidgetState extends State<UsuarioDetalhesWidget>
    with TickerProviderStateMixin {
  late TabController _tabController;

  int? _userId;
  String? _erroResolucao;

  bool _carregando = true;
  String? _erroGeral;

  Map<String, dynamic>? _usuario;
  List<Map<String, dynamic>> _obrasUsuario = [];
  List<Map<String, dynamic>> _obrasDisponiveis = [];

  bool _permissoesCarregando = false;
  bool _permissoesInicializadas = false;
  List<Map<String, dynamic>> _todasPermissoes = [];
  List<Map<String, dynamic>> _selectedPermissions = [];

  final TextEditingController _buscaPermissao = TextEditingController();

  bool _salvando = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _buscaPermissao.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _iniciar());
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging &&
        _tabController.index == 2 &&
        !_permissoesInicializadas &&
        _userId != null) {
      _carregarPermissoes();
    }
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _buscaPermissao.dispose();
    super.dispose();
  }

  Future<void> _iniciar() async {
    final uuid = widget.usuarioUuid?.trim();
    if (uuid == null || uuid.isEmpty) {
      setState(() {
        _erroResolucao = 'Usuário não informado.';
        _carregando = false;
      });
      return;
    }

    final token = FFAppState().UserToken;
    final rUser = await GetUsuarioShowCall.call(
      usuarioUuid: uuid,
      token: token,
    );
    if (!mounted) return;
    final usuario = rUser.succeeded && rUser.jsonBody is Map
        ? _asMap((rUser.jsonBody as Map)['value'])
        : null;
    final id = _intFrom(usuario?['id']);
    if (usuario == null || id == null) {
      setState(() {
        _erroResolucao = rUser.bodyText.isNotEmpty
            ? rUser.bodyText
            : 'Não foi possível identificar o usuário no servidor.';
        _carregando = false;
      });
      return;
    }

    setState(() {
      _userId = id;
      _usuario = usuario;
    });
    await _carregarDadosPrincipais();
  }

  Map<String, dynamic>? _asMap(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return null;
  }

  List<Map<String, dynamic>> _asMapList(dynamic v) {
    if (v is! List) return [];
    return v
        .map((e) =>
            e is Map ? Map<String, dynamic>.from(e) : <String, dynamic>{})
        .where((m) => m.isNotEmpty)
        .toList();
  }

  int? _intFrom(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  List<Map<String, dynamic>> _parseObrasIndex(dynamic jsonBody) {
    if (jsonBody is! Map) return [];
    final obras = jsonBody['obras'];
    if (obras is Map && obras['data'] is List) {
      return _asMapList(obras['data']);
    }
    return [];
  }

  List<Map<String, dynamic>> _parseObrasUsuario(dynamic jsonBody) {
    if (jsonBody is List) return _asMapList(jsonBody);
    if (jsonBody is Map) {
      final v = jsonBody['value'] ?? jsonBody['obras'] ?? jsonBody['data'];
      return _asMapList(v);
    }
    return [];
  }

  Future<void> _carregarDadosPrincipais() async {
    final id = _userId;
    if (id == null) return;
    final token = FFAppState().UserToken;

    setState(() {
      _carregando = true;
      _erroGeral = null;
    });

    try {
      final rUser = await GetUsuarioShowCall.call(id: id, token: token);
      if (!rUser.succeeded || rUser.jsonBody is! Map) {
        setState(() {
          _erroGeral = rUser.bodyText.isNotEmpty
              ? rUser.bodyText
              : 'Erro ao carregar usuário';
          _carregando = false;
        });
        return;
      }
      final u = _asMap((rUser.jsonBody as Map)['value']);
      final rObU = await GetUsuarioObrasVinculadasCall.call(
        usuarioId: id,
        token: token,
      );
      final rObAll = await ListarObrasResumoCall.call(token: token);

      if (!mounted) return;

      setState(() {
        _usuario = u;
        _obrasUsuario = _parseObrasUsuario(rObU.jsonBody);
        _obrasDisponiveis =
            rObAll.succeeded ? _parseObrasIndex(rObAll.jsonBody) : [];
        _carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _erroGeral = e.toString();
        _carregando = false;
      });
    }
  }

  Future<void> _carregarPermissoes() async {
    final id = _userId;
    if (id == null) return;
    final token = FFAppState().UserToken;

    setState(() {
      _permissoesCarregando = true;
    });

    try {
      final rAll = await GetUsersPermissoesListaCall.call(token: token);
      final rUsr =
          await GetUsersUsuarioPermissoesCall.call(userId: id, token: token);

      if (!mounted) return;

      List<Map<String, dynamic>> todas = [];
      if (rAll.succeeded && rAll.jsonBody is Map) {
        final v = (rAll.jsonBody as Map)['value'];
        todas = _asMapList(v is List ? v : null);
      }

      List<Map<String, dynamic>> doUsuario = [];
      if (rUsr.succeeded && rUsr.jsonBody is Map) {
        final val = (rUsr.jsonBody as Map)['value'];
        if (val is Map && val['permissoes'] != null) {
          doUsuario = _asMapList(val['permissoes']);
        }
      }

      setState(() {
        _todasPermissoes = todas;
        _selectedPermissions = List<Map<String, dynamic>>.from(doUsuario);
        _permissoesInicializadas = true;
        _permissoesCarregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _permissoesCarregando = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao carregar permissões: $e'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  bool _obraTravadaValor() {
    final v = _usuario?['obra_travada'];
    if (v == true || v == 1 || v == '1') return true;
    return false;
  }

  Future<void> _salvarObraTravada(bool value) async {
    final id = _userId;
    if (id == null || _usuario == null) return;
    setState(() => _salvando = true);
    final token = FFAppState().UserToken;
    final resp = await PutUsuarioObraTravadaCall.call(
      usuarioId: id,
      obraTravada: value,
      token: token,
    );
    if (!mounted) return;
    setState(() => _salvando = false);
    if (resp.succeeded) {
      setState(() {
        _usuario!['obra_travada'] = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Configuração salva'),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao salvar'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  int? _obraId(Map<String, dynamic> o) {
    final v = o['id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  List<Map<String, dynamic>> get _obrasNaoVinculadas {
    final ids = _obrasUsuario.map((o) => _obraId(o)).whereType<int>().toSet();
    return _obrasDisponiveis.where((o) {
      final id = _obraId(o);
      return id != null && !ids.contains(id);
    }).toList();
  }

  String _pivotPermissao(Map<String, dynamic> obra) {
    final p = obra['pivot'];
    if (p is Map && p['permissao'] != null) {
      return p['permissao'].toString();
    }
    return 'visualizar';
  }

  Future<void> _vincularObra(int? obraId, String permissao) async {
    final uid = _userId;
    if (uid == null || obraId == null) return;
    final token = FFAppState().UserToken;
    setState(() => _salvando = true);
    final resp = await PostUsuarioVincularObraCall.call(
      usuarioId: uid,
      obraId: obraId,
      permissao: permissao,
      token: token,
    );
    setState(() => _salvando = false);
    if (!mounted) return;
    if (resp.succeeded) {
      await _recarregarObrasUsuario();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Obra vinculada'),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao vincular'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _recarregarObrasUsuario() async {
    final id = _userId;
    if (id == null) return;
    final r = await GetUsuarioObrasVinculadasCall.call(
      usuarioId: id,
      token: FFAppState().UserToken,
    );
    if (!mounted) return;
    setState(() {
      _obrasUsuario = _parseObrasUsuario(r.jsonBody);
    });
  }

  Future<void> _desvincularObra(int obraId) async {
    final uid = _userId;
    if (uid == null) return;
    setState(() => _salvando = true);
    final resp = await DeleteUsuarioDesvincularObraCall.call(
      usuarioId: uid,
      obraId: obraId,
      token: FFAppState().UserToken,
    );
    setState(() => _salvando = false);
    if (!mounted) return;
    if (resp.succeeded) {
      await _recarregarObrasUsuario();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Obra desvinculada'),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  Future<void> _atualizarPermissaoObra(int obraId, String permissao) async {
    final uid = _userId;
    if (uid == null) return;
    setState(() => _salvando = true);
    final resp = await PutUsuarioAtualizarPermissaoObraCall.call(
      usuarioId: uid,
      obraId: obraId,
      permissao: permissao,
      token: FFAppState().UserToken,
    );
    setState(() => _salvando = false);
    if (!mounted) return;
    if (resp.succeeded) {
      await _recarregarObrasUsuario();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permissão atualizada'),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  int? _permId(Map<String, dynamic> p) {
    final v = p['id'];
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '');
  }

  bool _temPermissaoSelecionada(int id) {
    return _selectedPermissions.any((p) => _permId(p) == id);
  }

  void _togglePermissao(Map<String, dynamic> permission) {
    final id = _permId(permission);
    if (id == null) return;
    setState(() {
      if (_temPermissaoSelecionada(id)) {
        _selectedPermissions.removeWhere((p) => _permId(p) == id);
      } else {
        _selectedPermissions.add(Map<String, dynamic>.from(permission));
      }
    });
  }

  Future<void> _salvarPermissoes() async {
    final id = _userId;
    if (id == null) return;
    final ids =
        _selectedPermissions.map((p) => _permId(p)).whereType<int>().toList();
    setState(() => _salvando = true);
    final resp = await PutUsersSubstituirPermissoesCall.call(
      userId: id,
      permissionIds: ids,
      token: FFAppState().UserToken,
    );
    setState(() => _salvando = false);
    if (!mounted) return;
    if (resp.succeeded) {
      await _carregarPermissoes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Permissões salvas'),
          backgroundColor: FlutterFlowTheme.of(context).secondary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao salvar'),
          backgroundColor: FlutterFlowTheme.of(context).error,
        ),
      );
    }
  }

  void _resetPermissoes() {
    _carregarPermissoes();
  }

  List<Map<String, dynamic>> get _permissoesFiltradas {
    final q = _buscaPermissao.text.toLowerCase().trim();
    if (q.isEmpty) return _todasPermissoes;
    return _todasPermissoes.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final desc = (p['description'] ?? '').toString().toLowerCase();
      return name.contains(q) || desc.contains(q);
    }).toList();
  }

  /// Mesma ideia do computed `permissoesPorModulo` no Vue (segundo segmento após `_`).
  Map<String, List<Map<String, dynamic>>> get _permissoesPorModulo {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final permission in _permissoesFiltradas) {
      final name = (permission['name'] ?? '').toString();
      final parts = name.split('_');
      var modulo =
          parts.length > 1 ? parts[1] : (parts.isNotEmpty ? parts[0] : 'geral');
      if (modulo == 'ordens') modulo = 'ordens de serviço';
      if (modulo == 'modelos') modulo = 'modelos de relatórios';
      if (modulo == 'relatorios') modulo = 'relatórios';
      map.putIfAbsent(modulo, () => []).add(permission);
    }
    final keys = map.keys.toList()..sort();
    final sorted = <String, List<Map<String, dynamic>>>{};
    for (final k in keys) {
      sorted[k] = map[k]!;
    }
    return sorted;
  }

  String _formatPermissionLabel(Map<String, dynamic> permission) {
    final desc = permission['description']?.toString();
    if (desc != null && desc.trim().isNotEmpty) return desc;
    final name = (permission['name'] ?? '').toString();
    final parts = name.split('_');
    final action = parts.isNotEmpty ? parts[0] : '';
    final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    const actions = {
      'view': 'Visualizar',
      'create': 'Criar',
      'edit': 'Editar',
      'delete': 'Excluir',
      'approve': 'Aprovar',
      'export': 'Exportar',
      'print': 'Imprimir',
      'manage': 'Gerenciar',
      'complete': 'Concluir',
      'resolve': 'Resolver',
      'generate': 'Gerar',
    };
    final actionText = actions[action] ?? action;
    return '$actionText ${rest.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1) : ''}').join(' ')}'
        .trim();
  }

  String _formatTipo(dynamic t) {
    final s = t?.toString() ?? '';
    switch (s) {
      case 'operador':
        return 'Operador';
      case 'cliente':
        return 'Cliente';
      case 'supervisor':
        return 'Supervisor';
      case 'administrador':
        return 'Administrador';
      default:
        return s.isEmpty ? '—' : s;
    }
  }

  String _formatPermissaoObra(String? p) {
    switch (p) {
      case 'visualizar':
        return 'Visualizar';
      case 'editar':
        return 'Editar';
      case 'gerenciar':
        return 'Gerenciar';
      default:
        return p ?? '—';
    }
  }

  String _formatData(dynamic d) {
    if (d == null) return '—';
    try {
      final dt = DateTime.parse(d.toString());
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) {
      return d.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return Scaffold(
      backgroundColor: FlutterFlowTheme.of(context).primaryBackground,
      appBar: AppBar(
        backgroundColor: FlutterFlowTheme.of(context).primary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.safePop(),
        ),
        title: Text(
          'Detalhes do usuário',
          style: FlutterFlowTheme.of(context).titleLarge.override(
                font: GoogleFonts.interTight(fontWeight: FontWeight.w600),
                color: Colors.white,
                fontSize: 20.0,
              ),
        ),
        elevation: 0.0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_erroResolucao != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            _erroResolucao!,
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).bodyLarge,
          ),
        ),
      );
    }

    if (_carregando || _userId == null) {
      return Center(
        child: CircularProgressIndicator(
          color: FlutterFlowTheme.of(context).primary,
        ),
      );
    }

    if (_erroGeral != null) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Não foi possível carregar os dados.',
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).titleMedium,
            ),
            const SizedBox(height: 12),
            SelectableText(
              _erroGeral!,
              style: FlutterFlowTheme.of(context).bodySmall.override(
                    font: GoogleFonts.inter(),
                    color: FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 12,
                  ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: _carregarDadosPrincipais,
                child: const Text('Tentar novamente'),
              ),
            ),
          ],
        ),
      );
    }

    final u = _usuario;
    if (u == null) {
      return const Center(child: Text('Sem dados'));
    }

    final nome = '${u['nome'] ?? ''} ${u['sobrenome'] ?? ''}'.trim();
    final initials = _iniciais(u);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            clipBehavior: Clip.antiAlias,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: FlutterFlowTheme.of(context).primary,
                        radius: 28,
                        child: Text(
                          initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome.isEmpty ? '—' : nome,
                              style: FlutterFlowTheme.of(context).titleMedium,
                            ),
                            Text(
                              u['email']?.toString() ?? '',
                              style: FlutterFlowTheme.of(context)
                                  .bodySmall
                                  .override(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _chipInfo(
                        context,
                        'Tipo',
                        _formatTipo(u['type']),
                      ),
                      _chipInfo(
                        context,
                        'Status',
                        (u['situacao'] == 1 || u['situacao'] == true)
                            ? 'Ativo'
                            : 'Inativo',
                        positive: u['situacao'] == 1 || u['situacao'] == true,
                      ),
                      _chipInfo(
                        context,
                        'Cadastro',
                        _formatData(u['created_at']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Material(
          color: FlutterFlowTheme.of(context).secondaryBackground,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: FlutterFlowTheme.of(context).secondaryText,
            indicator: BoxDecoration(
              color: FlutterFlowTheme.of(context).primary,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(text: 'Dados básicos'),
              Tab(text: 'Vínculo com obras'),
              Tab(text: 'Permissões'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _tabDadosBasicos(u),
              _tabObras(u),
              _tabPermissoes(),
            ],
          ),
        ),
      ],
    );
  }

  String _iniciais(Map<String, dynamic> u) {
    final a = (u['nome']?.toString().trim() ?? '');
    final b = (u['sobrenome']?.toString().trim() ?? '');
    final s =
        '${a.isNotEmpty ? a[0] : ''}${b.isNotEmpty ? b[0] : ''}'.toUpperCase();
    return s.isEmpty ? 'U' : s;
  }

  Widget _chipInfo(
    BuildContext context,
    String label,
    String value, {
    bool positive = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: FlutterFlowTheme.of(context).labelSmall.override(
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: positive
                ? FlutterFlowTheme.of(context).secondary
                : FlutterFlowTheme.of(context).alternate,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: FlutterFlowTheme.of(context).bodySmall.override(
                  color: positive
                      ? FlutterFlowTheme.of(context).primaryBackground
                      : FlutterFlowTheme.of(context).primaryText,
                ),
          ),
        ),
      ],
    );
  }

  Widget _tabDadosBasicos(Map<String, dynamic> u) {
    final jur = u['juridica'] == true || u['juridica'] == 1;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Informações pessoais',
          style: FlutterFlowTheme.of(context).titleMedium,
        ),
        const SizedBox(height: 12),
        _readonlyField('Nome', u['nome']?.toString()),
        _readonlyField('Sobrenome', u['sobrenome']?.toString()),
        _readonlyField('E-mail', u['email']?.toString()),
        _readonlyField(
          'Telefone',
          (u['telefone'] ?? u['whatsapp'])?.toString(),
        ),
        _readonlyField('Cargo', u['cargo']?.toString()),
        _readonlyField(
            'Registro profissional', u['registro_profissional']?.toString()),
        _readonlyField(
          jur ? 'CNPJ' : 'CPF',
          u['documento']?.toString(),
        ),
        if (jur) _readonlyField('Razão social', u['razao_social']?.toString()),
      ],
    );
  }

  Widget _readonlyField(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: TextFormField(
        initialValue: value ?? '',
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          filled: true,
          fillColor: FlutterFlowTheme.of(context).secondaryBackground,
        ),
      ),
    );
  }

  Widget _tabObras(Map<String, dynamic> u) {
    final tipo = u['type']?.toString() ?? '';
    final travada = _obraTravadaValor();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Configuração de acesso',
          style: FlutterFlowTheme.of(context).titleMedium,
        ),
        SwitchListTile(
          title: Text(
            travada
                ? 'Acesso restrito a obras vinculadas'
                : 'Acesso livre às obras',
          ),
          value: travada,
          onChanged: _salvando ? null : (v) => _salvarObraTravada(v),
        ),
        Text(
          travada
              ? 'Usuário só verá obras vinculadas abaixo.'
              : 'Usuário verá todas as obras conforme regras do sistema.',
          style: FlutterFlowTheme.of(context).bodySmall.override(
                color: FlutterFlowTheme.of(context).secondaryText,
              ),
        ),
        if (tipo == 'cliente')
          _alertInfo(context,
              'Cliente: recomendado manter acesso restrito e vincular só obras dele.'),
        if (tipo == 'operador')
          _alertInfo(context, 'Operador: vincule apenas obras necessárias.'),
        if (tipo == 'supervisor')
          _alertInfo(
              context, 'Supervisor: pode ter várias obras para supervisão.'),
        const SizedBox(height: 16),
        if (travada) ...[
          _VinculoObraSection(
            obrasNaoVinculadas: _obrasNaoVinculadas,
            obrasUsuario: _obrasUsuario,
            salvando: _salvando,
            onVincular: _vincularObra,
            onDesvincular: _desvincularObra,
            onPermissaoObra: _atualizarPermissaoObra,
            pivotPermissao: _pivotPermissao,
            formatPerm: _formatPermissaoObra,
            obraId: _obraId,
          ),
        ] else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Todas as obras estão permitidas para este usuário (acesso livre).',
                style: FlutterFlowTheme.of(context).bodyMedium,
              ),
            ),
          ),
      ],
    );
  }

  Widget _alertInfo(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).accent4,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: FlutterFlowTheme.of(context).bodySmall),
      ),
    );
  }

  Widget _tabPermissoes() {
    if (_permissoesCarregando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (!_permissoesInicializadas) {
      return Center(
        child: TextButton(
          onPressed: _carregarPermissoes,
          child: const Text('Carregar permissões'),
        ),
      );
    }

    final grupos = _permissoesPorModulo;
    final count = _selectedPermissions.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscaPermissao,
                  decoration: InputDecoration(
                    labelText: 'Buscar permissão',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('$count selecionadas',
                  style: FlutterFlowTheme.of(context).labelLarge),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: [
              ...grupos.entries.map((e) {
                final modulo = e.key;
                final lista = e.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ExpansionTile(
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            modulo,
                            style: FlutterFlowTheme.of(context).titleSmall,
                          ),
                        ),
                        Chip(
                          label: Text('${lista.length}'),
                          visualDensity: VisualDensity.compact,
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                        child: Column(
                          children: lista.map((perm) {
                            final id = _permId(perm);
                            if (id == null) return const SizedBox.shrink();
                            final sel = _temPermissaoSelecionada(id);
                            return CheckboxListTile(
                              dense: true,
                              value: sel,
                              onChanged: (_) => _togglePermissao(perm),
                              title: Text(
                                _formatPermissionLabel(perm),
                                style: FlutterFlowTheme.of(context).bodySmall,
                              ),
                              controlAffinity: ListTileControlAffinity.leading,
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _salvando ? null : _resetPermissoes,
                child: const Text('Resetar'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _salvando ? null : _salvarPermissoes,
                child: _salvando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salvar permissões'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VinculoObraSection extends StatefulWidget {
  const _VinculoObraSection({
    required this.obrasNaoVinculadas,
    required this.obrasUsuario,
    required this.salvando,
    required this.onVincular,
    required this.onDesvincular,
    required this.onPermissaoObra,
    required this.pivotPermissao,
    required this.formatPerm,
    required this.obraId,
  });

  final List<Map<String, dynamic>> obrasNaoVinculadas;
  final List<Map<String, dynamic>> obrasUsuario;
  final bool salvando;
  final Future<void> Function(int? obraId, String permissao) onVincular;
  final Future<void> Function(int obraId) onDesvincular;
  final Future<void> Function(int obraId, String permissao) onPermissaoObra;
  final String Function(Map<String, dynamic> obra) pivotPermissao;
  final String Function(String? p) formatPerm;
  final int? Function(Map<String, dynamic> o) obraId;

  @override
  State<_VinculoObraSection> createState() => _VinculoObraSectionState();
}

class _VinculoObraSectionState extends State<_VinculoObraSection> {
  int? _novaObraId;
  String _novaPermissao = 'visualizar';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Obras vinculadas',
          style: FlutterFlowTheme.of(context).titleMedium,
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              flex: 2,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Vincular obra',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _novaObraId,
                    hint: const Text('Selecione'),
                    items: widget.obrasNaoVinculadas.map((o) {
                      final id = widget.obraId(o);
                      final nome = o['nome']?.toString() ?? '#$id';
                      return DropdownMenuItem(
                        value: id,
                        child: Text(nome, overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: widget.salvando
                        ? null
                        : (v) => setState(() => _novaObraId = v),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Permissão',
                  border: OutlineInputBorder(),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _novaPermissao,
                    items: const [
                      DropdownMenuItem(
                          value: 'visualizar', child: Text('Visualizar')),
                      DropdownMenuItem(value: 'editar', child: Text('Editar')),
                      DropdownMenuItem(
                          value: 'gerenciar', child: Text('Gerenciar')),
                    ],
                    onChanged: widget.salvando
                        ? null
                        : (v) =>
                            setState(() => _novaPermissao = v ?? 'visualizar'),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: widget.salvando || _novaObraId == null
                  ? null
                  : () async {
                      await widget.onVincular(_novaObraId, _novaPermissao);
                      if (mounted) setState(() => _novaObraId = null);
                    },
              child: const Text('Vincular'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (widget.obrasUsuario.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).accent4,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Nenhuma obra vinculada.'),
          )
        else
          ...widget.obrasUsuario.map((obra) {
            final oid = widget.obraId(obra);
            if (oid == null) return const SizedBox.shrink();
            final nome = obra['nome']?.toString() ?? 'Obra';
            final perm = widget.pivotPermissao(obra);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: Icon(Icons.business,
                    color: FlutterFlowTheme.of(context).primary),
                title: Text(nome),
                subtitle: Text('Permissão: ${widget.formatPerm(perm)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButton<String>(
                      value: perm,
                      items: const [
                        DropdownMenuItem(
                            value: 'visualizar', child: Text('Visualizar')),
                        DropdownMenuItem(
                            value: 'editar', child: Text('Editar')),
                        DropdownMenuItem(
                            value: 'gerenciar', child: Text('Gerenciar')),
                      ],
                      onChanged: widget.salvando
                          ? null
                          : (v) {
                              if (v != null && v != perm) {
                                widget.onPermissaoObra(oid, v);
                              }
                            },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: widget.salvando
                          ? null
                          : () => widget.onDesvincular(oid),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

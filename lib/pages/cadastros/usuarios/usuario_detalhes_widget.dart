import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/pages/cadastros/cadastrar_usuario/cadastrar_usuario_widget.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_usuarios')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar usuários.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
        return;
      }
      _iniciar();
    });
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
    if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }
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
    if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }
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
    if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }
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
    if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }
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
    if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }
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
    if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }
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

  String _formatDocumento(String? doc, bool juridica) {
    if (doc == null || doc.trim().isEmpty) return 'Não informado';
    final d = doc.replaceAll(RegExp(r'\D'), '');
    if (juridica) {
      if (d.length != 14) return doc;
      return '${d.substring(0, 2)}.${d.substring(2, 5)}.${d.substring(5, 8)}/${d.substring(8, 12)}-${d.substring(12)}';
    }
    if (d.length != 11) return doc;
    return '${d.substring(0, 3)}.${d.substring(3, 6)}.${d.substring(6, 9)}-${d.substring(9)}';
  }

  String _formatTelefone(String? tel) {
    if (tel == null || tel.trim().isEmpty) return 'Não informado';
    final t = tel.replaceAll(RegExp(r'\D'), '');
    if (t.length == 11) {
      return '(${t.substring(0, 2)}) ${t.substring(2, 7)}-${t.substring(7)}';
    }
    if (t.length == 10) {
      return '(${t.substring(0, 2)}) ${t.substring(2, 6)}-${t.substring(6)}';
    }
    return tel;
  }

  String _txt(dynamic v, [String empty = 'Não informado']) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? empty : s;
  }

  String _nomeCompleto(Map<String, dynamic> u) {
    final nome = '${u['nome'] ?? ''} ${u['sobrenome'] ?? ''}'.trim();
    return nome.isEmpty ? 'Usuário' : nome;
  }

  String _iniciais(Map<String, dynamic> u) {
    final a = (u['nome']?.toString().trim() ?? '');
    final b = (u['sobrenome']?.toString().trim() ?? '');
    final s =
        '${a.isNotEmpty ? a[0] : ''}${b.isNotEmpty ? b[0] : ''}'.toUpperCase();
    return s.isEmpty ? 'U' : s;
  }

  bool _usuarioAtivo(Map<String, dynamic> u) {
    final sit = u['situacao'];
    return sit == null || sit == 1 || sit == true;
  }

  void _abrirEditar() {
    if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }
    final uuid = widget.usuarioUuid?.trim() ??
        _usuario?['uuid']?.toString().trim() ??
        '';
    if (uuid.isEmpty) return;
    context
        .pushNamed(
      CadastrarUsuarioWidget.routeName,
      queryParameters: {
        'usuarioUuid': serializeParam(uuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        kTransitionInfoKey: const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    )
        .then((_) {
      if (mounted) _carregarDadosPrincipais();
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final canEdit = MembershipAccess.canPermission('edit_usuarios');
    final nome = _usuario == null ? '' : _nomeCompleto(_usuario!);

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
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
                  'Detalhes do usuário',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  nome.isEmpty ? 'Acesso e permissões' : nome,
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
              tooltip: 'Atualizar',
              icon: const Icon(Icons.refresh_rounded,
                  color: Colors.white, size: 21),
              onPressed: _carregando ? null : _carregarDadosPrincipais,
            ),
            if (canEdit && _usuario != null)
              IconButton(
                tooltip: 'Editar',
                icon: const Icon(Icons.edit_outlined,
                    color: Colors.white, size: 21),
                onPressed: _abrirEditar,
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _buildBody(theme, canEdit)),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(FlutterFlowTheme theme, bool canEdit) {
    if (_erroResolucao != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 48,
                  color: theme.secondaryText.withValues(alpha: 0.5)),
              const SizedBox(height: 12),
              Text(
                _erroResolucao!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: theme.secondaryText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_carregando || _userId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: theme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Carregando dados do usuário…',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: theme.secondaryText,
              ),
            ),
          ],
        ),
      );
    }

    if (_erroGeral != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: theme.error),
              const SizedBox(height: 12),
              Text(
                'Não foi possível carregar os dados.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.primaryText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _erroGeral!,
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: theme.secondaryText,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _carregarDadosPrincipais,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Tentar novamente'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(180, 42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final u = _usuario;
    if (u == null) {
      return Center(
        child: Text(
          'Sem dados',
          style: GoogleFonts.inter(color: theme.secondaryText),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: NestedScrollView(
            headerSliverBuilder: (context, _) => [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Column(
                    children: [
                      _buildResumoCard(theme, u),
                      if (canEdit) ...[
                        const SizedBox(height: 10),
                        RdoSectionCard(
                          title: 'Ações',
                          icon: Icons.tune_rounded,
                          margin: EdgeInsets.zero,
                          child: FilledButton.icon(
                            onPressed: _abrirEditar,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            label: Text(
                              'Editar usuário',
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
                      ],
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _RdoTabBarDelegate(
                  theme: theme,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: Colors.white,
                    unselectedLabelColor: theme.secondaryText,
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                    unselectedLabelStyle: GoogleFonts.inter(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                    indicator: BoxDecoration(
                      color: theme.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Dados'),
                      Tab(text: 'Obras'),
                      Tab(text: 'Permissões'),
                    ],
                  ),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _tabDadosBasicos(theme, u),
                _tabObras(theme, u, canEdit),
                _tabPermissoes(theme, canEdit),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumoCard(FlutterFlowTheme theme, Map<String, dynamic> u) {
    final ativo = _usuarioAtivo(u);
    final statusColor =
        ativo ? Colors.green.shade700 : Colors.grey.shade700;

    return RdoSectionCard(
      title: 'Resumo',
      icon: Icons.manage_accounts_outlined,
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: theme.primary.withValues(alpha: 0.12),
            child: Text(
              _iniciais(u),
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.primary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nomeCompleto(u),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _txt(u['email']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: theme.secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _miniChip(theme, _formatTipo(u['type']), theme.primary),
                    _miniChip(
                      theme,
                      ativo ? 'Ativo' : 'Inativo',
                      statusColor,
                    ),
                    _miniChip(
                      theme,
                      'Desde ${_formatData(u['created_at'])}',
                      theme.secondaryText,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(FlutterFlowTheme theme, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _tabDadosBasicos(FlutterFlowTheme theme, Map<String, dynamic> u) {
    final jur = u['juridica'] == true || u['juridica'] == 1;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        RdoSectionCard(
          title: 'Informações pessoais',
          icon: Icons.badge_outlined,
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (jur) ...[
                _infoRow(theme, 'Razão social', _txt(u['nome'])),
                _infoRow(
                  theme,
                  'CNPJ',
                  _formatDocumento(u['documento']?.toString(), true),
                ),
              ] else ...[
                _infoRow(theme, 'Nome', _txt(u['nome'])),
                _infoRow(theme, 'Sobrenome', _txt(u['sobrenome'])),
                _infoRow(
                  theme,
                  'CPF',
                  _formatDocumento(u['documento']?.toString(), false),
                ),
              ],
              _infoRow(theme, 'E-mail', _txt(u['email'])),
              _infoRow(
                theme,
                'Telefone',
                _formatTelefone(
                  (u['telefone'] ?? u['whatsapp'])?.toString(),
                ),
              ),
              _infoRow(theme, 'Cargo', _txt(u['cargo'])),
              _infoRow(
                theme,
                'Registro',
                _txt(u['registro_profissional']),
              ),
              _infoRow(theme, 'Tipo', _formatTipo(u['type'])),
              _infoRow(
                theme,
                'Status',
                _usuarioAtivo(u) ? 'Ativo' : 'Inativo',
              ),
              _infoRow(theme, 'Cadastro', _formatData(u['created_at'])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tabObras(
    FlutterFlowTheme theme,
    Map<String, dynamic> u,
    bool canEdit,
  ) {
    final tipo = u['type']?.toString() ?? '';
    final travada = _obraTravadaValor();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      children: [
        RdoSectionCard(
          title: 'Configuração de acesso',
          icon: Icons.lock_outline_rounded,
          subtitle: travada
              ? 'Acesso restrito a obras vinculadas'
              : 'Acesso livre às obras',
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  travada
                      ? 'Acesso restrito a obras vinculadas'
                      : 'Acesso livre às obras',
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: theme.primaryText,
                  ),
                ),
                subtitle: Text(
                  travada
                      ? 'Usuário só verá obras vinculadas abaixo.'
                      : 'Usuário verá todas as obras conforme regras do sistema.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: theme.secondaryText,
                  ),
                ),
                value: travada,
                activeThumbColor: theme.primary,
                onChanged: (!canEdit || _salvando)
                    ? null
                    : (v) => _salvarObraTravada(v),
              ),
              if (tipo == 'cliente')
                _alertInfo(
                  theme,
                  'Cliente: recomendado manter acesso restrito e vincular só obras dele.',
                ),
              if (tipo == 'operador')
                _alertInfo(
                  theme,
                  'Operador: vincule apenas obras necessárias.',
                ),
              if (tipo == 'supervisor')
                _alertInfo(
                  theme,
                  'Supervisor: pode ter várias obras para supervisão.',
                ),
            ],
          ),
        ),
        if (travada)
          RdoSectionCard(
            title: 'Obras vinculadas',
            icon: Icons.apartment_outlined,
            subtitle: '${_obrasUsuario.length} vínculo(s)',
            trailing: _obrasUsuario.isEmpty
                ? null
                : RdoContadorChip('${_obrasUsuario.length}'),
            margin: EdgeInsets.zero,
            child: _VinculoObraSection(
              obrasNaoVinculadas: _obrasNaoVinculadas,
              obrasUsuario: _obrasUsuario,
              salvando: _salvando || !canEdit,
              onVincular: _vincularObra,
              onDesvincular: _desvincularObra,
              onPermissaoObra: _atualizarPermissaoObra,
              pivotPermissao: _pivotPermissao,
              formatPerm: _formatPermissaoObra,
              obraId: _obraId,
            ),
          )
        else
          RdoSectionCard(
            title: 'Obras',
            icon: Icons.apartment_outlined,
            margin: EdgeInsets.zero,
            child: Text(
              'Todas as obras estão permitidas para este usuário (acesso livre).',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          ),
      ],
    );
  }

  Widget _alertInfo(FlutterFlowTheme theme, String text) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: theme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tabPermissoes(FlutterFlowTheme theme, bool canEdit) {
    if (_permissoesCarregando) {
      return Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: theme.primary,
          ),
        ),
      );
    }

    if (!_permissoesInicializadas) {
      return Center(
        child: FilledButton.icon(
          onPressed: _carregarPermissoes,
          icon: const Icon(Icons.security_rounded, size: 18),
          label: const Text('Carregar permissões'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.primary,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    final grupos = _permissoesPorModulo;
    final count = _selectedPermissions.length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: RdoSectionCard(
            title: 'Buscar permissões',
            icon: Icons.search_rounded,
            trailing: RdoContadorChip('$count'),
            margin: EdgeInsets.zero,
            child: TextField(
              controller: _buscaPermissao,
              style: rdoFormFieldTextStyle(context),
              decoration: rdoFormFieldDecoration(
                context,
                label: 'Nome ou descrição',
                hint: 'Digite para filtrar',
                suffixIcon: _buscaPermissao.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar',
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.secondaryText,
                        ),
                        onPressed: () {
                          _buscaPermissao.clear();
                          setState(() {});
                        },
                      ),
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            children: [
              if (grupos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Nenhuma permissão encontrada.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: theme.secondaryText,
                    ),
                  ),
                )
              else
                ...grupos.entries.map((e) {
                  final modulo = e.key;
                  final lista = e.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: RdoSectionCard(
                      title: modulo,
                      icon: Icons.folder_open_outlined,
                      trailing: RdoContadorChip('${lista.length}'),
                      margin: EdgeInsets.zero,
                      contentPadding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < lista.length; i++) ...[
                            if (i > 0)
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: theme.alternate),
                            Builder(
                              builder: (context) {
                                final perm = lista[i];
                                final id = _permId(perm);
                                if (id == null) {
                                  return const SizedBox.shrink();
                                }
                                final sel = _temPermissaoSelecionada(id);
                                return CheckboxListTile(
                                  dense: true,
                                  value: sel,
                                  onChanged: canEdit
                                      ? (_) => _togglePermissao(perm)
                                      : null,
                                  title: Text(
                                    _formatPermissionLabel(perm),
                                    style: GoogleFonts.inter(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: theme.primaryText,
                                    ),
                                  ),
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: theme.primary,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        ),
        if (canEdit)
          Material(
            color: theme.secondaryBackground,
            elevation: 6,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            child: SafeArea(
              top: false,
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _salvando ? null : _resetPermissoes,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.primaryText,
                          side: BorderSide(color: theme.alternate),
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Resetar',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: _salvando ? null : _salvarPermissoes,
                        icon: _salvando
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          _salvando ? 'Salvando…' : 'Salvar permissões',
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: theme.primary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(0, 44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _infoRow(FlutterFlowTheme theme, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RdoTabBarDelegate extends SliverPersistentHeaderDelegate {
  _RdoTabBarDelegate({required this.theme, required this.child});

  final FlutterFlowTheme theme;
  final Widget child;

  @override
  double get minExtent => 52;

  @override
  double get maxExtent => 52;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      color: theme.secondaryBackground,
      elevation: overlapsContent ? 1 : 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _RdoTabBarDelegate oldDelegate) =>
      theme != oldDelegate.theme || child != oldDelegate.child;
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
    final theme = FlutterFlowTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('obra-$_novaObraId'),
          initialValue: _novaObraId,
          isExpanded: true,
          decoration: rdoFormFieldDecoration(
            context,
            label: 'Vincular obra',
            hint: 'Selecione',
          ),
          style: rdoFormFieldTextStyle(context),
          items: [
            for (final o in widget.obrasNaoVinculadas)
              DropdownMenuItem(
                value: widget.obraId(o),
                child: Text(
                  o['nome']?.toString() ?? '#${widget.obraId(o)}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
          onChanged: widget.salvando
              ? null
              : (v) => setState(() => _novaObraId = v),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                key: ValueKey('perm-$_novaPermissao'),
                initialValue: _novaPermissao,
                isExpanded: true,
                decoration: rdoFormFieldDecoration(
                  context,
                  label: 'Permissão',
                ),
                style: rdoFormFieldTextStyle(context),
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
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: widget.salvando || _novaObraId == null
                  ? null
                  : () async {
                      await widget.onVincular(_novaObraId, _novaPermissao);
                      if (mounted) setState(() => _novaObraId = null);
                    },
              icon: const Icon(Icons.link_rounded, size: 18),
              label: Text(
                'Vincular',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: theme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (widget.obrasUsuario.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Nenhuma obra vinculada.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: theme.secondaryText,
              ),
            ),
          )
        else
          for (var i = 0; i < widget.obrasUsuario.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: theme.alternate),
            Builder(
              builder: (context) {
                final obra = widget.obrasUsuario[i];
                final oid = widget.obraId(obra);
                if (oid == null) return const SizedBox.shrink();
                final nome = obra['nome']?.toString() ?? 'Obra';
                final perm = widget.pivotPermissao(obra);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
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
                          Icons.apartment_rounded,
                          size: 18,
                          color: theme.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nome,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Permissão: ${widget.formatPerm(perm)}',
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DropdownButton<String>(
                        value: perm,
                        underline: const SizedBox.shrink(),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: theme.primaryText,
                        ),
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
                        tooltip: 'Desvincular',
                        onPressed: widget.salvando
                            ? null
                            : () => widget.onDesvincular(oid),
                        icon: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
      ],
    );
  }
}

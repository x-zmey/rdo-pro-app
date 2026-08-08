import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'usuarios_model.dart';
export 'usuarios_model.dart';

/// Lista de usuários com cadastro, edição, detalhes e exclusão via API.
class UsuariosWidget extends StatefulWidget {
  const UsuariosWidget({super.key});

  static String routeName = 'Usuarios';
  static String routePath = '/usuarios';

  @override
  State<UsuariosWidget> createState() => _UsuariosWidgetState();
}

class _UsuariosWidgetState extends State<UsuariosWidget> {
  late UsuariosModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _buscaController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _usuariosFuture;
  List<Map<String, dynamic>> _usuarios = [];
  bool _isLoading = true;
  String? _error;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => UsuariosModel());
    _usuariosFuture = _fetchUsuariosApi();
    _carregar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_usuarios')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar usuários.',
        );
        if (context.mounted && context.canPop()) {
          context.pop();
        }
      }
    });
  }

  @override
  void dispose() {
    _buscaController.dispose();
    _model.dispose();
    super.dispose();
  }

  String _formatarTipo(String? type) {
    switch (type) {
      case 'administrador':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'operador':
        return 'Operador';
      case 'cliente':
        return 'Cliente';
      default:
        return type ?? '—';
    }
  }

  String _rotuloStatus(int? situacao) {
    if (situacao == null || situacao == 1) return 'Ativo';
    if (situacao == 0) return 'Inativo';
    return '—';
  }

  bool _usuarioAtivo(int? situacao) => situacao == null || situacao == 1;

  List<Map<String, dynamic>> _extractUsuarios(dynamic body) {
    final rawValue = body is Map ? body['value'] : null;
    final rawUsers = rawValue is Map ? rawValue['users'] : rawValue;
    if (rawUsers is! List) return [];
    return rawUsers
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchUsuariosApi() async {
    final resp = await ListarUsuariosApiCall.call(
      token: FFAppState().UserToken,
    );
    if (!resp.succeeded) {
      throw Exception(
        resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao carregar usuários',
      );
    }
    return _extractUsuarios(resp.jsonBody);
  }

  Future<void> _carregar() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _usuariosFuture = _fetchUsuariosApi();
    });
    try {
      final list = await _usuariosFuture;
      if (!mounted) return;
      setState(() {
        _usuarios = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int? _intFrom(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  String? _usuarioUuid(Map<String, dynamic> usuario) {
    final uuid = usuario['uuid']?.toString().trim();
    return uuid != null && uuid.isNotEmpty ? uuid : null;
  }

  String? _identificador(Map<String, dynamic> usuario) {
    final uuid = _usuarioUuid(usuario);
    if (uuid != null) return uuid;
    final id = _intFrom(usuario['id']);
    return id?.toString();
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _busca.trim().toLowerCase();
    if (q.isEmpty) return _usuarios;
    return _usuarios.where((u) {
      final nome = (u['nome']?.toString() ?? '').toLowerCase();
      final email = (u['email']?.toString() ?? '').toLowerCase();
      final cargo = (u['cargo']?.toString() ?? '').toLowerCase();
      final tipo = _formatarTipo(u['type']?.toString()).toLowerCase();
      return nome.contains(q) ||
          email.contains(q) ||
          cargo.contains(q) ||
          tipo.contains(q);
    }).toList();
  }

  String _iniciais(String nome) {
    final partes = nome.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty || partes.first.isEmpty) return '?';
    if (partes.length == 1) {
      return partes.first.length >= 2
          ? partes.first.substring(0, 2).toUpperCase()
          : partes.first[0].toUpperCase();
    }
    final a = partes.first[0];
    final b = partes.last.isNotEmpty ? partes.last[0] : '';
    return ('$a$b').toUpperCase();
  }

  void _abrirCadastro({String? usuarioUuid}) {
    if (usuarioUuid == null || usuarioUuid.isEmpty) {
      if (!MembershipAccess.canPermission('create_usuarios')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para criar usuários.',
        );
        return;
      }
    } else if (!MembershipAccess.canPermission('edit_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar usuários.',
      );
      return;
    }

    context
        .pushNamed(
      CadastrarUsuarioWidget.routeName,
      queryParameters: {
        'usuarioUuid': serializeParam(usuarioUuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        kTransitionInfoKey: const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    )
        .then((_) {
      if (mounted) _carregar();
    });
  }

  Future<void> _abrirDetalhes(Map<String, dynamic> usuario) async {
    final identificador = _identificador(usuario);
    if (identificador == null) return;

    await context.pushNamed(
      UsuarioDetalhesWidget.routeName,
      queryParameters: {
        'usuarioUuid': serializeParam(identificador, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        kTransitionInfoKey: const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    );
    if (mounted) _carregar();
  }

  Future<void> _confirmarExcluir(Map<String, dynamic> usuario) async {
    if (!MembershipAccess.canPermission('delete_usuarios')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir usuários.',
      );
      return;
    }

    final uuid = _usuarioUuid(usuario);
    final meuUsuario =
        uuid != null && uuid == FFAppState().UserUuid.trim();
    if (meuUsuario) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você não pode apagar o próprio usuário.'),
        ),
      );
      return;
    }

    final theme = FlutterFlowTheme.of(context);
    final nome =
        valueOrDefault<String>(usuario['nome']?.toString(), 'Usuário');
    final idServidor = _intFrom(usuario['id']);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Apagar usuário',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        content: Text(
          'Deseja apagar o usuário "$nome"? Ele deixará de aparecer na lista.',
          style: GoogleFonts.inter(fontSize: 13.5, color: theme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancelar',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                color: theme.secondaryText,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: theme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    final resp = await ExcluirUsuarioCall.call(
      id: idServidor,
      usuarioUuid: uuid ?? '',
      token: FFAppState().UserToken,
    );
    if (!mounted) return;

    if (resp.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Usuário apagado'),
          backgroundColor: theme.secondary,
        ),
      );
      await _carregar();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            resp.bodyText.isNotEmpty
                ? resp.bodyText
                : 'Erro ao apagar usuário',
          ),
          backgroundColor: theme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);
    final canCreate = MembershipAccess.canPermission('create_usuarios');
    final filtrados = _filtrados;

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
                  'Usuários',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Acesso e permissões do sistema',
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
              onPressed: _isLoading ? null : _carregar,
            ),
            if (canCreate)
              IconButton(
                tooltip: 'Novo usuário',
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 24),
                onPressed: () => _abrirCadastro(),
              ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                color: theme.primary,
                onRefresh: _carregar,
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
                        title: 'Incluir usuário',
                        icon: Icons.person_add_alt_1_outlined,
                        subtitle: 'Cadastrar novo acesso',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: () => _abrirCadastro(),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: Text(
                            'Novo usuário',
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
                      title: 'Buscar',
                      icon: Icons.search_rounded,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: TextField(
                        controller: _buscaController,
                        onChanged: (v) => setState(() => _busca = v),
                        style: rdoFormFieldTextStyle(context),
                        decoration: rdoFormFieldDecoration(
                          context,
                          label: 'Nome, e-mail, cargo ou tipo',
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
                                    _buscaController.clear();
                                    setState(() => _busca = '');
                                  },
                                ),
                        ),
                      ),
                    ),
                    RdoSectionCard(
                      title: 'Lista de usuários',
                      icon: Icons.manage_accounts_outlined,
                      subtitle: _isLoading
                          ? 'Carregando…'
                          : filtrados.isEmpty
                              ? 'Nenhum usuário encontrado'
                              : _busca.trim().isEmpty
                                  ? 'Toque para ver detalhes'
                                  : '${filtrados.length} de ${_usuarios.length}',
                      margin: EdgeInsets.zero,
                      trailing: filtrados.isEmpty
                          ? null
                          : RdoContadorChip('${filtrados.length}'),
                      contentPadding: EdgeInsets.zero,
                      child: _buildLista(theme, filtrados, canCreate),
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
    List<Map<String, dynamic>> filtrados,
    bool canCreate,
  ) {
    if (_isLoading && _usuarios.isEmpty) {
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

    if (_error != null && _usuarios.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: theme.error),
            const SizedBox(height: 12),
            Text(
              'Erro ao carregar usuários',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _error!,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: theme.secondaryText,
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _carregar,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tentar novamente'),
            ),
          ],
        ),
      );
    }

    if (filtrados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
        child: Column(
          children: [
            Icon(
              Icons.person_off_outlined,
              size: 40,
              color: theme.secondaryText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _usuarios.isEmpty
                  ? 'Nenhum usuário cadastrado'
                  : 'Nenhum resultado na busca',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _usuarios.isEmpty
                  ? (canCreate
                      ? 'Cadastre o primeiro usuário para começar.'
                      : 'Não há usuários disponíveis.')
                  : 'Tente outro termo de busca.',
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
        for (var i = 0; i < filtrados.length; i++) ...[
          if (i > 0)
            Divider(height: 1, thickness: 1, color: theme.alternate),
          _buildUsuarioItem(theme, filtrados[i]),
        ],
      ],
    );
  }

  Widget _buildUsuarioItem(
    FlutterFlowTheme theme,
    Map<String, dynamic> usuario,
  ) {
    final nome = valueOrDefault<String>(
        usuario['nome']?.toString(), 'Usuário sem nome');
    final email =
        valueOrDefault<String>(usuario['email']?.toString(), 'Sem e-mail');
    final cargo =
        valueOrDefault<String>(usuario['cargo']?.toString(), 'Sem cargo');
    final tipo = _formatarTipo(usuario['type']?.toString());
    final situacao = _intFrom(usuario['situacao']);
    final ativo = _usuarioAtivo(situacao);
    final statusColor =
        ativo ? Colors.green.shade700 : Colors.grey.shade700;
    final uuid = _usuarioUuid(usuario);
    final idServidor = _intFrom(usuario['id']);
    final identificador = _identificador(usuario);
    final temIdentificador = identificador != null;
    final meuUsuario =
        uuid != null && uuid == FFAppState().UserUuid.trim();
    final canEdit = MembershipAccess.canPermission('edit_usuarios');
    final canDelete = MembershipAccess.canPermission('delete_usuarios');

    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: temIdentificador ? () => _abrirDetalhes(usuario) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: statusColor),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: theme.primary.withValues(alpha: 0.12),
                        child: Text(
                          _iniciais(nome),
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: theme.primary,
                          ),
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
                                fontWeight: FontWeight.w700,
                                color: theme.primaryText,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: theme.secondaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  tipo,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: theme.primary,
                                  ),
                                ),
                                Text(
                                  '· $cargo',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    color: theme.secondaryText,
                                  ),
                                ),
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
                                    _rotuloStatus(situacao),
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (temIdentificador)
                        PopupMenuButton<String>(
                          tooltip: 'Ações',
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: theme.secondaryText,
                            size: 20,
                          ),
                          onSelected: (value) {
                            switch (value) {
                              case 'detalhes':
                                _abrirDetalhes(usuario);
                                break;
                              case 'editar':
                                _abrirCadastro(usuarioUuid: identificador);
                                break;
                              case 'excluir':
                                _confirmarExcluir(usuario);
                                break;
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'detalhes',
                              child: Text('Ver detalhes'),
                            ),
                            if (canEdit &&
                                (uuid != null || idServidor != null))
                              const PopupMenuItem(
                                value: 'editar',
                                child: Text('Editar'),
                              ),
                            if (canDelete &&
                                !meuUsuario &&
                                (uuid != null || idServidor != null))
                              PopupMenuItem(
                                value: 'excluir',
                                child: Text(
                                  'Apagar',
                                  style: TextStyle(color: theme.error),
                                ),
                              ),
                          ],
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
}

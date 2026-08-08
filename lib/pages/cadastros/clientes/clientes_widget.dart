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
import 'clientes_model.dart';
export 'clientes_model.dart';

/// Lista de clientes com cadastro, edição, detalhes e exclusão.
class ClientesWidget extends StatefulWidget {
  const ClientesWidget({super.key});

  static String routeName = 'Clientes';
  static String routePath = '/clientes';

  @override
  State<ClientesWidget> createState() => _ClientesWidgetState();
}

class _ClientesWidgetState extends State<ClientesWidget> {
  late ClientesModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _buscaController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _clientesFuture;
  List<Map<String, dynamic>> _clientes = [];
  bool _isLoading = true;
  String? _error;
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ClientesModel());
    _clientesFuture = _fetchClientesApi();
    _carregar();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!MembershipAccess.canPermission('view_clientes')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para visualizar clientes.',
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

  List<Map<String, dynamic>> _extractClientes(dynamic body) {
    final rawClientes = body is Map ? body['clientes'] : null;
    final rawData = rawClientes is Map ? rawClientes['data'] : rawClientes;
    if (rawData is! List) return [];
    return rawData
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> _fetchClientesApi() async {
    final resp = await ListarClientesApiCall.call(
      token: FFAppState().UserToken,
      itemsPerPage: 1000,
    );
    if (!resp.succeeded) {
      throw Exception(
        resp.bodyText.isNotEmpty ? resp.bodyText : 'Erro ao carregar clientes',
      );
    }
    return _extractClientes(resp.jsonBody);
  }

  Future<void> _carregar() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _clientesFuture = _fetchClientesApi();
    });
    try {
      final list = await _clientesFuture;
      if (!mounted) return;
      setState(() {
        _clientes = list;
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

  String? _clienteUuid(Map<String, dynamic> cliente) {
    final uuid = cliente['uuid']?.toString().trim();
    return uuid != null && uuid.isNotEmpty ? uuid : null;
  }

  List<Map<String, dynamic>> get _filtrados {
    final q = _busca.trim().toLowerCase();
    if (q.isEmpty) return _clientes;
    return _clientes.where((c) {
      final nome = (c['nome']?.toString() ?? '').toLowerCase();
      final email = (c['email']?.toString() ?? '').toLowerCase();
      final tel = (c['telefone']?.toString() ?? '').toLowerCase();
      final doc = (c['documento']?.toString() ??
              c['cpf_cnpj']?.toString() ??
              c['cpf']?.toString() ??
              c['cnpj']?.toString() ??
              '')
          .toLowerCase();
      return nome.contains(q) ||
          email.contains(q) ||
          tel.contains(q) ||
          doc.contains(q);
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

  void _abrirCadastro({String? clienteUuid}) {
    if (clienteUuid == null || clienteUuid.isEmpty) {
      if (!MembershipAccess.canPermission('create_clientes')) {
        MembershipAccess.showDenied(
          context,
          'Sem permissão para criar clientes.',
        );
        return;
      }
    } else if (!MembershipAccess.canPermission('edit_clientes')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para editar clientes.',
      );
      return;
    }

    context.pushNamed(
      CadastrarClienteWidget.routeName,
      queryParameters: {
        'clienteUuid': serializeParam(clienteUuid, ParamType.String),
      }.withoutNulls,
      extra: <String, dynamic>{
        kTransitionInfoKey: const TransitionInfo(
          hasTransition: true,
          transitionType: PageTransitionType.rightToLeft,
        ),
      },
    ).then((_) {
      if (mounted) _carregar();
    });
  }

  Future<void> _abrirDetalhes(Map<String, dynamic> cliente) async {
    final clienteUuid = _clienteUuid(cliente);
    final clienteId = _intFrom(cliente['id']);
    await context.pushNamed(
      ClienteDetalhesWidget.routeName,
      queryParameters: {
        'clienteServidorId': serializeParam(clienteId, ParamType.int),
        'clienteUuid': serializeParam(clienteUuid, ParamType.String),
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

  Future<void> _confirmarExcluir(Map<String, dynamic> cliente) async {
    if (!MembershipAccess.canPermission('delete_clientes')) {
      MembershipAccess.showDenied(
        context,
        'Sem permissão para excluir clientes.',
      );
      return;
    }

    final theme = FlutterFlowTheme.of(context);
    final nome = valueOrDefault<String>(cliente['nome']?.toString(), 'Cliente');
    final clienteUuid = _clienteUuid(cliente);
    final clienteId = _intFrom(cliente['id']);

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
          'Apagar cliente',
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: theme.primaryText,
          ),
        ),
        content: Text(
          'Deseja apagar o cliente "$nome"? Ele deixará de aparecer na lista.',
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

    final resp = await ExcluirClienteCall.call(
      id: clienteId,
      clienteUuid: clienteUuid ?? '',
      token: FFAppState().UserToken,
    );
    if (!mounted) return;

    if (resp.succeeded) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cliente apagado'),
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
                : 'Erro ao apagar cliente',
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
    final canCreate = MembershipAccess.canPermission('create_clientes');
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
                  'Clientes',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Cadastro geral do sistema',
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
                tooltip: 'Novo cliente',
                icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
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
                        title: 'Incluir cliente',
                        icon: Icons.person_add_alt_1_outlined,
                        subtitle: 'Cadastrar novo cliente',
                        margin: const EdgeInsets.only(bottom: 10),
                        child: FilledButton.icon(
                          onPressed: () => _abrirCadastro(),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: Text(
                            'Novo cliente',
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
                          label: 'Nome, e-mail, telefone ou documento',
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
                      title: 'Lista de clientes',
                      icon: Icons.people_alt_outlined,
                      subtitle: _isLoading
                          ? 'Carregando…'
                          : filtrados.isEmpty
                              ? 'Nenhum cliente encontrado'
                              : _busca.trim().isEmpty
                                  ? 'Toque para ver detalhes'
                                  : '${filtrados.length} de ${_clientes.length}',
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
    if (_isLoading && _clientes.isEmpty) {
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

    if (_error != null && _clientes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
        child: Column(
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: theme.error),
            const SizedBox(height: 12),
            Text(
              'Erro ao carregar clientes',
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
              Icons.people_outline_rounded,
              size: 40,
              color: theme.secondaryText.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _clientes.isEmpty
                  ? 'Nenhum cliente cadastrado'
                  : 'Nenhum resultado na busca',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.primaryText,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _clientes.isEmpty
                  ? (canCreate
                      ? 'Cadastre o primeiro cliente para começar.'
                      : 'Não há clientes disponíveis.')
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
          _buildClienteItem(theme, filtrados[i]),
        ],
      ],
    );
  }

  Widget _buildClienteItem(
    FlutterFlowTheme theme,
    Map<String, dynamic> cliente,
  ) {
    final nome =
        valueOrDefault<String>(cliente['nome']?.toString(), 'Cliente sem nome');
    final email =
        valueOrDefault<String>(cliente['email']?.toString(), 'Sem e-mail');
    final telefone = valueOrDefault<String>(
        cliente['telefone']?.toString(), 'Sem telefone');
    final clienteUuid = _clienteUuid(cliente);
    final clienteId = _intFrom(cliente['id']);
    final canEdit = MembershipAccess.canPermission('edit_clientes');
    final canDelete = MembershipAccess.canPermission('delete_clientes');

    return Material(
      color: theme.secondaryBackground,
      child: InkWell(
        onTap: () => _abrirDetalhes(cliente),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 3, color: theme.primary),
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
                            const SizedBox(height: 1),
                            Text(
                              telefone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 11.5,
                                color: theme.secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                              _abrirDetalhes(cliente);
                              break;
                            case 'editar':
                              _abrirCadastro(clienteUuid: clienteUuid);
                              break;
                            case 'excluir':
                              _confirmarExcluir(cliente);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'detalhes',
                            child: Text('Ver detalhes'),
                          ),
                          if (canEdit &&
                              (clienteUuid != null || clienteId != null))
                            const PopupMenuItem(
                              value: 'editar',
                              child: Text('Editar'),
                            ),
                          if (canDelete &&
                              (clienteUuid != null || clienteId != null))
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

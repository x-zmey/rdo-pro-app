import '/auth/apply_membership_auth.dart';
import '/app_version.dart';
import '/componentes/dialogs/logout_dialog/logout_dialog_widget.dart';
import '/componentes/navegacao/barra_navegacao_principal.dart';
import '/componentes/permission/menu_permission_tile.dart';
import '/componentes/tenant_switcher/tenant_switcher_widget.dart';
import '/componentes/ui/rdo_estilo.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'menu_model.dart';
export 'menu_model.dart';

/// Página de menu aberta pela barra inferior — acessos rápidos do sistema.
class MenuWidget extends StatefulWidget {
  const MenuWidget({super.key});

  static String routeName = 'Menu';
  static String routePath = '/menu';

  @override
  State<MenuWidget> createState() => _MenuWidgetState();
}

class _MenuWidgetState extends State<MenuWidget> {
  late MenuModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  /// `versionName` do build — igual à Play Store (pubspec antes do `+`).
  String _versaoApp = kAppVersionName;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MenuModel());
    _carregarVersaoApp();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await refreshSessionFromServer();
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  Future<void> _carregarVersaoApp() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final v = info.version.trim();
      if (!mounted || v.isEmpty) return;
      if (v != _versaoApp) {
        setState(() => _versaoApp = v);
      }
    } catch (_) {
      // Mantém [kAppVersionName] do pubspec.
    }
  }

  void _navegar(
    String routeName, {
    PageTransitionType transition = PageTransitionType.bottomToTop,
  }) {
    context.pushNamed(
      routeName,
      extra: <String, dynamic>{
        kTransitionInfoKey: TransitionInfo(
          hasTransition: true,
          transitionType: transition,
        ),
      },
    );
  }

  Future<void> _abrirLogout() async {
    await showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          elevation: 0,
          insetPadding: EdgeInsets.zero,
          backgroundColor: Colors.transparent,
          alignment: AlignmentDirectional.center
              .resolve(Directionality.of(context)),
          child: GestureDetector(
            onTap: () {
              FocusScope.of(dialogContext).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: const LogoutDialogWidget(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();
    final theme = FlutterFlowTheme.of(context);

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
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                _navegar(InicioWidget.routeName);
              }
            },
          ),
          title: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu',
                  style: GoogleFonts.interTight(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Funcionalidades do sistema',
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
              tooltip: 'Início',
              icon: const Icon(Icons.home_outlined, color: Colors.white, size: 21),
              onPressed: () => _navegar(InicioWidget.routeName),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Expanded(
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
                  const TenantSwitcherWidget(compact: false),
                  const SizedBox(height: 10),
                  _secao(
                    theme,
                    title: 'Conta e sistema',
                    icon: Icons.manage_accounts_outlined,
                    itens: [
                      _item(
                        theme,
                        icon: Icons.notifications_outlined,
                        title: 'Notificações',
                        subtitle: 'Alertas de OS, RDO e sistema',
                        onTap: () => _navegar(NotificacoesWidget.routeName),
                      ),
                      _item(
                        theme,
                        icon: Icons.sync_rounded,
                        title: 'Sincronização',
                        subtitle: 'Sincronizar dados do sistema',
                        onTap: () => _navegar(SincronizacoesWidget.routeName),
                      ),
                      _item(
                        theme,
                        icon: Icons.person_rounded,
                        title: 'Perfil',
                        subtitle: 'Gerenciar informações pessoais',
                        onTap: () => _navegar(EditarPerfilWidget.routeName),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _secao(
                    theme,
                    title: 'Operação',
                    icon: Icons.work_outline_rounded,
                    itens: [
                      MenuPermissionTile(
                        permission: 'view_medicoes',
                        permitido: const [
                          'administrador',
                          'supervisor',
                          'operador',
                        ],
                        child: _item(
                          theme,
                          icon: Icons.straighten_rounded,
                          title: 'Medições',
                          subtitle: 'Listagem mensal por obra',
                          onTap: () => _navegar(MedicoesWidget.routeName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _secao(
                    theme,
                    title: 'Cadastros',
                    icon: Icons.folder_open_outlined,
                    itens: [
                      MenuPermissionTile(
                        permission: 'view_clientes',
                        child: _item(
                          theme,
                          icon: Icons.people_alt_outlined,
                          title: 'Clientes',
                          subtitle: 'Gerenciar clientes do sistema',
                          onTap: () => _navegar(ClientesWidget.routeName),
                        ),
                      ),
                      MenuPermissionTile(
                        permission: 'view_cadastros_gerais',
                        permitido: const [
                          'administrador',
                          'operador',
                          'supervisor',
                        ],
                        child: _item(
                          theme,
                          icon: Icons.dns_rounded,
                          title: 'Grupos de obras',
                          subtitle: 'Gerenciar grupos de obras',
                          onTap: () => _navegar(
                            GruposObrasWidget.routeName,
                            transition: PageTransitionType.rightToLeft,
                          ),
                        ),
                      ),
                      MenuPermissionTile(
                        permission: 'view_insumos',
                        permitido: const [
                          'administrador',
                          'supervisor',
                          'operador',
                        ],
                        child: _item(
                          theme,
                          icon: Icons.inventory_2_outlined,
                          title: 'Insumos',
                          subtitle: 'Gerenciar insumos',
                          onTap: () =>
                              _navegar(InsumosCadastrosWidget.routeName),
                        ),
                      ),
                      MenuPermissionTile(
                        permission: 'view_equipamentos',
                        permitido: const [
                          'administrador',
                          'supervisor',
                          'operador',
                        ],
                        child: _item(
                          theme,
                          icon: Icons.agriculture_outlined,
                          title: 'Equipamentos',
                          subtitle: 'Gerenciar equipamentos',
                          onTap: () =>
                              _navegar(EquipamentosCadastrosWidget.routeName),
                        ),
                      ),
                      MenuPermissionTile(
                        permission: 'view_mao_obra',
                        permitido: const ['administrador', 'supervisor'],
                        child: _item(
                          theme,
                          icon: Icons.group_outlined,
                          title: 'Mão de obra',
                          subtitle: 'Gerenciar mão de obra',
                          onTap: () =>
                              _navegar(MaoObraCadastrosWidget.routeName),
                        ),
                      ),
                      MenuPermissionTile(
                        permission: 'view_mao_obra',
                        permitido: const [
                          'administrador',
                          'operador',
                          'supervisor',
                        ],
                        child: _item(
                          theme,
                          icon: Icons.badge_outlined,
                          title: 'Funções mão de obra',
                          subtitle: 'Gerenciar funções predefinidas',
                          onTap: () =>
                              _navegar(FuncoesMaoObraWidget.routeName),
                        ),
                      ),
                      MenuPermissionTile(
                        permission: 'view_cadastros_gerais',
                        permitido: const [
                          'administrador',
                          'operador',
                          'supervisor',
                        ],
                        child: _item(
                          theme,
                          icon: Icons.place_outlined,
                          title: 'Locais',
                          subtitle: 'Gerenciar locais de obras',
                          onTap: () => _navegar(LocaisWidget.routeName),
                        ),
                      ),
                      MenuPermissionTile(
                        permission: 'view_usuarios',
                        child: _item(
                          theme,
                          icon: Icons.manage_accounts_outlined,
                          title: 'Usuários',
                          subtitle: 'Gerenciar usuários',
                          onTap: () => _navegar(UsuariosWidget.routeName),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _secao(
                    theme,
                    title: 'Sessão',
                    icon: Icons.logout_rounded,
                    itens: [
                      _item(
                        theme,
                        icon: Icons.logout_rounded,
                        title: 'Deslogar',
                        subtitle: 'Sair do sistema',
                        destructive: true,
                        onTap: _abrirLogout,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _rodapeVersao(theme),
                ],
              ),
            ),
            const BarraNavegacaoPrincipal(),
          ],
        ),
      ),
    );
  }

  Widget _secao(
    FlutterFlowTheme theme, {
    required String title,
    required IconData icon,
    required List<Widget> itens,
  }) {
    return RdoSectionCard(
      title: title,
      icon: icon,
      margin: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      trailing: RdoContadorChip('${itens.length}'),
      child: Material(
        color: theme.secondaryBackground,
        child: Column(
          children: [
            for (var i = 0; i < itens.length; i++) ...[
              if (i > 0)
                Divider(height: 1, thickness: 1, color: theme.alternate),
              itens[i],
            ],
          ],
        ),
      ),
    );
  }

  /// Retorna [InkWell] na raiz para [MenuPermissionTile] interceptar o toque.
  Widget _item(
    FlutterFlowTheme theme, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool destructive = false,
  }) {
    final accent = destructive ? theme.error : theme.primary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: destructive ? theme.error : theme.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
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
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.secondaryText,
            ),
          ],
        ),
      ),
    );
  }

  Widget _rodapeVersao(FlutterFlowTheme theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(kRdoRadius),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline_rounded, color: theme.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            'Versão $_versaoApp',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: theme.primaryText,
            ),
          ),
        ],
      ),
    );
  }
}

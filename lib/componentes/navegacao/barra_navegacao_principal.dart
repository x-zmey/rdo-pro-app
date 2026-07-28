import '/auth/membership_access.dart';
import '/componentes/permission/permission_gate.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Margem inferior recomendada para o conteúdo scrollável (evita sobrepor a barra
/// e o botão + elevado; alinhada ao uso em [DetalhesObra]).
const double kBarraNavegacaoPrincipalReservaScroll = 72.0;

/// Ações rápidas ao tocar no botão central [+] (novo RDO, obra, utilizador).
void abrirMenuAdicionarNovoBottomSheet(BuildContext context) {
  final canRelatorio = MembershipAccess.canPermission('generate_rdo');
  final canObra = MembershipAccess.canPermission('create_obras');
  final canUsuario = MembershipAccess.canPermission('create_usuarios');

  if (!canRelatorio && !canObra && !canUsuario) {
    MembershipAccess.showDenied(
      context,
      'Sem permissão para cadastrar relatório, obra ou usuário.',
    );
    return;
  }

  final t = FlutterFlowTheme.of(context);
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    showDragHandle: true,
    backgroundColor: t.secondaryBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (canRelatorio)
                ListTile(
                  leading: const Icon(Icons.description_outlined,
                      color: Colors.indigo, size: 24),
                  title: Text('Cadastrar relatório', style: t.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.pushNamed(
                      CadastrarRelatorioGeralWidget.routeName,
                      extra: <String, dynamic>{
                        kTransitionInfoKey: const TransitionInfo(
                          hasTransition: true,
                          transitionType: PageTransitionType.bottomToTop,
                        ),
                      },
                    );
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.description_outlined,
                      color: t.secondaryText, size: 24),
                  title: Text(
                    'Cadastrar relatório',
                    style: t.bodyLarge.copyWith(color: t.secondaryText),
                  ),
                  trailing: Icon(Icons.lock_outline,
                      size: 18, color: t.secondaryText),
                  onTap: () => MembershipAccess.showDenied(
                    sheetContext,
                    'Sem permissão para gerar RDO.',
                  ),
                ),
              if (canObra)
                ListTile(
                  leading: Icon(Icons.business, color: t.primary, size: 24),
                  title: Text('Cadastrar obra', style: t.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.pushNamed(
                      CadastrarObraWidget.routeName,
                      extra: <String, dynamic>{
                        kTransitionInfoKey: const TransitionInfo(
                          hasTransition: true,
                          transitionType: PageTransitionType.bottomToTop,
                        ),
                      },
                    );
                  },
                )
              else
                ListTile(
                  leading:
                      Icon(Icons.business, color: t.secondaryText, size: 24),
                  title: Text(
                    'Cadastrar obra',
                    style: t.bodyLarge.copyWith(color: t.secondaryText),
                  ),
                  trailing: Icon(Icons.lock_outline,
                      size: 18, color: t.secondaryText),
                  onTap: () => MembershipAccess.showDenied(
                    sheetContext,
                    'Sem permissão para criar obras.',
                  ),
                ),
              if (canUsuario)
                ListTile(
                  leading:
                      Icon(Icons.person_add_alt_1, color: t.primary, size: 24),
                  title: Text('Cadastrar usuário', style: t.bodyLarge),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.pushNamed(
                      CadastrarUsuarioWidget.routeName,
                      extra: <String, dynamic>{
                        kTransitionInfoKey: const TransitionInfo(
                          hasTransition: true,
                          transitionType: PageTransitionType.bottomToTop,
                        ),
                      },
                    );
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.person_add_alt_1,
                      color: t.secondaryText, size: 24),
                  title: Text(
                    'Cadastrar usuário',
                    style: t.bodyLarge.copyWith(color: t.secondaryText),
                  ),
                  trailing: Icon(Icons.lock_outline,
                      size: 18, color: t.secondaryText),
                  onTap: () => MembershipAccess.showDenied(
                    sheetContext,
                    'Sem permissão para criar usuários.',
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
  );
}

/// Barra fixa: Início, Relatórios, [+], Medições, Menu — mesmo padrão em toda a app.
class BarraNavegacaoPrincipal extends StatelessWidget {
  const BarraNavegacaoPrincipal({
    super.key,
    this.onAdicionar,
  });

  /// Se null, abre [abrirMenuAdicionarNovoBottomSheet].
  final VoidCallback? onAdicionar;

  @override
  Widget build(BuildContext context) {
    void adicionar() {
      (onAdicionar ?? () => abrirMenuAdicionarNovoBottomSheet(context))();
    }

    final t = FlutterFlowTheme.of(context);
    return ColoredBox(
      color: t.primary,
      child: SafeArea(
        top: false,
        child: Material(
          color: t.primary,
          clipBehavior: Clip.none,
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: t.primary,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  offset: const Offset(0, -2),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _item(
                  context,
                  icon: Icons.home_outlined,
                  label: 'Início',
                  onTap: () {
                    context.pushNamed(InicioWidget.routeName);
                  },
                ),
                _item(
                  context,
                  icon: Icons.description_outlined,
                  label: 'Relatórios',
                  onTap: () => runWithPermission(
                    context,
                    permissions: const [
                      'view_relatorios_gerais',
                      'generate_rdo',
                    ],
                    onAllowed: () {
                      context.pushNamed(
                        RelatoriosGeraisWidget.routeName,
                        extra: <String, dynamic>{
                          kTransitionInfoKey: const TransitionInfo(
                            hasTransition: true,
                            transitionType: PageTransitionType.rightToLeft,
                          ),
                        },
                      );
                    },
                  ),
                ),
                _botaoAdd(context, adicionar),
                _item(
                  context,
                  icon: Icons.straighten,
                  label: 'Medições',
                  onTap: () => runWithPermission(
                    context,
                    permission: 'view_medicoes',
                    permitido: const [
                      'administrador',
                      'supervisor',
                      'operador',
                    ],
                    onAllowed: () {
                      context.pushNamed(MedicoesWidget.routeName);
                    },
                  ),
                ),
                _item(
                  context,
                  icon: Icons.menu_rounded,
                  label: 'Menu',
                  onTap: () {
                    context.pushNamed(
                      MenuWidget.routeName,
                      extra: <String, dynamic>{
                        kTransitionInfoKey: const TransitionInfo(
                          hasTransition: true,
                          transitionType: PageTransitionType.bottomToTop,
                        ),
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _item(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final t = FlutterFlowTheme.of(context);
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 19, color: t.info),
                const SizedBox(height: 1),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.labelSmall.override(
                    font: GoogleFonts.inter(fontWeight: FontWeight.w500),
                    color: t.info,
                    fontSize: 9.0,
                    letterSpacing: 0.0,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static Widget _botaoAdd(BuildContext context, VoidCallback onTap) {
    final t = FlutterFlowTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Transform.translate(
        offset: const Offset(0, -16),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: t.primaryBackground,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: t.primary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

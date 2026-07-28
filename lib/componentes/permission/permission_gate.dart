import '/auth/membership_access.dart';
import 'package:flutter/material.dart';

/// Mantém [child] visível; use [runWithPermission] no `onTap` para bloquear sem permissão.
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.child,
    this.permission,
    this.permissions,
    this.permitido,
    this.fallback,
    this.requireFullAccess = false,
  });

  final Widget child;
  final String? permission;
  final List<String>? permissions;
  final List<String>? permitido;
  final Widget? fallback;
  final bool requireFullAccess;

  @override
  Widget build(BuildContext context) => child;
}

/// Executa [onAllowed] ou mostra mensagem de acesso negado.
void runWithPermission(
  BuildContext context, {
  String? permission,
  List<String>? permissions,
  List<String>? permitido,
  bool requireFullAccess = false,
  required VoidCallback onAllowed,
  String? deniedMessage,
}) {
  if (requireFullAccess && !MembershipAccess.isFullAccess) {
    MembershipAccess.showDenied(context, deniedMessage);
    return;
  }
  if (!MembershipAccess.canShowMenuItem(
    permission: permission,
    permissions: permissions,
    permitido: permitido,
  )) {
    MembershipAccess.showDenied(context, deniedMessage);
    return;
  }
  onAllowed();
}

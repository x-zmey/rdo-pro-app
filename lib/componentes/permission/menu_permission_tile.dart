import 'package:flutter/material.dart';

import '/auth/membership_access.dart';
import '/componentes/permission/permission_gate.dart';

/// Item de menu sempre visível; bloqueia a ação no toque sem permissão.
class MenuPermissionTile extends StatelessWidget {
  const MenuPermissionTile({
    super.key,
    required this.child,
    this.permission,
    this.permissions,
    this.permitido,
    this.requireFullAccess = false,
    this.deniedMessage,
  });

  final Widget child;
  final String? permission;
  final List<String>? permissions;
  final List<String>? permitido;
  final bool requireFullAccess;
  final String? deniedMessage;

  bool get _allowed {
    if (requireFullAccess && !MembershipAccess.isFullAccess) return false;
    return MembershipAccess.canShowMenuItem(
      permission: permission,
      permissions: permissions,
      permitido: permitido,
    );
  }

  @override
  Widget build(BuildContext context) {
    final allowed = _allowed;
    Widget tile;
    if (child is InkWell) {
      final well = child as InkWell;
      tile = InkWell(
        key: well.key,
        splashColor: well.splashColor,
        focusColor: well.focusColor,
        hoverColor: well.hoverColor,
        highlightColor: well.highlightColor,
        onTap: well.onTap == null
            ? null
            : () => runWithPermission(
                  context,
                  permission: permission,
                  permissions: permissions,
                  permitido: permitido,
                  requireFullAccess: requireFullAccess,
                  deniedMessage: deniedMessage,
                  onAllowed: well.onTap!,
                ),
        child: well.child,
      );
    } else {
      tile = child;
    }

    if (allowed) return tile;
    return Opacity(opacity: 0.55, child: tile);
  }
}

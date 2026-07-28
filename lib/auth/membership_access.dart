import 'dart:convert';

import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';

/// Perfis com acesso total no tenant (alinha frontend + UserPermissionDefaultsService).
const kFullAccessTypes = ['company', 'admin', 'administrador'];

/// Chaves SharedPreferences (espelham authStorageKeys.js do frontend).
const kPermissionNamesPref = 'ff_permissionNames';
const kObraTravadaPref = 'ff_obraTravada';
const kAllowedObraIdsPref = 'ff_allowedObraIds';
const kMembershipTypePref = 'ff_membershipType';

/// Controle de acesso por vínculo ativo (permission_names + obra_travada).
class MembershipAccess {
  MembershipAccess._();

  static String _normType(String? type) {
    if (type == null) return '';
    return type.toLowerCase().trim();
  }

  static String get membershipType {
    final fromState = _normType(FFAppState().membershipType);
    if (fromState.isNotEmpty) return fromState;
    return _normType(FFAppState().userTipo);
  }

  /// Papel usado no menu (`permitido`), alinhado ao web (`navRoleForMenu`).
  static String get navMenuRole {
    final t = membershipType;
    if (kFullAccessTypes.contains(t)) return t;
    if (t == 'user') {
      final cargo = _normType(FFAppState().userCargo);
      if (cargo.isNotEmpty) return cargo;
      return 'operador';
    }
    return t;
  }

  static bool get isFullAccess =>
      kFullAccessTypes.contains(membershipType);

  static bool get isCliente => membershipType == 'cliente';

  static bool get isOperador => membershipType == 'operador';

  static bool get isSupervisor => membershipType == 'supervisor';

  static bool get obraTravada {
    if (isCliente) return true;
    return FFAppState().obraTravada;
  }

  static List<String> get permissionNames {
    final stored = FFAppState().permissionNames;
    if (stored.isNotEmpty) return stored;
    return _namesFromPermissoes(FFAppState().UserPermissoes);
  }

  static List<int> get allowedObraIds => FFAppState().allowedObraIds;

  static bool canPermission(String? name) {
    if (name == null || name.trim().isEmpty) return true;
    if (isFullAccess) return true;
    return permissionNames.contains(name.trim());
  }

  static bool canAny(List<String>? names) {
    if (names == null || names.isEmpty) return true;
    if (isFullAccess) return true;
    return names.any(canPermission);
  }

  static bool canAccessObra(int? obraId) {
    if (obraId == null || obraId <= 0) return false;
    if (isFullAccess) return true;
    if (!obraTravada) return true;
    // Preferência: IDs locais resolvidos (allowed_obra_ids da API são do servidor).
    final local = FFAppState().allowedObraLocalIds;
    if (local.isNotEmpty) return local.contains(obraId);
    return allowedObraIds.contains(obraId);
  }

  static bool canAccessObraUuid(String? obraUuid) {
    final uuid = (obraUuid ?? '').trim();
    if (uuid.isEmpty) return false;
    if (isFullAccess) return true;
    if (!obraTravada) return true;
    final allowed = FFAppState().allowedObraUuids;
    if (allowed.isEmpty) return false;
    return allowed.contains(uuid);
  }

  /// Menu / tipos legados (`permitido` no navigation vertical).
  static bool canShowForTypes(List<String>? permitido) {
    if (permitido == null || permitido.isEmpty) return true;
    if (isFullAccess) return true;
    final t = navMenuRole;
    if (t.isEmpty) return true;
    return permitido.map(_normType).contains(t);
  }

  static bool canShowMenuItem({
    String? permission,
    List<String>? permissions,
    List<String>? permitido,
  }) {
    if (!canShowForTypes(permitido)) return false;
    if (permissions != null && permissions.isNotEmpty) {
      return canAny(permissions);
    }
    if (permission != null && permission.isNotEmpty) {
      return canPermission(permission);
    }
    return true;
  }

  static List<String> _namesFromPermissoes(dynamic permissoes) {
    if (permissoes is! List) return [];
    final names = <String>[];
    for (final item in permissoes) {
      if (item is Map) {
        final n = item['name']?.toString().trim();
        if (n != null && n.isNotEmpty) names.add(n);
      } else if (item is String && item.trim().isNotEmpty) {
        names.add(item.trim());
      }
    }
    return names;
  }

  static List<String> mergePermissionNames({
    List<String>? permissionNamesRaw,
    dynamic permissoes,
  }) {
    final set = <String>{};
    if (permissionNamesRaw != null) {
      for (final n in permissionNamesRaw) {
        if (n.trim().isNotEmpty) set.add(n.trim());
      }
    }
    for (final n in _namesFromPermissoes(permissoes)) {
      set.add(n);
    }
    final list = set.toList()..sort();
    return list;
  }

  static bool resolveObraTravada({
    dynamic membership,
    String? membershipType,
  }) {
    final type = _normType(membershipType);
    if (type == 'cliente') return true;
    if (membership is Map && membership['obra_travada'] != null) {
      final v = membership['obra_travada'];
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        return v == '1' || v.toLowerCase() == 'true';
      }
    }
    return false;
  }

  static void persistToPrefs() {
    try {
      final prefs = FFAppState().prefs;
      prefs.setString(kMembershipTypePref, membershipType);
      prefs.setString(
        kPermissionNamesPref,
        jsonEncode(FFAppState().permissionNames),
      );
      prefs.setBool(kObraTravadaPref, FFAppState().obraTravada);
      prefs.setString(
        kAllowedObraIdsPref,
        jsonEncode(FFAppState().allowedObraIds),
      );
    } catch (_) {}
  }

  static void loadFromPrefs() {
    try {
      final prefs = FFAppState().prefs;
      final type = prefs.getString(kMembershipTypePref);
      if (type != null && type.isNotEmpty) {
        FFAppState().membershipType = type;
      }
      final namesRaw = prefs.getString(kPermissionNamesPref);
      if (namesRaw != null && namesRaw.isNotEmpty) {
        final decoded = jsonDecode(namesRaw);
        if (decoded is List) {
          FFAppState().permissionNames = decoded
              .map((e) => e.toString())
              .where((s) => s.isNotEmpty)
              .toList();
        }
      }
      FFAppState().obraTravada = prefs.getBool(kObraTravadaPref) ?? false;
      final idsRaw = prefs.getString(kAllowedObraIdsPref);
      if (idsRaw != null && idsRaw.isNotEmpty) {
        final decoded = jsonDecode(idsRaw);
        if (decoded is List) {
          FFAppState().allowedObraIds = decoded
              .map((e) => int.tryParse(e.toString()) ?? 0)
              .where((id) => id > 0)
              .toList();
        }
      }
    } catch (_) {}
  }

  static void clearMembershipPrefs() {
    try {
      final prefs = FFAppState().prefs;
      prefs.remove(kMembershipTypePref);
      prefs.remove(kPermissionNamesPref);
      prefs.remove(kObraTravadaPref);
      prefs.remove(kAllowedObraIdsPref);
    } catch (_) {}
  }

  /// Snackbar padrão quando ação é bloqueada.
  static void showDenied(BuildContext context, [String? message]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message ?? 'Você não tem permissão para esta ação.',
        ),
      ),
    );
  }
}

import '/auth/fetch_allowed_obras.dart';
import '/auth/membership_access.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/sqlite/empresa_multi_tenant_sqlite.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Resolve o tenant ativo priorizando `membership.tenant_user_id` (fonte confiável).
int? resolveActiveTenantUserId(
  dynamic response, {
  int? fallbackTenantUserId,
  bool preserveLocalOnConflict = false,
}) {
  final localTenant = FFAppState().activeTenantUserId;
  final fromMembership = LoginCall.membershipTenantUserId(response);
  final fromApi = LoginCall.activeTenantUserId(response);

  if (fromMembership != null && fromMembership > 0) {
    return fromMembership;
  }

  if (fromApi != null && fromApi > 0) {
    if (preserveLocalOnConflict &&
        localTenant > 0 &&
        fromApi != localTenant) {
      return localTenant;
    }
    return fromApi;
  }

  if (fallbackTenantUserId != null && fallbackTenantUserId > 0) {
    return fallbackTenantUserId;
  }

  return localTenant > 0 ? localTenant : null;
}

/// Hidrata permissões e vínculo a partir da resposta de login / switch-tenant / check-token.
Future<void> applyMembershipFromAuth(
  dynamic response, {
  int? fallbackTenantUserId,
  bool preserveLocalTenantOnConflict = false,
}) async {
  final tenantId = resolveActiveTenantUserId(
    response,
    fallbackTenantUserId: fallbackTenantUserId,
    preserveLocalOnConflict: preserveLocalTenantOnConflict,
  );
  if (tenantId != null && tenantId > 0) {
    FFAppState().activeTenantUserId = tenantId;
  }

  final creatorId = LoginCall.creatorId(response);
  if (creatorId != null && creatorId > 0) {
    FFAppState().creatorId = creatorId;
  } else if (tenantId != null && tenantId > 0) {
    FFAppState().creatorId = tenantId;
  }

  var creatorUuid = LoginCall.creatorUuid(response)?.trim() ?? '';
  if (creatorUuid.isEmpty) {
    creatorUuid = LoginCall.membershipTenantUuid(response)?.trim() ?? '';
  }
  if (creatorUuid.isNotEmpty) {
    FFAppState().creatorUuid = creatorUuid;
  }

  final empresaUserId = LoginCall.activeEmpresaUserId(response);
  if (empresaUserId != null && empresaUserId > 0) {
    FFAppState().activeEmpresaUserId = empresaUserId;
  }

  final membershipType = _resolveMembershipType(response);
  if (membershipType.isNotEmpty) {
    FFAppState().membershipType = membershipType;
    FFAppState().userTipo = membershipType;
  } else {
    final userType = LoginCall.userTypeRoot(response);
    if (userType != null && userType.isNotEmpty) {
      FFAppState().userTipo = userType;
      FFAppState().membershipType = userType.toLowerCase().trim();
    }
  }

  final cargo = LoginCall.userCargo(response)?.trim() ?? '';
  if (cargo.isNotEmpty) {
    FFAppState().userCargo = cargo;
  }

  final membership = LoginCall.membership(response);
  final obraTravada = MembershipAccess.resolveObraTravada(
    membership: membership,
    membershipType: FFAppState().membershipType,
  );
  FFAppState().obraTravada = obraTravada;

  final empresaNome = LoginCall.empresaNome(response);
  if (empresaNome != null && empresaNome.isNotEmpty) {
    FFAppState().activeEmpresaNome = empresaNome;
  }

  // SQLite primeiro (offline); a API abaixo sempre prevalece quando vier no payload.
  await refreshAppStatePermissoesFromSqlite();

  final apiNames = LoginCall.permissionNames(response);
  final apiPerms = LoginCall.permissoes(response);
  final hasApiPermPayload = apiNames != null || apiPerms is List;

  if (hasApiPermPayload) {
    final names = MembershipAccess.mergePermissionNames(
      permissionNamesRaw: apiNames,
      permissoes: apiPerms,
    );
    // Lista vazia também conta: permissões revogadas no servidor.
    FFAppState().permissionNames = names;
    if (apiPerms is List && apiPerms.isNotEmpty) {
      FFAppState().UserPermissoes = apiPerms;
    } else {
      FFAppState().UserPermissoes =
          names.map((n) => {'name': n}).toList();
    }
  } else if (FFAppState().permissionNames.isEmpty) {
    final fromSqlite = MembershipAccess.mergePermissionNames(
      permissoes: FFAppState().UserPermissoes,
    );
    if (fromSqlite.isNotEmpty) {
      FFAppState().permissionNames = fromSqlite;
    }
  }

  final allowedFromLogin = LoginCall.allowedObraIds(response);
  if (allowedFromLogin != null && allowedFromLogin.isNotEmpty) {
    FFAppState().allowedObraIds = allowedFromLogin;
    MembershipAccess.persistToPrefs();
  }
  // Sempre busca vínculos com UUID (API) e garante linhas locais — IDs do
  // login sozinhos não batem com o id AUTOINCREMENT do SQLite.
  await refreshAllowedObraIdsIfNeeded();
  MembershipAccess.persistToPrefs();
}

/// Reidrata permissões e vínculo a partir de `GET /api/check-token` (com tenant ativo).
Future<void> refreshSessionFromServer() async {
  final token = FFAppState().UserToken.trim();
  if (token.isEmpty) return;

  try {
    final res = await AuthCheckTokenCall.call(token: token);
    if (res.succeeded && res.jsonBody != null) {
      await applyMembershipFromAuth(
        res.jsonBody,
        preserveLocalTenantOnConflict: true,
      );
    }
  } catch (e) {
    print('refreshSessionFromServer: $e');
  }
}

String _resolveMembershipType(dynamic response) {
  final m = LoginCall.membership(response);
  if (m is Map) {
    final t = m['type']?.toString();
    if (t != null && t.isNotEmpty) return t.toLowerCase().trim();
  }
  final root = LoginCall.userTypeRoot(response);
  if (root != null && root.isNotEmpty) {
    return root.toLowerCase().trim();
  }
  return '';
}

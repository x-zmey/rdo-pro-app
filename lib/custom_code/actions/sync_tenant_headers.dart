import '/flutter_flow/flutter_flow_util.dart';

/// Headers comuns para rotas de sync que respeitam o tenant ativo.
Map<String, String> syncAuthHeaders({String contentType = 'application/json'}) {
  final headers = <String, String>{
    'Content-Type': contentType,
    'Authorization': 'Bearer ${FFAppState().UserToken}',
  };
  final tenantId = FFAppState().activeTenantUserId;
  if (tenantId > 0) {
    headers['X-Tenant-User-Id'] = tenantId.toString();
  }
  return headers;
}

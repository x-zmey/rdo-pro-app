/// Base da API Laravel usada pelo app.
///
/// Staging é o padrão. Para apontar para outro ambiente:
/// `flutter run --dart-define=API_BASE_URL=https://api.rdopro.com.br`
const String kApiBaseUrl = String.fromEnvironment(
  'API_BASE_URL',
  defaultValue: 'https://staging-api.rdopro.com.br',
);

/// Host sem esquema, para lookup de rede (`api.rdopro.com.br`).
String get kApiHost {
  final host = Uri.parse(kApiBaseUrl).host;
  return host.isEmpty ? kApiBaseUrl : host;
}

/// Monta URL absoluta a partir de um caminho (`/api/...` ou `api/...`).
String apiUrl(String path) {
  final base = kApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  if (path.isEmpty) {
    return base;
  }
  final normalized = path.startsWith('/') ? path : '/$path';
  return '$base$normalized';
}

Uri apiUri(String path, [Map<String, String>? query]) {
  final uri = Uri.parse(apiUrl(path));
  if (query == null || query.isEmpty) {
    return uri;
  }
  return uri.replace(queryParameters: {
    ...uri.queryParameters,
    ...query,
  });
}

/// Base pública do bucket S3 das capas de obra (mesmo de `AWS_URL` no servidor).
const kObrasFotoS3BaseUrl = 'https://rdo-pro-principal.s3.amazonaws.com';

/// Resolve URL absoluta para exibir/baixar a capa da obra.
///
/// - Se [fotoUrl] já for http(s), usa ela.
/// - Se [foto] for http(s), usa ela.
/// - Se [foto] for path relativo do S3, monta a URL pública.
String? resolveObraFotoNetworkUrl({
  String? foto,
  String? fotoUrl,
}) {
  final url = (fotoUrl ?? '').trim();
  if (url.startsWith('http://') || url.startsWith('https://')) {
    return url;
  }

  final path = (foto ?? '').trim();
  if (path.isEmpty) return null;
  if (path.startsWith('http://') || path.startsWith('https://')) {
    return path;
  }

  final relative = path.startsWith('/') ? path.substring(1) : path;
  return '$kObrasFotoS3BaseUrl/$relative';
}

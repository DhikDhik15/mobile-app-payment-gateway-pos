import 'package:payment_simulator/core/config/app_environment.dart';

/// Path prefix for backend-local catalog image references.
///
/// The backend returns product `image_url` values either as absolute
/// `https://` URLs or as backend-local references such as
/// `/api/v1/product-images/<merchant-uuid>/<file-uuid>.png`. Only references
/// under this prefix are resolved against the configured backend origin;
/// anything else is treated as unrenderable (placeholder).
const String productImageApiPrefix = '/api/v1/product-images/';

/// Resolves a backend product `image_url` into a renderable absolute URL.
///
/// Display-only helper (uploads are out of scope):
/// * absolute `http(s)` URLs are returned unchanged;
/// * backend-local references starting with [productImageApiPrefix] are
///   resolved against the origin (scheme + host + port) of [apiBaseUrl]
///   (defaults to [AppEnvironment.apiBaseUrl]), so a base URL that already
///   carries an `/api/v1` path never produces a doubled prefix;
/// * null, blank, malformed, relative non-catalog, and unsupported-scheme
///   values resolve to null so callers render the placeholder.
///
/// No credentials are ever attached or logged; catalog images are served by
/// the backend as public assets and are fetched with a plain GET.
String? resolveProductImageUrl(String? rawImageUrl, {String? apiBaseUrl}) {
  final value = rawImageUrl?.trim() ?? '';
  if (value.isEmpty) return null;
  final parsed = Uri.tryParse(value);
  if (parsed == null) return null;
  if (parsed.hasScheme) {
    if (parsed.scheme == 'http' || parsed.scheme == 'https') return value;
    return null;
  }
  if (!value.startsWith(productImageApiPrefix)) return null;
  final base = (apiBaseUrl ?? AppEnvironment.apiBaseUrl).trim();
  if (base.isEmpty) return null;
  final baseUri = Uri.tryParse(base);
  if (baseUri == null || !baseUri.hasAuthority) return null;
  final origin = '${baseUri.scheme}://${baseUri.authority}';
  return '$origin$value';
}

/// A normalized, library-agnostic HTTP response.
///
/// The GO-SAAS backend wraps every successful payload in a success envelope
/// (`{"success": true, "data": ..., "meta": ...}`). The shared API client
/// unwraps that envelope so callers receive the inner [data] directly, along
/// with the HTTP [statusCode]. Pagination endpoints additionally expose the
/// envelope's [meta] map (`page`, `limit`, `total`, `total_pages`).
class NetworkResponse {
  const NetworkResponse({required this.statusCode, required this.data, this.meta});

  /// The HTTP status code returned by the server.
  final int statusCode;

  /// The decoded response payload (the unwrapped `data` field of the success
  /// envelope, or the raw decoded body for non-envelope responses).
  final dynamic data;

  /// The decoded `meta` map of the success envelope, or null when the
  /// response carries no metadata (non-paginated endpoints).
  final dynamic meta;

  @override
  String toString() => 'NetworkResponse(statusCode: $statusCode)';
}

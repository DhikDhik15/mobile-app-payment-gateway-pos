import 'package:payment_simulator/core/network/network_response.dart';

/// Abstract HTTP API client contract.
///
/// This abstraction lives in `core/` so that the domain and data layers can
/// depend on it without being coupled to any specific HTTP library
/// (Dio, http, etc.). A single concrete implementation ([DioApiClient]) is
/// created at the application composition root and shared by every feature —
/// features never instantiate HTTP clients directly.
abstract class ApiClient {
  /// Sets (or clears, with `null`) the bearer token attached to subsequent
  /// requests as an `Authorization: Bearer <token>` header.
  ///
  /// This exists so that future auth features can transparently authenticate
  /// requests without managing header plumbing themselves.
  void setAuthToken(String? token);

  /// Performs an HTTP GET request to [path].
  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? headers,
  });

  /// Performs an HTTP POST request to [path] with an optional [body].
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });

  /// Performs an HTTP PUT request to [path] with an optional [body].
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });

  /// Performs an HTTP PATCH request to [path] with an optional [body].
  Future<NetworkResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });

  /// Performs an HTTP DELETE request to [path] with an optional [body].
  Future<NetworkResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  });
}

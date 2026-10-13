import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/config/app_environment.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/network_config.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/core/network/safe_log_interceptor.dart';
import 'package:payment_simulator/core/network/token_storage.dart';

/// Shared HTTP API client implementation backed by Dio.
///
/// A single instance is created at the application composition root
/// (`main.dart`) and reused by every feature (auth, payments, transactions,
/// …). Features never instantiate HTTP clients directly.
///
/// Responsibilities:
///  * base URL, default headers, and timeouts (from [AppEnvironment] /
///    [NetworkConfig]);
///  * JSON encoding/decoding and unwrapping of the backend success envelope;
///  * HTTP status-code handling with meaningful [AppException] failures;
///  * optional bearer-token authorization header;
///  * safe development logging (see [SafeLogInterceptor]).
///
/// Authentication (GO-SAAS dual-token contract):
///  * the short-lived access token is attached as `Authorization: Bearer …`
///    and persisted through the injected [AuthTokenStorage];
///  * the long-lived refresh token is delivered by the backend via an
///    `HttpOnly` `Set-Cookie` header. Because Flutter is not a browser, the
///    client captures it from `Set-Cookie` on login/refresh responses and
///    persists it through the same [AuthTokenStorage] — it is never exposed
///    outside the network layer;
///  * on HTTP 401 the client transparently refreshes the session (using the
///    backend-documented `X-Refresh-Token` header for non-browser clients),
///    persists the rotated tokens, and retries the original request once;
///  * concurrent requests that all receive a 401 share a single in-flight
///    refresh, and a failed refresh clears the stored tokens so the app falls
///    back to the unauthenticated state instead of looping forever.
class DioApiClient implements ApiClient {
  /// Builds a client around an injected [Dio] instance (used by tests) or a
  /// default-configured one.
  ///
  /// When [tokenStorage] is provided the client manages the GO-SAAS
  /// access/refresh token lifecycle (attach, persist, rotate, clear).
  DioApiClient({Dio? dio, AuthTokenStorage? tokenStorage})
      : _dio = dio ?? _buildDio(),
        // The parameter name (`tokenStorage`) differs from the private field
        // (`_tokenStorage`), so an initializing formal is not possible here.
        // ignore: prefer_initializing_formals
        _tokenStorage = tokenStorage;

  final Dio _dio;
  final AuthTokenStorage? _tokenStorage;

  /// In-memory cache of the access token (avoids a secure-storage round trip
  /// on every request). Mirrors the persisted token.
  String? _accessToken;

  /// In-flight refresh future. While non-null, additional 401s await this
  /// future instead of starting a competing refresh (single-flight).
  Future<void>? _refreshFuture;

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppEnvironment.apiBaseUrl,
        connectTimeout: NetworkConfig.connectionTimeout,
        receiveTimeout: NetworkConfig.receiveTimeout,
        sendTimeout: NetworkConfig.sendTimeout,
        headers: Map<String, dynamic>.of(NetworkConfig.defaultHeaders),
        // Bodies are decoded manually so that malformed JSON can be surfaced
        // as an [InvalidResponseException].
        responseType: ResponseType.plain,
        // Every status code is handled manually so that error envelopes can
        // be parsed and surfaced as [ApiException]s.
        validateStatus: (_) => true,
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(const SafeLogInterceptor());
    }

    return dio;
  }

  @override
  void setAuthToken(String? token) {
    _accessToken = token;
    // Persist alongside the in-memory cache so the token survives process
    // restarts. A null token clears the stored value.
    if (token == null) {
      _tokenStorage?.clear();
    } else {
      _tokenStorage?.saveAccessToken(token);
    }
  }

  @override
  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? headers,
  }) =>
      _request('GET', path, headers: headers);

  @override
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _request('POST', path, body: body, headers: headers);

  @override
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _request('PUT', path, body: body, headers: headers);

  @override
  Future<NetworkResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _request('PATCH', path, body: body, headers: headers);

  @override
  Future<NetworkResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      _request('DELETE', path, body: body, headers: headers);

  Future<NetworkResponse> _request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool allowRetry = true,
  }) async {
    try {
      final response = await _dio.request<dynamic>(
        path,
        data: body,
        options: Options(
          method: method,
          headers: await _buildHeaders(headers),
        ),
      );
      final networkResponse = _toNetworkResponse(response);
      await _persistTokensFromResponse(networkResponse, response);

      // On logout, clear any stored tokens so the app falls back to the
      // unauthenticated state.
      if (path == ApiEndpoints.logout) {
        _accessToken = null;
        await _tokenStorage?.clear();
      }

      if (networkResponse.statusCode == 401 && allowRetry) {
        return await _refreshAndRetry(
          () => _request(
            method,
            path,
            body: body,
            headers: headers,
            allowRetry: false,
          ),
        );
      }
      return networkResponse;
    } on ApiException catch (error) {
      // Error envelope with a 401 status (e.g. expired access token).
      if (error.statusCode == 401 && allowRetry) {
        return await _refreshAndRetry(
          () => _request(
            method,
            path,
            body: body,
            headers: headers,
            allowRetry: false,
          ),
        );
      }
      rethrow;
    } on DioException catch (error) {
      final mapped = _mapDioError(error);
      if (mapped is ApiException && mapped.statusCode == 401 && allowRetry) {
        return await _refreshAndRetry(
          () => _request(
            method,
            path,
            body: body,
            headers: headers,
            allowRetry: false,
          ),
        );
      }
      throw mapped;
    } on AppException {
      rethrow;
    } catch (error) {
      throw InvalidResponseException(
        'Unexpected response from server: $error',
      );
    }
  }

  /// Builds the request headers, attaching the bearer access token when one
  /// is available. The token is read from the in-memory cache, falling back
  /// to secure storage on first use.
  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? headers,
  ) async {
    final token = await _getAccessToken();
    return <String, String>{
      if (token != null) 'Authorization': 'Bearer $token',
      ...?headers,
    };
  }

  Future<String?> _getAccessToken() async {
    return _accessToken ??= await _tokenStorage?.accessToken;
  }

  /// Persists tokens found in a response:
  ///  * the access token from a login/refresh success envelope;
  ///  * the refresh token from any `Set-Cookie: refresh_token=…` header.
  Future<void> _persistTokensFromResponse(
    NetworkResponse networkResponse,
    Response<dynamic> response,
  ) async {
    final data = networkResponse.data;
    if (data is Map<String, dynamic>) {
      final accessToken = data['access_token'] as String?;
      if (accessToken != null && accessToken.isNotEmpty) {
        _accessToken = accessToken;
        await _tokenStorage?.saveAccessToken(accessToken);
      }
    }
    await _captureRefreshToken(response);
  }

  /// Extracts `refresh_token` from `Set-Cookie` response headers and persists
  /// it. The backend rotates the refresh token on every login/refresh, so
  /// the latest value always overwrites the previous one.
  Future<void> _captureRefreshToken(Response<dynamic> response) async {
    final cookies = response.headers.map['set-cookie'];
    if (cookies == null) return;
    for (final cookie in cookies) {
      final match = RegExp(r'refresh_token=([^;]+)').firstMatch(cookie);
      if (match != null) {
        final token = match.group(1)!;
        if (token.isNotEmpty) {
          await _tokenStorage?.saveRefreshToken(token);
        }
      }
    }
  }

  /// Handles a 401 by refreshing the session (single-flight) and retrying the
  /// original request with the rotated access token.
  Future<NetworkResponse> _refreshAndRetry(
    Future<NetworkResponse> Function() retry,
  ) async {
    await _refreshSession();
    return retry();
  }

  /// Refreshes the access token using the stored refresh token.
  ///
  /// Single-flight: concurrent callers share the same in-flight refresh. On
  /// failure the stored tokens are cleared so the app transitions to the
  /// unauthenticated state instead of retrying indefinitely.
  Future<void> _refreshSession() async {
    if (_refreshFuture != null) return _refreshFuture!;
    _refreshFuture = _doRefresh();
    try {
      await _refreshFuture!;
    } finally {
      _refreshFuture = null;
    }
  }

  /// Performs the actual refresh call. Uses the backend-documented
  /// `X-Refresh-Token` header (the non-browser client path) instead of
  /// relying on a cookie jar.
  Future<void> _doRefresh() async {
    final refreshToken = await _tokenStorage?.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      // Nothing to refresh with — clear any stale access token and let the
      // caller surface the original 401.
      _accessToken = null;
      await _tokenStorage?.clear();
      throw const ConnectionNetworkException(
        'Your session has expired. Please log in again.',
      );
    }

    try {
      final response = await _dio.request<dynamic>(
        ApiEndpoints.refresh,
        options: Options(
          method: 'POST',
          headers: {'X-Refresh-Token': refreshToken},
        ),
      );
      final networkResponse = _toNetworkResponse(response);
      await _persistTokensFromResponse(networkResponse, response);
    } on AppException {
      // Refresh failed (invalid/expired rotation, disabled account, …).
      // Clear local tokens so the app falls back to unauthenticated.
      _accessToken = null;
      await _tokenStorage?.clear();
      rethrow;
    } on DioException catch (error) {
      _accessToken = null;
      await _tokenStorage?.clear();
      throw _mapDioError(error);
    }
  }

  /// Converts a raw Dio [Response] into a [NetworkResponse], unwrapping the
  /// backend success envelope and throwing an [ApiException] for error
  /// envelopes.
  NetworkResponse _toNetworkResponse(Response<dynamic> response) {
    final decoded = _decodeBody(response.data);
    final statusCode = response.statusCode ?? 0;

    if (decoded is Map<String, dynamic>) {
      final success = decoded['success'];
      if (success == true) {
        return NetworkResponse(
          statusCode: statusCode,
          data: decoded['data'],
          meta: decoded['meta'],
        );
      }
      if (success == false) {
        final error = decoded['error'];
        final message = error is Map<String, dynamic>
            ? error['message'] as String?
            : null;
        final code = error is Map<String, dynamic>
            ? error['code'] as String?
            : null;
        throw ApiException(
          statusCode,
          message ?? 'The request could not be completed',
          code,
        );
      }
    }

    // Non-envelope payload (e.g. a plain health check from another server).
    return NetworkResponse(statusCode: statusCode, data: decoded);
  }

  dynamic _decodeBody(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return null;
      try {
        return jsonDecode(trimmed);
      } on FormatException {
        throw InvalidResponseException(
          'The server returned a non-JSON response',
        );
      }
    }
    return raw;
  }

  AppException _mapDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const NetworkTimeoutException();
      case DioExceptionType.connectionError:
        return const ConnectionNetworkException();
      case DioExceptionType.badCertificate:
        return const ConnectionNetworkException(
          'The server certificate could not be verified',
        );
      case DioExceptionType.badResponse:
        final response = error.response;
        if (response != null) {
          try {
            _toNetworkResponse(response);
          } on AppException catch (mapped) {
            return mapped;
          }
        }
        return const NetworkException(
          'The server returned an invalid response',
        );
      case DioExceptionType.cancel:
        return const NetworkException('The request was cancelled');
      case DioExceptionType.unknown:
        final cause = error.error;
        if (cause is AppException) return cause;
        return NetworkException(
          error.message ?? 'A network error occurred',
        );
    }
  }
}

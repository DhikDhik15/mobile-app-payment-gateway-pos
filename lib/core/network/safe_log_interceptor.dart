import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Development-only Dio interceptor that emits useful debugging logs while
/// never leaking secrets.
///
/// Safety guarantees:
///  * Request/response bodies are never logged (they may contain passwords,
///    payment credentials, or PII).
///  * Sensitive headers (authorization, cookies, API keys) are redacted.
class SafeLogInterceptor extends Interceptor {
  const SafeLogInterceptor();

  static const String _loggerName = 'ApiClient';

  static const Set<String> _sensitiveHeaders = {
    'authorization',
    'proxy-authorization',
    'cookie',
    'set-cookie',
    'x-api-key',
  };

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (kDebugMode) {
      developer.log(
        '${options.method} ${options.uri}',
        name: _loggerName,
      );
      developer.log(
        'headers: ${_redact(options.headers)}',
        name: _loggerName,
      );
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    if (kDebugMode) {
      developer.log(
        '${response.statusCode} ${response.requestOptions.method} '
        '${response.requestOptions.uri}',
        name: _loggerName,
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (kDebugMode) {
      developer.log(
        '${err.type} ${err.requestOptions.method} ${err.requestOptions.uri}',
        name: _loggerName,
        level: 1000,
      );
    }
    handler.next(err);
  }

  Map<String, Object?> _redact(Map<String, dynamic> headers) {
    return headers.map((key, value) {
      final isSensitive = _sensitiveHeaders.contains(key.toLowerCase());
      return MapEntry(key, isSensitive ? '***' : value);
    });
  }
}

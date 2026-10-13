import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:payment_simulator/core/config/app_environment.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/dio_api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';

/// A fake [HttpClientAdapter] that returns canned responses or throws
/// simulated Dio errors, so the client can be tested without a live backend.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this._handler);

  final Future<_FakeResponse> Function(RequestOptions options) _handler;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final fake = await _handler(options);
    return ResponseBody.fromString(
      fake.body,
      fake.statusCode,
      headers: fake.headers,
    );
  }

  @override
  void close({bool force = false}) {}
}

class _FakeResponse {
  const _FakeResponse(
    this.statusCode, {
    this.body = '',
    required this.headers,
  });

  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;
}

const _successEnvelope = '''
{"success":true,"data":{"status":"ok"},"meta":{"request_id":"req_test123"}}
''';

const _errorEnvelope = '''
{"success":false,"error":{"code":"VALIDATION_FAILED","message":"Invalid email address"},"meta":{}}
''';

Dio _dioWith(_FakeAdapter adapter) {
  final dio = Dio(
    BaseOptions(
      headers: const {'Content-Type': 'application/json'},
    ),
  );
  dio.httpClientAdapter = adapter;
  return dio;
}

void main() {
  group('DioApiClient', () {
    test('returns unwrapped data on a successful HTTP response', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(200, body: _successEnvelope, headers: {},),
      );
      final client = DioApiClient(dio: _dioWith(adapter));

      final response = await client.get('/health');

      expect(response, isA<NetworkResponse>());
      expect(response.statusCode, 200);
      expect(response.data, {'status': 'ok'});
      expect(adapter.requests.single.uri.path, '/health');
      expect(adapter.requests.single.method, 'GET');
    });

    test('throws ApiException with status and message on HTTP error',
        () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(400, body: _errorEnvelope, headers: {},),
      );
      final client = DioApiClient(dio: _dioWith(adapter));

      await expectLater(
        client.post('/api/v1/auth/login', body: {'email': 'bad'}),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 400)
              .having((e) => e.message, 'message', 'Invalid email address'),
        ),
      );
    });

    test('throws NetworkTimeoutException on timeout', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final client = DioApiClient(dio: _dioWith(adapter));

      await expectLater(
        client.get('/health'),
        throwsA(isA<NetworkTimeoutException>()),
      );
    });

    test('throws ConnectionNetworkException on connection failure',
        () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: const SocketException('Connection refused'),
        ),
      );
      final client = DioApiClient(dio: _dioWith(adapter));

      await expectLater(
        client.get('/health'),
        throwsA(isA<ConnectionNetworkException>()),
      );
    });

    test('throws InvalidResponseException on a non-JSON response', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(200, body: '<html>Not Found</html>', headers: {},),
      );
      final client = DioApiClient(dio: _dioWith(adapter));

      await expectLater(
        client.get('/health'),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('sends the bearer token after setAuthToken', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(200, body: _successEnvelope, headers: {},),
      );
      final client = DioApiClient(dio: _dioWith(adapter))
        ..setAuthToken('test-token-123');

      await client.get('/health');

      expect(
        adapter.requests.single.headers['Authorization'],
        'Bearer test-token-123',
      );
    });

    test('supports all HTTP verbs', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(200, body: _successEnvelope, headers: {},),
      );
      final client = DioApiClient(dio: _dioWith(adapter));

      await client.get('/resource');
      await client.post('/resource', body: {'a': 1});
      await client.put('/resource', body: {'a': 2});
      await client.patch('/resource', body: {'a': 3});
      await client.delete('/resource');

      expect(
        adapter.requests.map((r) => r.method),
        ['GET', 'POST', 'PUT', 'PATCH', 'DELETE'],
      );
    });

    test('encodes JSON request bodies', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(200, body: _successEnvelope, headers: {},),
      );
      final client = DioApiClient(dio: _dioWith(adapter));

      await client.post('/resource', body: {'email': 'a@b.c'});

      final body = adapter.requests.single.data;
      expect(body, {'email': 'a@b.c'});
    });

    test('default client uses the configured development base URL', () {
      // The effective base URL comes from .env (API_BASE_URL) — never a
      // hardcoded LAN IP.
      dotenv.testLoad(mergeWith: {'API_BASE_URL': 'http://test-server:8081'});
      final client = DioApiClient();
      expect(client, isA<ApiClient>());
      expect(AppEnvironment.apiBaseUrl, 'http://test-server:8081');
    });
  });
}

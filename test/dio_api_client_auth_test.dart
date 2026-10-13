import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/dio_api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/core/network/token_storage.dart';

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
    this.headers = const {},
  });

  final int statusCode;
  final String body;
  final Map<String, List<String>> headers;
}

const _loginEnvelope = '''
{"success":true,"data":{"access_token":"access-abc","expires_in":900,"token_type":"Bearer","user":{"id":"u1","email":"t@e.com","role":"OWNER","status":"ACTIVE","merchant_id":"m1"}},"meta":{}}
''';

const _refreshEnvelope = '''
{"success":true,"data":{"access_token":"access-new","expires_in":900,"token_type":"Bearer","user":{"id":"u1","email":"t@e.com","role":"OWNER","status":"ACTIVE","merchant_id":"m1"}},"meta":{}}
''';

const _error401 = '''
{"success":false,"error":{"code":"INVALID_CREDENTIALS","message":"Access token has expired"},"meta":{}}
''';

/// An in-memory [AuthTokenStorage] for tests.
class _FakeTokenStorage extends AuthTokenStorage {
  _FakeTokenStorage({this._accessToken, this._refreshToken});

  String? _accessToken;
  String? _refreshToken;

  @override
  Future<String?> get accessToken async => _accessToken;

  @override
  Future<String?> get refreshToken async => _refreshToken;

  @override
  Future<void> saveAccessToken(String token) async => _accessToken = token;

  @override
  Future<void> saveRefreshToken(String token) async => _refreshToken = token;

  @override
  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
  }
}

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
  group('DioApiClient authentication', () {
    test('login persists access token and captures refresh token from Set-Cookie',
        () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(
          200,
          body: _loginEnvelope,
          headers: {
            'set-cookie': [
              'refresh_token=refresh-xyz; Path=/api/v1/auth; Max-Age=604800; HttpOnly',
            ],
          },
        ),
      );
      final storage = _FakeTokenStorage();
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      final response = await client.post(
        ApiEndpoints.login,
        body: {'email': 't@e.com', 'password': 'pw'},
      );

      expect(response.statusCode, 200);
      expect((response.data as Map)['access_token'], 'access-abc');
      // Access token persisted.
      expect(await storage.accessToken, 'access-abc');
      // Refresh token captured from Set-Cookie and persisted.
      expect(await storage.refreshToken, 'refresh-xyz');
    });

    test('attaches the stored access token to subsequent requests', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(
          200,
          body: _loginEnvelope,
          headers: {
            'set-cookie': ['refresh_token=r1; Path=/api/v1/auth'],
          },
        ),
      );
      final storage = _FakeTokenStorage();
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      await client.post(ApiEndpoints.login, body: {'email': 't@e.com', 'password': 'pw'});
      await client.get(ApiEndpoints.me);

      expect(adapter.requests[1].headers['Authorization'], 'Bearer access-abc');
    });

    test('refreshes and retries once on 401', () async {
      var meCalls = 0;
      final adapter = _FakeAdapter((RequestOptions options) async {
        if (options.path == ApiEndpoints.refresh) {
          return const _FakeResponse(
            200,
            body: _refreshEnvelope,
            headers: {
              'set-cookie': ['refresh_token=refresh-new; Path=/api/v1/auth'],
            },
          );
        }
        // First /me call → 401, second (retry) → 200.
        meCalls++;
        if (meCalls == 1) {
          return const _FakeResponse(401, body: _error401);
        }
        return const _FakeResponse(
          200,
          body: '''
{"success":true,"data":{"id":"u1","email":"t@e.com","role":"OWNER","status":"ACTIVE","merchant_id":"m1"},"meta":{}}
''',
        );
      });
      final storage = _FakeTokenStorage(
        accessToken: 'stale-access',
        refreshToken: 'stored-refresh',
      );
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      final response = await client.get(ApiEndpoints.me);

      expect(response.statusCode, 200);
      // Refresh happened once, persisting the rotated tokens.
      expect(await storage.accessToken, 'access-new');
      expect(await storage.refreshToken, 'refresh-new');
      // The retried /me used the new access token.
      final meRetry = adapter.requests.last;
      expect(meRetry.headers['Authorization'], 'Bearer access-new');
      // Exactly one refresh call.
      expect(
        adapter.requests.where((r) => r.path == ApiEndpoints.refresh).length,
        1,
      );
    });

    test('does not retry more than once (no infinite loop)', () async {
      var refreshCalls = 0;
      final adapter = _FakeAdapter((RequestOptions options) async {
        if (options.path == ApiEndpoints.refresh) {
          refreshCalls++;
          return const _FakeResponse(401, body: _error401);
        }
        return const _FakeResponse(401, body: _error401);
      });
      final storage = _FakeTokenStorage(
        accessToken: 'stale',
        refreshToken: 'r',
      );
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      await expectLater(
        client.get(ApiEndpoints.me),
        throwsA(isA<ApiException>()),
      );

      // Only one refresh attempt, then it gives up.
      expect(refreshCalls, 1);
      // Tokens cleared after failed refresh.
      expect(await storage.accessToken, isNull);
      expect(await storage.refreshToken, isNull);
    });

    test('shares a single refresh across concurrent 401s', () async {
      var refreshCalls = 0;
      var refreshed = false;
      final adapter = _FakeAdapter((RequestOptions options) async {
        if (options.path == ApiEndpoints.refresh) {
          refreshCalls++;
          refreshed = true;
          return const _FakeResponse(
            200,
            body: _refreshEnvelope,
            headers: {
              'set-cookie': ['refresh_token=rotated; Path=/api/v1/auth'],
            },
          );
        }
        if (refreshed) {
          return const _FakeResponse(
            200,
            body: '{"success":true,"data":{"id":"u1"},"meta":{}}',
          );
        }
        return const _FakeResponse(401, body: _error401);
      });
      final storage = _FakeTokenStorage(
        accessToken: 'stale',
        refreshToken: 'r',
      );
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      // Fire three concurrent requests that all 401.
      final results = await Future.wait([
        client.get(ApiEndpoints.me).catchError((e) => e),
        client.get(ApiEndpoints.me).catchError((e) => e),
        client.get(ApiEndpoints.me).catchError((e) => e),
      ]);

      // All three retried with the new token and succeeded.
      for (final r in results) {
        expect(r, isA<NetworkResponse>());
        expect(r.statusCode, 200);
      }
      // Only one refresh happened despite three 401s.
      expect(refreshCalls, 1);
      expect(await storage.accessToken, 'access-new');
    });

    test('clears tokens when no refresh token is stored', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(401, body: _error401),
      );
      final storage = _FakeTokenStorage(accessToken: 'stale');
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      await expectLater(
        client.get(ApiEndpoints.me),
        throwsA(isA<ConnectionNetworkException>()),
      );

      expect(await storage.accessToken, isNull);
      expect(await storage.refreshToken, isNull);
    });

    test('maps a network failure during refresh to a network exception',
        () async {
      final adapter = _FakeAdapter((RequestOptions options) async {
        if (options.path == ApiEndpoints.refresh) {
          throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: const SocketException('refused'),
          );
        }
        return const _FakeResponse(401, body: _error401);
      });
      final storage = _FakeTokenStorage(
        accessToken: 'stale',
        refreshToken: 'r',
      );
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      await expectLater(
        client.get(ApiEndpoints.me),
        throwsA(isA<ConnectionNetworkException>()),
      );
    });

    test('logout clears stored tokens', () async {
      final adapter = _FakeAdapter(
        (RequestOptions options) async => const _FakeResponse(
          200,
          body: '{"success":true,"data":{},"meta":{}}',
        ),
      );
      final storage = _FakeTokenStorage(
        accessToken: 'a',
        refreshToken: 'r',
      );
      final client = DioApiClient(dio: _dioWith(adapter), tokenStorage: storage);

      await client.post(ApiEndpoints.logout);

      expect(await storage.accessToken, isNull);
      expect(await storage.refreshToken, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/home/data/repositories/backend_connectivity_repository_impl.dart';
import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';

/// A fake [ApiClient] that returns a canned response or throws a canned
/// error, so the repository mapping logic can be tested without a live
/// backend.
class _FakeApiClient implements ApiClient {
  _FakeApiClient({this.response, this.error});

  NetworkResponse? response;
  Object? error;
  String? requestedPath;

  @override
  void setAuthToken(String? token) {}

  @override
  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    requestedPath = path;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError();

  @override
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError();

  @override
  Future<NetworkResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError();

  @override
  Future<NetworkResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) =>
      throw UnimplementedError();
}

BackendConnectivityRepositoryImpl _repository(_FakeApiClient client) =>
    BackendConnectivityRepositoryImpl(client);

void main() {
  group('BackendConnectivityRepositoryImpl', () {
    test('returns connected status with HTTP status code on success', () async {
      final client = _FakeApiClient(
        response: const NetworkResponse(statusCode: 200, data: {'status': 'ok'}),
      );

      final status = await _repository(client).check();

      expect(client.requestedPath, ApiEndpoints.health);
      expect(
        status,
        isA<BackendConnected>()
            .having((s) => s.statusCode, 'statusCode', 200)
            .having((s) => s.latency, 'latency', isA<Duration>()),
      );
    });

    test('maps timeout to a timeout failure category', () async {
      final client = _FakeApiClient(error: const NetworkTimeoutException());

      final status = await _repository(client).check();

      expect(
        status,
        isA<BackendConnectionFailed>()
            .having((s) => s.category, 'category', BackendFailureCategory.timeout)
            .having((s) => s.message, 'message', isNotEmpty),
      );
    });

    test('maps connection error to a connection failure category', () async {
      final client = _FakeApiClient(
        error: const ConnectionNetworkException(),
      );

      final status = await _repository(client).check();

      expect(
        status,
        isA<BackendConnectionFailed>().having(
          (s) => s.category,
          'category',
          BackendFailureCategory.connection,
        ),
      );
    });

    test('maps ApiException to an httpError failure with status', () async {
      final client = _FakeApiClient(
        error: const ApiException(503, 'DB down'),
      );

      final status = await _repository(client).check();

      expect(
        status,
        isA<BackendConnectionFailed>()
            .having(
              (s) => s.category,
              'category',
              BackendFailureCategory.httpError,
            )
            .having((s) => s.message, 'message', contains('503')),
      );
    });

    test('maps invalid response to an invalidResponse failure category',
        () async {
      final client = _FakeApiClient(
        error: const InvalidResponseException(),
      );

      final status = await _repository(client).check();

      expect(
        status,
        isA<BackendConnectionFailed>().having(
          (s) => s.category,
          'category',
          BackendFailureCategory.invalidResponse,
        ),
      );
    });

    test('maps unexpected exceptions to the unknown failure category', () async {
      final client = _FakeApiClient(error: const CacheException());

      final status = await _repository(client).check();

      expect(
        status,
        isA<BackendConnectionFailed>().having(
          (s) => s.category,
          'category',
          BackendFailureCategory.unknown,
        ),
      );
    });
  });
}

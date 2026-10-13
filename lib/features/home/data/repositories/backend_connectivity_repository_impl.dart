import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';
import 'package:payment_simulator/features/home/domain/repositories/backend_connectivity_repository.dart';

/// Data-layer implementation of [BackendConnectivityRepository].
///
/// Calls the documented backend health endpoint through the shared
/// [ApiClient] and translates any [AppException] into a user-safe
/// [BackendConnectionFailed] — raw exceptions never escape this boundary.
class BackendConnectivityRepositoryImpl
    implements BackendConnectivityRepository {
  const BackendConnectivityRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<BackendConnectionStatus> check() async {
    final stopwatch = Stopwatch()..start();
    try {
      final response = await _apiClient.get(ApiEndpoints.health);
      return BackendConnected(
        statusCode: response.statusCode,
        latency: stopwatch.elapsed,
      );
    } on NetworkTimeoutException {
      return const BackendConnectionFailed(
        category: BackendFailureCategory.timeout,
        message:
            'The request timed out. Make sure the backend is running and '
            'that this device can reach the configured LAN address.',
      );
    } on ConnectionNetworkException {
      return const BackendConnectionFailed(
        category: BackendFailureCategory.connection,
        message:
            'Could not reach the backend. On a physical device, configure '
            'the backend URL at build time with '
            '--dart-define=API_BASE_URL=http://<ubuntu-lan-ip>:8081.',
      );
    } on ApiException catch (error) {
      return BackendConnectionFailed(
        category: BackendFailureCategory.httpError,
        message: 'HTTP ${error.statusCode}: ${error.message}',
      );
    } on InvalidResponseException {
      return const BackendConnectionFailed(
        category: BackendFailureCategory.invalidResponse,
        message: 'The backend returned an unexpected response.',
      );
    } on AppException {
      return const BackendConnectionFailed(
        category: BackendFailureCategory.unknown,
        message: 'An unexpected error occurred while connecting.',
      );
    }
  }
}

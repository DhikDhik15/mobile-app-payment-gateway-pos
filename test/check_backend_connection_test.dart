import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';
import 'package:payment_simulator/features/home/domain/repositories/backend_connectivity_repository.dart';
import 'package:payment_simulator/features/home/domain/usecases/check_backend_connection.dart';

class _FakeRepository implements BackendConnectivityRepository {
  _FakeRepository(this.status);

  final BackendConnectionStatus status;

  @override
  Future<BackendConnectionStatus> check() async => status;
}

void main() {
  group('CheckBackendConnectionUseCase', () {
    test('delegates to the repository and returns its status', () async {
      final useCase = CheckBackendConnectionUseCase(
        _FakeRepository(
          const BackendConnected(statusCode: 200, latency: Duration(milliseconds: 5)),
        ),
      );

      final status = await useCase(const NoParams());

      expect(status, isA<BackendConnected>());
      expect((status as BackendConnected).statusCode, 200);
    });

    test('propagates failure statuses from the repository', () async {
      final useCase = CheckBackendConnectionUseCase(
        _FakeRepository(
          const BackendConnectionFailed(
            category: BackendFailureCategory.timeout,
            message: 'timed out',
          ),
        ),
      );

      final status = await useCase(const NoParams());

      expect(status, isA<BackendConnectionFailed>());
    });
  });
}

import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';
import 'package:payment_simulator/features/home/domain/repositories/backend_connectivity_repository.dart';

/// Use case that verifies the app can reach the configured GO-SAAS backend.
///
/// Invoked from the Home presentation layer; delegates all network access to
/// the [BackendConnectivityRepository] abstraction.
class CheckBackendConnectionUseCase
    implements UseCase<BackendConnectionStatus, NoParams> {
  const CheckBackendConnectionUseCase(this._repository);

  final BackendConnectivityRepository _repository;

  @override
  Future<BackendConnectionStatus> call(NoParams params) => _repository.check();
}

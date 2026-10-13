import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';

/// Use case that restores a session at app startup.
///
/// Checks whether a valid authentication session exists in secure storage.
/// Returns `AuthSuccess(null)` when the user is unauthenticated.
class RestoreSessionUseCase
    implements UseCase<AuthResult<AuthSession?>, NoParams> {
  const RestoreSessionUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AuthResult<AuthSession?>> call(NoParams params) =>
      _repository.restoreSession();
}

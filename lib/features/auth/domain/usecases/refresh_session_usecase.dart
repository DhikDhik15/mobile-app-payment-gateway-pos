import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';

/// Use case that explicitly refreshes the access token.
///
/// Uses the stored refresh token; the backend rotates it on every call.
class RefreshSessionUseCase
    implements UseCase<AuthResult<AuthSession>, NoParams> {
  const RefreshSessionUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AuthResult<AuthSession>> call(NoParams params) =>
      _repository.refreshSession();
}

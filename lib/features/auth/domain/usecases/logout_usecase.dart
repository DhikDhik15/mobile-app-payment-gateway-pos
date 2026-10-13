import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';

/// Use case that logs out the current user.
///
/// Revokes the backend refresh session and clears locally stored tokens.
class LogoutUseCase implements UseCase<AuthResult<void>, NoParams> {
  const LogoutUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AuthResult<void>> call(NoParams params) => _repository.logout();
}

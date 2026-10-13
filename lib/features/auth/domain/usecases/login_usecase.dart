import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';

/// Use case that authenticates a user with the GO-SAAS backend.
class LoginUseCase implements UseCase<AuthResult<AuthSession>, LoginParams> {
  const LoginUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<AuthResult<AuthSession>> call(LoginParams params) =>
      _repository.login(params.email, params.password);
}

/// Parameters for [LoginUseCase].
class LoginParams {
  const LoginParams({required this.email, required this.password});

  final String email;
  final String password;
}

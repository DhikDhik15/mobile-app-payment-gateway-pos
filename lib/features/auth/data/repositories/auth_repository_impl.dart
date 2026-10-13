import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/core/network/token_storage.dart';
import 'package:payment_simulator/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';

/// Data-layer implementation of [AuthRepository].
///
/// Delegates HTTP access to [AuthRemoteDataSource] (which uses the shared
/// core `ApiClient`) and translates any [AppException] into a domain
/// [Failure] — raw exceptions never escape this boundary.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remote, this._tokenStorage);

  final AuthRemoteDataSource _remote;
  final AuthTokenStorage _tokenStorage;

  @override
  Future<AuthResult<AuthSession>> login(String email, String password) async {
    try {
      final session = await _remote.login(email, password);
      return AuthSuccess(session.toEntity());
    } on AppException catch (error) {
      return AuthError(_mapError(error));
    }
  }

  @override
  Future<AuthResult<void>> logout() async {
    try {
      await _remote.logout();
      // Ensure local tokens are cleared even if the backend call fails
      // (e.g. the session was already revoked server-side).
      await _tokenStorage.clear();
      return const AuthSuccess(null);
    } on AppException catch (error) {
      await _tokenStorage.clear();
      return AuthError(_mapError(error));
    }
  }

  @override
  Future<AuthResult<AuthSession?>> restoreSession() async {
    try {
      // Without a stored refresh token there is nothing to restore.
      final refreshToken = await _tokenStorage.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        return const AuthSuccess(null);
      }

      // The client attaches the stored access token and transparently
      // refreshes + retries on 401. If the refresh fails it clears the
      // stored tokens, so a subsequent read returns null.
      final user = await _remote.me();
      final accessToken = await _tokenStorage.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        return const AuthSuccess(null);
      }
      return AuthSuccess(
        AuthSession(
          accessToken: accessToken,
          user: user,
          expiresIn: 0,
        ),
      );
    } on AppException {
      // Refresh failed / session invalid — tokens are already cleared by the
      // client. Treat as unauthenticated rather than an error.
      return const AuthSuccess(null);
    }
  }

  @override
  Future<AuthResult<AuthSession>> refreshSession() async {
    try {
      final session = await _remote.refresh();
      return AuthSuccess(session.toEntity());
    } on AppException catch (error) {
      return AuthError(_mapError(error));
    }
  }

  /// Maps a network-layer [AppException] to a domain [Failure] with a
  /// user-safe message.
  Failure _mapError(AppException error) {
    return switch (error) {
      NetworkTimeoutException() => const TimeoutFailure(),
      ConnectionNetworkException() => const ConnectionFailure(),
      ApiException() => ApiFailure(error.statusCode, error.message),
      InvalidResponseException() => const InvalidResponseFailure(),
      _ => const ServerFailure(),
    };
  }
}

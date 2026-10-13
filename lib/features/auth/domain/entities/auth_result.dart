import 'package:payment_simulator/core/error/failure.dart';

/// Result of an authentication use case.
///
/// A sealed type so the presentation layer can exhaustively handle success
/// and failure without catching exceptions. The failure variant carries a
/// domain [Failure] whose [Failure.message] is always user-safe (never a
/// raw exception or stack trace).
sealed class AuthResult<T> {
  const AuthResult();
}

/// The use case succeeded.
final class AuthSuccess<T> extends AuthResult<T> {
  const AuthSuccess(this.value);

  final T value;
}

/// The use case failed with a user-safe, domain-level failure.
final class AuthError<T> extends AuthResult<T> {
  const AuthError(this.failure);

  final Failure failure;
}

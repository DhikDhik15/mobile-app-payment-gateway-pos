/// Base abstraction for all domain-level failures.
///
/// Failures represent expected, recoverable error conditions that can be
/// propagated from the data layer up to the presentation layer.
sealed class Failure {
  const Failure(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A failure caused by an error on the server side.
final class ServerFailure extends Failure {
  const ServerFailure([super.message = 'A server error occurred']);
}

/// A failure caused by a network connectivity issue.
final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'A network error occurred']);
}

/// A failure caused by a local cache read/write error.
final class CacheFailure extends Failure {
  const CacheFailure([super.message = 'A cache error occurred']);
}

/// A failure caused by invalid user input or validation rules.
final class ValidationFailure extends Failure {
  const ValidationFailure([super.message = 'A validation error occurred']);
}

/// A failure caused by a request that exceeded its timeout.
final class TimeoutFailure extends Failure {
  const TimeoutFailure([super.message = 'The request timed out']);
}

/// A failure caused by the backend being unreachable.
final class ConnectionFailure extends Failure {
  const ConnectionFailure([super.message = 'Could not reach the server']);
}

/// A failure caused by a non-success HTTP status code.
final class ApiFailure extends Failure {
  const ApiFailure(this.statusCode, [super.message = 'The server returned an error', this.code]);

  final int statusCode;

  /// Stable backend error code when the server provided one.
  final String? code;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

/// A failure caused by an undecodable server response.
final class InvalidResponseFailure extends Failure {
  const InvalidResponseFailure([super.message = 'The server returned an invalid response']);
}

/// A failure that does not fit into any other category.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure([super.message = 'An unexpected error occurred']);
}

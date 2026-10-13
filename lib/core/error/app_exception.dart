/// Base application exception.
///
/// Exceptions represent unexpected error conditions that are typically
/// caught and converted to [Failure] instances at the data layer boundary.
/// The network layer throws the network-specific subtypes below; raw HTTP
/// library exceptions (e.g. DioException) never escape the API client.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// An exception caused by an error on the server side.
class ServerException extends AppException {
  const ServerException([super.message = 'A server error occurred']);
}

/// An exception caused by a network connectivity issue.
class NetworkException extends AppException {
  const NetworkException([super.message = 'A network error occurred']);
}

/// An exception caused by a local cache read/write error.
class CacheException extends AppException {
  const CacheException([super.message = 'A cache error occurred']);
}

/// An exception thrown when a request exceeds its timeout.
class NetworkTimeoutException extends AppException {
  const NetworkTimeoutException([
    super.message = 'The request timed out. Please try again.',
  ]);
}

/// An exception thrown when the backend cannot be reached at all
/// (DNS failure, refused connection, no route, untrusted certificate, …).
class ConnectionNetworkException extends AppException {
  const ConnectionNetworkException([
    super.message = 'Could not reach the server. Please check your connection.',
  ]);
}

/// An exception thrown when the server answers with a non-success status
/// code. Carries the HTTP [statusCode] and the message from the backend's
/// error envelope when available.
class ApiException extends AppException {
  const ApiException(this.statusCode, [super.message = 'The server returned an error', this.code]);

  final int statusCode;

  /// Stable backend error code from the error envelope (e.g.
  /// `INVALID_TRANSACTION_STATE`, `PAYMENT_PROVIDER_TIMEOUT`), when present.
  /// Prefer this over parsing [message] for control flow.
  final String? code;

  @override
  String toString() => '$runtimeType($statusCode): $message';
}

/// An exception thrown when the server response cannot be decoded as the
/// expected JSON structure.
class InvalidResponseException extends AppException {
  const InvalidResponseException([
    super.message = 'The server returned an invalid response',
  ]);
}

/// Status of the development-only backend connectivity check.
///
/// This is a sealed hierarchy so the presentation layer can exhaustively
/// render every state.
sealed class BackendConnectionStatus {
  const BackendConnectionStatus();
}

/// The connectivity check has not run yet.
final class BackendNotChecked extends BackendConnectionStatus {
  const BackendNotChecked();
}

/// The connectivity check is currently in flight.
final class BackendChecking extends BackendConnectionStatus {
  const BackendChecking();
}

/// The backend responded successfully.
final class BackendConnected extends BackendConnectionStatus {
  const BackendConnected({required this.statusCode, required this.latency});

  /// The HTTP status code returned by the backend.
  final int statusCode;

  /// How long the round trip took.
  final Duration latency;
}

/// The connectivity check failed.
final class BackendConnectionFailed extends BackendConnectionStatus {
  const BackendConnectionFailed({required this.category, required this.message});

  /// Coarse-grained failure category for display and diagnostics.
  final BackendFailureCategory category;

  /// Human-readable, user-safe explanation (never a raw stack trace).
  final String message;
}

/// Coarse-grained connectivity failure categories.
enum BackendFailureCategory {
  timeout,
  connection,
  httpError,
  invalidResponse,
  unknown,
}

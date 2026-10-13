import '../entities/auth_result.dart';
import '../entities/auth_session.dart';

/// Contract for authentication operations.
///
/// The domain layer depends on this abstraction. The data layer provides the
/// concrete implementation, which delegates HTTP access to the shared core
/// `ApiClient`.
abstract class AuthRepository {
  /// Authenticates a user with [email] and [password].
  ///
  /// On success the backend returns a short-lived access token and sets an
  /// HttpOnly refresh-token cookie; the data layer persists both through the
  /// network layer's secure token storage.
  Future<AuthResult<AuthSession>> login(String email, String password);

  /// Logs out the current user by revoking the backend refresh session and
  /// clearing locally stored tokens.
  Future<AuthResult<void>> logout();

  /// Attempts to restore a session from locally stored tokens.
  ///
  /// Returns `AuthSuccess(null)` when no session can be restored (no stored
  /// refresh token, or the refresh failed). On success the returned session
  /// carries a valid access token and the current user.
  Future<AuthResult<AuthSession?>> restoreSession();

  /// Explicitly refreshes the access token using the stored refresh token.
  ///
  /// The backend rotates the refresh token on every call; the data layer
  /// persists the rotated pair.
  Future<AuthResult<AuthSession>> refreshSession();
}

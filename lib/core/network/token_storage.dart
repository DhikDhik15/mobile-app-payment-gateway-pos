/// Secure storage abstraction for authentication tokens.
///
/// The GO-SAAS backend delivers a short-lived access token in the response
/// body and a long-lived refresh token via an `HttpOnly` `Set-Cookie` header
/// (see `AuthHandler`). Because Flutter is not a browser, the refresh token
/// is captured from `Set-Cookie` at login/refresh time and persisted through
/// this abstraction instead of relying on a cookie jar.
///
/// Implementations MUST store tokens in platform-backed secure storage
/// (Android Keystore / iOS Keychain). Tokens must never be written to
/// SharedPreferences, plain files, logs, or compile-time constants.
abstract class AuthTokenStorage {
  const AuthTokenStorage();

  /// The persisted access token, or `null` when absent.
  Future<String?> get accessToken;

  /// The persisted refresh token, or `null` when absent.
  Future<String?> get refreshToken;

  /// Persists a new access token (e.g. after login or refresh rotation).
  Future<void> saveAccessToken(String token);

  /// Persists a new refresh token (delivered via `Set-Cookie`).
  Future<void> saveRefreshToken(String token);

  /// Clears all stored tokens (logout / failed refresh).
  Future<void> clear();
}

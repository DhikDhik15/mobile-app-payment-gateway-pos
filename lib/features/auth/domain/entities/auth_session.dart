import 'auth_user.dart';

/// Domain entity representing an authenticated session.
///
/// Holds the short-lived access token and the authenticated user. The
/// long-lived refresh token is intentionally NOT part of this entity — it
/// lives only inside the network layer's secure [AuthTokenStorage] and is
/// never exposed to the domain or presentation layers.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    required this.expiresIn,
  });

  /// The short-lived access token (JWT) used as `Authorization: Bearer …`.
  final String accessToken;

  /// The authenticated user.
  final AuthUser user;

  /// Lifetime of [accessToken] in seconds (mirrors the backend `expires_in`).
  final int expiresIn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          other.accessToken == accessToken &&
          other.user == user &&
          other.expiresIn == expiresIn;

  @override
  int get hashCode => Object.hash(accessToken, user, expiresIn);
}

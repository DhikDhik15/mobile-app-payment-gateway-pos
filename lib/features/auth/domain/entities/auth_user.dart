/// Domain entity representing an authenticated dashboard user.
///
/// Mirrors the GO-SAAS `DashboardUserResponse` contract. This is a pure
/// domain object with no dependency on Flutter, Dio, or any serialization
/// framework. API-specific serialization is handled by the corresponding data
/// model (`AuthUserModel`).
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.role,
    required this.status,
    required this.merchantId,
    this.lastLoginAt,
    this.createdAt,
    this.updatedAt,
  });

  /// The user's unique identifier (UUID).
  final String id;

  /// The user's email address (also the login identifier).
  final String email;

  /// The user's dashboard role (`OWNER`, `ADMIN`, `VIEWER`).
  final String role;

  /// The user's account status (`ACTIVE`, `DISABLED`).
  final String status;

  /// The merchant (tenant) this user belongs to.
  final String merchantId;

  /// When the user last logged in, if known.
  final DateTime? lastLoginAt;

  /// When the user was created.
  final DateTime? createdAt;

  /// When the user was last updated.
  final DateTime? updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthUser &&
          other.id == id &&
          other.email == email &&
          other.role == role &&
          other.status == status &&
          other.merchantId == merchantId;

  @override
  int get hashCode => Object.hash(id, email, role, status, merchantId);
}

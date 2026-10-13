import '../../domain/entities/auth_user.dart';

/// Data model for [AuthUser] that handles JSON serialization.
///
/// Maps the GO-SAAS `DashboardUserResponse` payload. Extends the domain
/// entity so it can be used interchangeably in the domain layer while
/// providing serialization capabilities.
class AuthUserModel extends AuthUser {
  const AuthUserModel({
    required super.id,
    required super.email,
    required super.role,
    required super.status,
    required super.merchantId,
    super.lastLoginAt,
    super.createdAt,
    super.updatedAt,
  });

  factory AuthUserModel.fromJson(Map<String, dynamic> json) {
    return AuthUserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
      merchantId: json['merchant_id'] as String,
      lastLoginAt: _parseDateTime(json['last_login_at']),
      createdAt: _parseDateTime(json['created_at']),
      updatedAt: _parseDateTime(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'status': status,
      'merchant_id': merchantId,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

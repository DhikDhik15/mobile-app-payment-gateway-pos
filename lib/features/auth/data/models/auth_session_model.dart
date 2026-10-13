import '../../domain/entities/auth_session.dart';
import 'auth_user_model.dart';

/// Data model for [AuthSession] that handles JSON serialization.
///
/// Maps the GO-SAAS `LoginResponse` payload (the unwrapped `data` field of
/// the success envelope). The refresh token is NOT part of this model — it
/// is delivered via `Set-Cookie` and persisted directly by the network layer.
class AuthSessionModel {
  const AuthSessionModel({
    required this.accessToken,
    required this.expiresIn,
    required this.tokenType,
    required this.user,
  });

  factory AuthSessionModel.fromJson(Map<String, dynamic> json) {
    return AuthSessionModel(
      accessToken: json['access_token'] as String,
      expiresIn: json['expires_in'] as int,
      tokenType: json['token_type'] as String? ?? 'Bearer',
      user: AuthUserModel.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  final String accessToken;
  final int expiresIn;
  final String tokenType;
  final AuthUserModel user;

  AuthSession toEntity() {
    return AuthSession(
      accessToken: accessToken,
      expiresIn: expiresIn,
      user: user,
    );
  }
}

import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/auth/data/models/auth_session_model.dart';
import 'package:payment_simulator/features/auth/data/models/auth_user_model.dart';

/// Contract for remote authentication data sources.
///
/// Implementations handle actual HTTP calls through the shared core
/// [ApiClient].
abstract class AuthRemoteDataSource {
  const AuthRemoteDataSource();

  /// `POST /api/v1/auth/login`
  ///
  /// Returns the session (access token + user). The client persists the
  /// access token and the `Set-Cookie` refresh token automatically.
  Future<AuthSessionModel> login(String email, String password);

  /// `POST /api/v1/auth/logout`
  ///
  /// The client attaches the current access token (the backend prefers the
  /// stable `sid` claim) and clears local tokens afterwards.
  Future<void> logout();

  /// `POST /api/v1/auth/refresh`
  ///
  /// Uses the stored refresh token via the `X-Refresh-Token` header (the
  /// backend-documented non-browser client path). The client persists the
  /// rotated token pair.
  Future<AuthSessionModel> refresh();

  /// `GET /api/v1/auth/me`
  ///
  /// Returns the current user. The client attaches the access token and
  /// transparently refreshes + retries on 401.
  Future<AuthUserModel> me();
}

/// HTTP implementation of [AuthRemoteDataSource] backed by the shared core
/// [ApiClient].
class AuthRemoteDataSourceImpl extends AuthRemoteDataSource {
  const AuthRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<AuthSessionModel> login(String email, String password) async {
    final response = await _apiClient.post(
      ApiEndpoints.login,
      body: {'email': email, 'password': password},
    );
    return _parseSession(response);
  }

  @override
  Future<void> logout() async {
    await _apiClient.post(ApiEndpoints.logout);
  }

  @override
  Future<AuthSessionModel> refresh() async {
    final response = await _apiClient.post(ApiEndpoints.refresh);
    return _parseSession(response);
  }

  @override
  Future<AuthUserModel> me() async {
    final response = await _apiClient.get(ApiEndpoints.me);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException();
    }
    return AuthUserModel.fromJson(data);
  }

  AuthSessionModel _parseSession(NetworkResponse response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException();
    }
    return AuthSessionModel.fromJson(data);
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:payment_simulator/core/network/token_storage.dart';

/// Secure [AuthTokenStorage] backed by `flutter_secure_storage`.
///
/// On Android this uses the Android Keystore; on iOS the iOS Keychain.
/// Tokens are never written to SharedPreferences, plain files, or logs.
class SecureTokenStorage extends AuthTokenStorage {
  const SecureTokenStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  static const String _accessTokenKey = 'auth_access_token';
  static const String _refreshTokenKey = 'auth_refresh_token';

  @override
  Future<String?> get accessToken => _storage.read(key: _accessTokenKey);

  @override
  Future<String?> get refreshToken => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> saveAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  @override
  Future<void> saveRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  @override
  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}

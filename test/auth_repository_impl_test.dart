import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/core/network/token_storage.dart';
import 'package:payment_simulator/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:payment_simulator/features/auth/data/models/auth_session_model.dart';
import 'package:payment_simulator/features/auth/data/models/auth_user_model.dart';
import 'package:payment_simulator/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';

/// A fake [AuthRemoteDataSource] that returns canned results or throws
/// canned errors, so the repository mapping logic can be tested without a
/// live backend.
class _FakeDataSource extends AuthRemoteDataSource {
  _FakeDataSource({this.session, this.error, this.user});

  AuthSessionModel? session;
  AuthUserModel? user;
  Object? error;
  int loginCalls = 0;
  int logoutCalls = 0;
  int refreshCalls = 0;
  int meCalls = 0;

  @override
  Future<AuthSessionModel> login(String email, String password) async {
    loginCalls++;
    if (error != null) throw error!;
    return session!;
  }

  @override
  Future<void> logout() async {
    logoutCalls++;
    if (error != null) throw error!;
  }

  @override
  Future<AuthSessionModel> refresh() async {
    refreshCalls++;
    if (error != null) throw error!;
    return session!;
  }

  @override
  Future<AuthUserModel> me() async {
    meCalls++;
    if (error != null) throw error!;
    return user!;
  }
}

/// An in-memory [AuthTokenStorage] for tests.
class _FakeTokenStorage extends AuthTokenStorage {
  _FakeTokenStorage({this._accessToken, this._refreshToken});

  String? _accessToken;
  String? _refreshToken;
  int clearCalls = 0;

  @override
  Future<String?> get accessToken async => _accessToken;

  @override
  Future<String?> get refreshToken async => _refreshToken;

  @override
  Future<void> saveAccessToken(String token) async => _accessToken = token;

  @override
  Future<void> saveRefreshToken(String token) async => _refreshToken = token;

  @override
  Future<void> clear() async {
    clearCalls++;
    _accessToken = null;
    _refreshToken = null;
  }
}

AuthSessionModel _session() => AuthSessionModel.fromJson({
      'access_token': 'access-123',
      'expires_in': 900,
      'token_type': 'Bearer',
      'user': {
        'id': 'u1',
        'email': 'test@example.com',
        'role': 'OWNER',
        'status': 'ACTIVE',
        'merchant_id': 'm1',
        'created_at': '2026-01-01T00:00:00Z',
        'updated_at': '2026-01-01T00:00:00Z',
      },
    });

AuthUserModel _user() => AuthUserModel.fromJson({
      'id': 'u1',
      'email': 'test@example.com',
      'role': 'OWNER',
      'status': 'ACTIVE',
      'merchant_id': 'm1',
      'created_at': '2026-01-01T00:00:00Z',
      'updated_at': '2026-01-01T00:00:00Z',
    });

void main() {
  group('AuthRepositoryImpl', () {
    test('login returns a session on success', () async {
      final remote = _FakeDataSource(session: _session());
      final storage = _FakeTokenStorage();
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.login('test@example.com', 'pw');

      expect(result, isA<AuthSuccess<AuthSession>>());
      final session = (result as AuthSuccess<AuthSession>).value;
      expect(session.accessToken, 'access-123');
      expect(session.user.email, 'test@example.com');
      expect(remote.loginCalls, 1);
    });

    test('login maps ApiException to ApiFailure', () async {
      final remote = _FakeDataSource(error: const ApiException(401, 'Invalid email or password'));
      final storage = _FakeTokenStorage();
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.login('test@example.com', 'wrong');

      expect(result, isA<AuthError<AuthSession>>());
      final failure = (result as AuthError<AuthSession>).failure;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 401);
      expect(failure.message, 'Invalid email or password');
    });

    test('login maps timeout to TimeoutFailure', () async {
      final remote = _FakeDataSource(error: const NetworkTimeoutException());
      final storage = _FakeTokenStorage();
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.login('test@example.com', 'pw');

      expect((result as AuthError<AuthSession>).failure, isA<TimeoutFailure>());
    });

    test('login maps connection error to ConnectionFailure', () async {
      final remote = _FakeDataSource(error: const ConnectionNetworkException());
      final storage = _FakeTokenStorage();
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.login('test@example.com', 'pw');

      expect(
        (result as AuthError<AuthSession>).failure,
        isA<ConnectionFailure>(),
      );
    });

    test('logout clears tokens and returns success', () async {
      final remote = _FakeDataSource();
      final storage = _FakeTokenStorage(
        accessToken: 'a',
        refreshToken: 'r',
      );
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.logout();

      expect(result, isA<AuthSuccess<void>>());
      expect(remote.logoutCalls, 1);
      expect(storage.clearCalls, 1);
      expect(await storage.accessToken, isNull);
      expect(await storage.refreshToken, isNull);
    });

    test('logout clears tokens even when the backend call fails', () async {
      final remote = _FakeDataSource(error: const ApiException(500, 'boom'));
      final storage = _FakeTokenStorage(
        accessToken: 'a',
        refreshToken: 'r',
      );
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.logout();

      expect(result, isA<AuthError<void>>());
      expect(storage.clearCalls, 1);
      expect(await storage.accessToken, isNull);
    });

    test('restoreSession returns null when no refresh token is stored',
        () async {
      final remote = _FakeDataSource();
      final storage = _FakeTokenStorage();
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.restoreSession();

      expect(result, isA<AuthSuccess<AuthSession?>>());
      expect((result as AuthSuccess<AuthSession?>).value, isNull);
      expect(remote.meCalls, 0);
    });

    test('restoreSession returns a session when me succeeds', () async {
      final remote = _FakeDataSource(user: _user());
      final storage = _FakeTokenStorage(
        accessToken: 'stored-access',
        refreshToken: 'stored-refresh',
      );
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.restoreSession();

      expect(result, isA<AuthSuccess<AuthSession?>>());
      final session = (result as AuthSuccess<AuthSession?>).value;
      expect(session, isNotNull);
      expect(session!.accessToken, 'stored-access');
      expect(session.user.email, 'test@example.com');
      expect(remote.meCalls, 1);
    });

    test('restoreSession returns null when me fails (refresh failed)',
        () async {
      final remote = _FakeDataSource(error: const ApiException(401, 'expired'));
      final storage = _FakeTokenStorage(
        accessToken: 'stored-access',
        refreshToken: 'stored-refresh',
      );
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.restoreSession();

      expect(result, isA<AuthSuccess<AuthSession?>>());
      expect((result as AuthSuccess<AuthSession?>).value, isNull);
    });

    test('refreshSession returns a new session on success', () async {
      final remote = _FakeDataSource(session: _session());
      final storage = _FakeTokenStorage(refreshToken: 'r');
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.refreshSession();

      expect(result, isA<AuthSuccess<AuthSession>>());
      expect((result as AuthSuccess<AuthSession>).value.accessToken, 'access-123');
      expect(remote.refreshCalls, 1);
    });

    test('refreshSession maps failure to AuthError', () async {
      final remote = _FakeDataSource(error: const ApiException(401, 'Invalid or expired refresh token'));
      final storage = _FakeTokenStorage(refreshToken: 'r');
      final repo = AuthRepositoryImpl(remote, storage);

      final result = await repo.refreshSession();

      expect(result, isA<AuthError<AuthSession>>());
      final failure = (result as AuthError<AuthSession>).failure;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 401);
    });
  });
}

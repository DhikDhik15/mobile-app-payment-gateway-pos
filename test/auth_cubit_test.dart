import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_user.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';
import 'package:payment_simulator/features/auth/domain/usecases/login_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/logout_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:payment_simulator/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart_item.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';

/// A fake [AuthRepository] with configurable results.
class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.loginResult,
    this.logoutResult,
    this.restoreResult,
  });

  AuthResult<AuthSession>? loginResult;
  AuthResult<void>? logoutResult;
  AuthResult<AuthSession?>? restoreResult;
  AuthResult<AuthSession>? refreshResult;

  @override
  Future<AuthResult<AuthSession>> login(String email, String password) async {
    return loginResult ?? AuthError(const ServerFailure());
  }

  @override
  Future<AuthResult<void>> logout() async {
    return logoutResult ?? AuthError(const ServerFailure());
  }

  @override
  Future<AuthResult<AuthSession?>> restoreSession() async {
    return restoreResult ?? const AuthSuccess(null);
  }

  @override
  Future<AuthResult<AuthSession>> refreshSession() async {
    return refreshResult ?? AuthError(const ServerFailure());
  }
}

AuthSession _session() => AuthSession(
  accessToken: 'access-123',
  expiresIn: 900,
  user: const AuthUser(
    id: 'u1',
    email: 'test@example.com',
    role: 'OWNER',
    status: 'ACTIVE',
    merchantId: 'm1',
  ),
);

AuthCubit _cubit(_FakeAuthRepository repo) => AuthCubit(
  restoreSession: RestoreSessionUseCase(repo),
  login: LoginUseCase(repo),
  logout: LogoutUseCase(repo),
);

void main() {
  group('AuthCubit', () {
    test('starts in AuthInitial', () {
      final cubit = _cubit(_FakeAuthRepository());
      expect(cubit.state, isA<AuthInitial>());
    });

    test(
      'checkSession emits authenticated when a session is restored',
      () async {
        final repo = _FakeAuthRepository(
          restoreResult: AuthSuccess(_session()),
        );
        final cubit = _cubit(repo);

        await cubit.checkSession();

        expect(cubit.state, isA<AuthAuthenticated>());
        expect(
          (cubit.state as AuthAuthenticated).session.user.email,
          'test@example.com',
        );
      },
    );

    test(
      'checkSession emits unauthenticated when no session is restored',
      () async {
        final repo = _FakeAuthRepository(
          restoreResult: const AuthSuccess(null),
        );
        final cubit = _cubit(repo);

        await cubit.checkSession();

        expect(cubit.state, isA<AuthUnauthenticated>());
      },
    );

    test('checkSession emits unauthenticated when restoration fails', () async {
      final repo = _FakeAuthRepository(
        restoreResult: AuthError(const ConnectionFailure()),
      );
      final cubit = _cubit(repo);

      await cubit.checkSession();

      expect(cubit.state, isA<AuthUnauthenticated>());
    });

    test('signIn emits authenticated on success', () async {
      final repo = _FakeAuthRepository(loginResult: AuthSuccess(_session()));
      final cubit = _cubit(repo);

      await cubit.signIn('test@example.com', 'pw');

      expect(cubit.state, isA<AuthAuthenticated>());
    });

    test('signIn emits failure then unauthenticated on error', () async {
      final repo = _FakeAuthRepository(
        loginResult: AuthError(
          const ApiFailure(401, 'Invalid email or password'),
        ),
      );
      final cubit = _cubit(repo);
      final states = <AuthState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.signIn('test@example.com', 'wrong');
      // Flush stream events.
      await Future<void>.delayed(Duration.zero);

      // The last state is unauthenticated (so the login form stays usable).
      expect(cubit.state, isA<AuthUnauthenticated>());
      // A failure state was emitted in between.
      expect(states.any((s) => s is AuthFailure), isTrue);
      final failure = states.whereType<AuthFailure>().first;
      expect(failure.message, 'Invalid email or password');
      await sub.cancel();
    });

    test('signOut emits unauthenticated on success', () async {
      final repo = _FakeAuthRepository(logoutResult: const AuthSuccess(null));
      final cubit = _cubit(repo);

      await cubit.signOut();

      expect(cubit.state, isA<AuthUnauthenticated>());
    });

    test('signOut clears the shared local cart on logout', () async {
      final repo = _FakeAuthRepository(logoutResult: const AuthSuccess(null));
      final cartCubit = CartCubit();
      final cubit = AuthCubit(
        restoreSession: RestoreSessionUseCase(repo),
        login: LoginUseCase(repo),
        logout: LogoutUseCase(repo),
        cartCubit: cartCubit,
      );

      cartCubit.add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 1,
          unitPrice: 15000,
        ),
      );

      await cubit.signOut();

      expect(cartCubit.state, const Cart());
      expect(cubit.state, isA<AuthUnauthenticated>());
      addTearDown(cartCubit.close);
    });

    test(
      'signOut stays unauthenticated even when the backend call fails',
      () async {
        final repo = _FakeAuthRepository(
          logoutResult: AuthError(const ServerFailure()),
        );
        final cubit = _cubit(repo);

        await cubit.signOut();

        expect(cubit.state, isA<AuthUnauthenticated>());
      },
    );
  });
}

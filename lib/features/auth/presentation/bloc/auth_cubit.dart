import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';
import 'package:payment_simulator/features/auth/domain/usecases/login_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/logout_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';

/// Cubit that manages the authentication state machine.
///
/// States:
///  * [AuthInitial]           — app just launched, no check yet;
///  * [AuthCheckingSession]   — verifying a stored session at startup;
///  * [AuthAuthenticated]     — a valid session exists;
///  * [AuthUnauthenticated]   — no valid session;
///  * [AuthLoading]           — a login/logout request is in flight;
///  * [AuthFailure]           — the last request failed (user-safe message).
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({
    required this.restoreSession,
    required this.login,
    required this.logout,
    CartCubit? cartCubit,
  }) : super(const AuthInitial()) {
    _cartCubit = cartCubit;
  }

  final RestoreSessionUseCase restoreSession;
  final LoginUseCase login;
  final LogoutUseCase logout;
  CartCubit? _cartCubit;

  /// Restores any stored session at app startup. Never blocks indefinitely —
  /// the use case resolves to unauthenticated on any failure.
  Future<void> checkSession() async {
    emit(const AuthCheckingSession());
    final result = await restoreSession(const NoParams());
    switch (result) {
      case AuthSuccess(value: final session?):
        emit(AuthAuthenticated(session));
      case AuthSuccess():
        emit(const AuthUnauthenticated());
      case AuthError():
        // Restoration failure means no valid session — fall back to login.
        emit(const AuthUnauthenticated());
    }
  }

  /// Logs in with [email] and [password].
  Future<void> signIn(String email, String password) async {
    emit(const AuthLoading());
    final result = await login(LoginParams(email: email, password: password));
    switch (result) {
      case AuthSuccess(value: final session):
        emit(AuthAuthenticated(session));
      case AuthError(failure: final failure):
        emit(AuthFailure(failure.message));
        // Return to the unauthenticated state so the login form stays usable.
        emit(const AuthUnauthenticated());
    }
  }

  /// Logs out, clears local tokens, and returns to the login screen.
  Future<void> signOut() async {
    _cartCubit?.clear();
    emit(const AuthLoading());
    final result = await logout(const NoParams());
    switch (result) {
      case AuthSuccess():
        emit(const AuthUnauthenticated());
      case AuthError(failure: final failure):
        // Even if the backend call failed, local tokens were cleared by the
        // repository and the device cart must still be cleared.
        emit(AuthFailure(failure.message));
        emit(const AuthUnauthenticated());
    }
  }
}

/// Sealed authentication state hierarchy.
sealed class AuthState {
  const AuthState();
}

/// The app has just launched; no session check has run yet.
final class AuthInitial extends AuthState {
  const AuthInitial();
}

/// A stored session is being verified at startup.
final class AuthCheckingSession extends AuthState {
  const AuthCheckingSession();
}

/// A valid session exists.
final class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.session);

  final AuthSession session;
}

/// No valid session; the user must log in.
final class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

/// A login/logout request is in flight.
final class AuthLoading extends AuthState {
  const AuthLoading();
}

/// The last request failed with a user-safe message.
final class AuthFailure extends AuthState {
  const AuthFailure(this.message);

  final String message;
}

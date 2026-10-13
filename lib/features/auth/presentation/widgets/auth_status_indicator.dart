import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/auth/presentation/bloc/auth_cubit.dart';

/// A visual indicator for the current authentication status.
///
/// Renders a chip reflecting the [AuthCubit] state. Useful for debugging and
/// for surfaces that need to surface auth state at a glance.
class AuthStatusIndicator extends StatelessWidget {
  const AuthStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthAuthenticated(:final session) => _Chip(
              icon: Icons.verified_user,
              color: Colors.green.shade600,
              label: 'Authenticated · ${session.user.email}',
            ),
          AuthCheckingSession() => const _Chip(
              icon: Icons.hourglass_empty,
              color: Colors.grey,
              label: 'Checking session…',
            ),
          AuthLoading() => const _Chip(
              icon: Icons.sync,
              color: Colors.blue,
              label: 'Loading…',
            ),
          AuthFailure(:final message) => _Chip(
              icon: Icons.error_outline,
              color: Colors.red,
              label: message,
            ),
          _ => const _Chip(
              icon: Icons.person_outline,
              color: Colors.grey,
              label: 'Unauthenticated',
            ),
        };
      },
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.label});

  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: color),
      label: Text(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

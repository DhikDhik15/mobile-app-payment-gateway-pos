import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/auth/presentation/bloc/auth_cubit.dart';

/// Settings page.
///
/// Shows the real signed-in merchant account (from the auth session) and
/// entry points that do not require new backend capabilities.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<AuthCubit, AuthState>(
        builder: (context, state) {
          final session = state is AuthAuthenticated ? state.session : null;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Account',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Email'),
                      subtitle: Text(session?.user.email ?? '-'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.badge_outlined),
                      title: const Text('Role'),
                      subtitle: Text(session?.user.role ?? '-'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.store_outlined),
                      title: const Text('Merchant ID'),
                      subtitle: Text(session?.user.merchantId ?? '-'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: () => context.read<AuthCubit>().signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';
import 'package:payment_simulator/features/home/presentation/bloc/home_cubit.dart';

/// Development-only card that verifies the app can reach the configured
/// GO-SAAS backend.
///
/// Renders the current [BackendConnectionStatus] and lets the user trigger a
/// (re-)check. All network access happens in the cubit/use case/data layers —
/// this widget never touches HTTP directly.
class BackendConnectionCard extends StatelessWidget {
  const BackendConnectionCard({super.key, required this.status});

  final BackendConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (status) {
          BackendNotChecked() => _NotCheckedContent(onTap: _triggerCheck),
          BackendChecking() => const _CheckingContent(),
          BackendConnected(:final statusCode, :final latency) =>
            _ConnectedContent(
              statusCode: statusCode,
              latency: latency,
              onTap: _triggerCheck,
            ),
          BackendConnectionFailed(:final category, :final message) =>
            _FailedContent(
              category: category,
              message: message,
              onTap: _triggerCheck,
            ),
        },
      ),
    );
  }

  void _triggerCheck(BuildContext context) {
    context.read<HomeCubit>().checkBackendConnection();
  }
}

class _NotCheckedContent extends StatelessWidget {
  const _NotCheckedContent({required this.onTap});

  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    return _ContentRow(
      icon: Icons.cloud_outlined,
      iconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      title: 'Backend Connection',
      subtitle: 'Not checked yet',
      action: TextButton(
        onPressed: () => onTap(context),
        child: const Text('Test Connection'),
      ),
    );
  }
}

class _CheckingContent extends StatelessWidget {
  const _CheckingContent();

  @override
  Widget build(BuildContext context) {
    return const _ContentRow(
      icon: Icons.cloud_queue,
      title: 'Backend Connection',
      subtitle: 'Checking...',
      action: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _ConnectedContent extends StatelessWidget {
  const _ConnectedContent({
    required this.statusCode,
    required this.latency,
    required this.onTap,
  });

  final int statusCode;
  final Duration latency;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    return _ContentRow(
      icon: Icons.cloud_done,
      iconColor: Colors.green.shade600,
      title: 'Backend Connection',
      subtitle: 'Connected · HTTP $statusCode · ${latency.inMilliseconds} ms',
      action: IconButton(
        tooltip: 'Re-check connection',
        icon: const Icon(Icons.refresh),
        onPressed: () => onTap(context),
      ),
    );
  }
}

class _FailedContent extends StatelessWidget {
  const _FailedContent({
    required this.category,
    required this.message,
    required this.onTap,
  });

  final BackendFailureCategory category;
  final String message;
  final void Function(BuildContext context) onTap;

  @override
  Widget build(BuildContext context) {
    return _ContentRow(
      icon: Icons.cloud_off,
      iconColor: Theme.of(context).colorScheme.error,
      title: 'Backend Connection',
      subtitle: 'Connection Failed · ${_categoryLabel(category)}',
      message: message,
      action: TextButton(
        onPressed: () => onTap(context),
        child: const Text('Retry'),
      ),
    );
  }

  static String _categoryLabel(BackendFailureCategory category) {
    return switch (category) {
      BackendFailureCategory.timeout => 'Timeout',
      BackendFailureCategory.connection => 'Connection Failure',
      BackendFailureCategory.httpError => 'HTTP Error',
      BackendFailureCategory.invalidResponse => 'Invalid Response',
      BackendFailureCategory.unknown => 'Unknown Error',
    };
  }
}

class _ContentRow extends StatelessWidget {
  const _ContentRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor,
    this.message,
    this.action,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              if (message != null) ...[
                const SizedBox(height: 4),
                Text(
                  message!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
        ?action,
      ],
    );
  }
}

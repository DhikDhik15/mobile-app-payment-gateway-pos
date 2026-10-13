import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/payments/data/services/payment_url_opener.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/widgets/payment_status_indicator.dart';

/// Payment detail page.
///
/// Displays full payment information fetched from the GO-SAAS backend,
/// including the backend-provided payment URL.
///
/// The page never renders blank while an operation is in flight: the last
/// loaded payment is retained with a progress indicator during refreshes and
/// simulations. A payment belonging to a different ID is never shown.
class PaymentDetailPage extends StatefulWidget {
  const PaymentDetailPage({
    super.key,
    required this.paymentId,
    this.showSimulator = kDebugMode,
    this.urlLauncher = defaultLaunchPaymentUri,
  });

  final String paymentId;

  /// Whether the development-only simulation controls are visible.
  ///
  /// Defaults to debug builds. There is no flavor configuration in this
  /// project, so release builds hide the simulator UI; backend role checks
  /// remain the actual authorization and are unaffected by this flag.
  final bool showSimulator;

  /// Opens a validated payment URL. Injectable for tests.
  final LaunchPaymentUri urlLauncher;

  @override
  State<PaymentDetailPage> createState() => _PaymentDetailPageState();
}

class _PaymentDetailPageState extends State<PaymentDetailPage> {
  late final PaymentCubit _paymentCubit;

  @override
  void initState() {
    super.initState();
    _paymentCubit = context.read<PaymentCubit>();
    _paymentCubit.loadPayment(widget.paymentId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _paymentCubit,
      child: _PaymentDetailBody(
        paymentId: widget.paymentId,
        showSimulator: widget.showSimulator,
        urlLauncher: widget.urlLauncher,
      ),
    );
  }
}

class _PaymentDetailBody extends StatefulWidget {
  const _PaymentDetailBody({
    required this.paymentId,
    required this.showSimulator,
    required this.urlLauncher,
  });

  final String paymentId;
  final bool showSimulator;
  final LaunchPaymentUri urlLauncher;

  @override
  State<_PaymentDetailBody> createState() => _PaymentDetailBodyState();
}

class _PaymentDetailBodyState extends State<_PaymentDetailBody> {
  /// Last payment loaded for [widget.paymentId]. Retained across refreshes
  /// and simulations so the page never goes blank and never shows another
  /// payment's data.
  Payment? _lastPayment;

  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(onResume: _handleResumed);
  }

  @override
  void didUpdateWidget(covariant _PaymentDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.paymentId != widget.paymentId) {
      _lastPayment = null;
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Reloads the payment when the app returns to the foreground.
  ///
  /// Only when this page already holds settled data for its own payment and
  /// no operation is running — never during simulation/loading, never for
  /// another payment, and never on a loop.
  void _handleResumed() {
    if (!mounted) return;
    final state = context.read<PaymentCubit>().state;
    final cached = _lastPayment;
    final idle = state is PaymentDetailLoaded || state is PaymentSimulated;
    if (idle && cached != null && cached.transactionId == widget.paymentId) {
      context.read<PaymentCubit>().loadPayment(widget.paymentId);
    }
  }

  void _refresh() {
    final state = context.read<PaymentCubit>().state;
    if (_isBusy(state)) return;
    context.read<PaymentCubit>().loadPayment(widget.paymentId);
  }

  Future<void> _refreshForPull() async {
    final state = context.read<PaymentCubit>().state;
    if (_isBusy(state)) return;
    await context.read<PaymentCubit>().loadPayment(widget.paymentId);
  }

  bool _isBusy(PaymentState state) =>
      state is PaymentLoading ||
      state is PaymentSimulating ||
      state is PaymentCreating;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentCubit, PaymentState>(
      listener: (context, state) {
        // Cache only payments that belong to this page.
        final payment = switch (state) {
          PaymentDetailLoaded(payment: final p) => p,
          PaymentSimulated(payment: final p) => p,
          _ => null,
        };
        if (payment != null && payment.transactionId == widget.paymentId) {
          setState(() => _lastPayment = payment);
        }
      },
      builder: (context, state) {
        final busy = _isBusy(state);
        final cached = _lastPayment;
        final cachedForThisPage =
            cached != null && cached.transactionId == widget.paymentId;

        Widget body;
        switch (state) {
          case PaymentDetailLoaded(payment: final payment)
              when payment.transactionId == widget.paymentId:
            body = _PaymentDetail(
              payment: payment,
              busy: false,
              showSimulator: widget.showSimulator,
              urlLauncher: widget.urlLauncher,
              paymentId: widget.paymentId,
              onRefresh: _refreshForPull,
            );
          case PaymentSimulated(payment: final payment)
              when payment.transactionId == widget.paymentId:
            body = _PaymentDetail(
              payment: payment,
              busy: false,
              showSimulator: widget.showSimulator,
              urlLauncher: widget.urlLauncher,
              paymentId: widget.paymentId,
              onRefresh: _refreshForPull,
            );
          case PaymentFailure(message: final message):
            // A refresh/simulation failure must not discard the last known
            // details; only a first-load failure (no cache) is a full page.
            body = cachedForThisPage
                ? _PaymentDetail(
                    payment: cached,
                    busy: false,
                    showSimulator: widget.showSimulator,
                    urlLauncher: widget.urlLauncher,
                    paymentId: widget.paymentId,
                    inlineError: message,
                    onRetryError: _refresh,
                    onRefresh: _refreshForPull,
                  )
                : _ErrorView(message: message, onRetry: _refresh);
          case _ when cachedForThisPage:
            // Loading / Simulating / Creating / foreign list states: keep the
            // known payment visible with progress instead of going blank.
            body = _PaymentDetail(
              payment: cached,
              busy: busy,
              showSimulator: widget.showSimulator,
              urlLauncher: widget.urlLauncher,
              paymentId: widget.paymentId,
              onRefresh: _refreshForPull,
            );
          case _:
            body = const Center(child: CircularProgressIndicator());
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Payment Detail'),
            actions: [
              IconButton(
                key: const Key('payment-detail-refresh'),
                tooltip: 'Refresh payment status',
                onPressed: busy ? null : _refresh,
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
              ),
            ],
          ),
          body: body,
        );
      },
    );
  }
}

/// The full payment detail view.
class _PaymentDetail extends StatelessWidget {
  const _PaymentDetail({
    required this.payment,
    required this.busy,
    required this.showSimulator,
    required this.urlLauncher,
    required this.paymentId,
    required this.onRefresh,
    this.inlineError,
    this.onRetryError,
  });

  final Payment payment;
  final bool busy;
  final bool showSimulator;
  final LaunchPaymentUri urlLauncher;
  final String paymentId;
  final Future<void> Function() onRefresh;
  final String? inlineError;
  final VoidCallback? onRetryError;

  Future<void> _openPaymentUrl(BuildContext context) async {
    final url = payment.paymentUrl;
    if (!isLaunchablePaymentUrl(url)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No valid payment URL is available.')),
        );
      return;
    }
    final target = url!.trim();
    try {
      final opened = await urlLauncher(Uri.parse(target));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              opened
                  ? 'Payment page opened. Return here to see the updated status.'
                  : unreachablePaymentUrlHint(target),
            ),
          ),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(unreachablePaymentUrlHint(target))));
    }
  }

  Future<void> _copyPaymentUrl(BuildContext context) async {
    final url = payment.paymentUrl;
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('No payment URL to copy.')),
        );
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: url.trim()));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Payment URL copied to clipboard.')),
        );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Could not copy the payment URL.')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Pull-to-refresh re-reads this payment only. It never creates or
    // simulates a payment; simulation stays behind its explicit buttons.
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy) ...[
            const LinearProgressIndicator(key: Key('payment-detail-progress')),
            const SizedBox(height: 16),
          ],
          if (inlineError != null)
            _InlineErrorCard(
              message: inlineError!,
              onRetry: onRetryError,
            ),
          _DetailRow(
            label: 'Transaction ID',
            value: payment.transactionId,
            onCopy: () => _copyValue(context, payment.transactionId),
          ),
          _DetailRow(
            label: 'Merchant Order ID',
            value: payment.merchantOrderId,
          ),
          _DetailRow(
            label: 'Amount',
            value: '${payment.amount} ${payment.currency}',
          ),
          _DetailRow(label: 'Payment Method', value: payment.paymentMethod),
          _DetailRow(
            label: 'Status',
            value: payment.status.apiValue,
            trailing: PaymentStatusIndicator(status: payment.status),
          ),
          if (payment.provider != null)
            _DetailRow(label: 'Provider', value: payment.provider!),
          if (payment.providerTransactionId != null)
            _DetailRow(
              label: 'Provider Transaction ID',
              value: payment.providerTransactionId!,
            ),
          if (payment.paymentUrl != null) ...[
            _DetailRow(
              label: 'Payment URL',
              value: payment.paymentUrl!,
              onCopy: () => _copyPaymentUrl(context),
            ),
            FilledButton.tonalIcon(
              key: const Key('payment-open-url'),
              onPressed: () => _openPaymentUrl(context),
              icon: const Icon(Icons.open_in_new_outlined),
              label: const Text('Open payment page'),
            ),
            const SizedBox(height: 4),
            Text(
              'Development mock URLs open in your browser and need a '
              'reachable development environment.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
          if (payment.expiredAt != null)
            _DetailRow(
              label: 'Expires At',
              value: _formatDateTime(payment.expiredAt!),
            ),
          if (payment.paidAt != null)
            _DetailRow(
              label: 'Paid At',
              value: _formatDateTime(payment.paidAt!),
            ),
          _DetailRow(
            label: 'Created At',
            value: _formatDateTime(payment.createdAt),
          ),
          _DetailRow(
            label: 'Updated At',
            value: _formatDateTime(payment.updatedAt),
          ),
          const SizedBox(height: 24),
          if (showSimulator) _SimulationSection(payment: payment),
        ],
        ),
      ),
    );
  }

  Future<void> _copyValue(BuildContext context, String value) async {
    try {
      await Clipboard.setData(ClipboardData(text: value));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Copied to clipboard.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not copy.')));
    }
  }
}

/// Inline recoverable error shown above retained details.
///
/// Used when a refresh or simulation fails after details were already
/// loaded, so the last known payment is never discarded.
class _InlineErrorCard extends StatelessWidget {
  const _InlineErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('payment-detail-inline-error'),
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13)),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Simulation section with success/fail buttons.
///
/// Development-only: rendered only when the page's `showSimulator` flag is
/// enabled (debug builds by default). Backend role checks remain the actual
/// authorization for the underlying endpoints.
class _SimulationSection extends StatelessWidget {
  const _SimulationSection({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final isTerminal =
        payment.status == PaymentStatus.paid ||
        payment.status == PaymentStatus.failed ||
        payment.status == PaymentStatus.expired ||
        payment.status == PaymentStatus.cancelled;

    return BlocConsumer<PaymentCubit, PaymentState>(
      listener: (context, state) {
        if (state is PaymentSimulated) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment simulated: ${state.payment.status.apiValue}',
              ),
            ),
          );
        } else if (state is PaymentFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isSimulating = state is PaymentSimulating;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simulate Payment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Development only — drives the mock provider, not a real payment.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                if (isTerminal)
                  const Text(
                    'Payment is in a terminal state and cannot be simulated.',
                    style: TextStyle(color: Colors.grey),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: isSimulating
                              ? null
                              : () => context
                                    .read<PaymentCubit>()
                                    .simulateSuccess(payment.transactionId),
                          icon: isSimulating
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check_circle_outline),
                          label: const Text('Success'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: isSimulating
                              ? null
                              : () => context.read<PaymentCubit>().simulateFail(
                                  payment.transactionId,
                                ),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Fail'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A single detail row with label and value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.onCopy,
  });

  final String label;
  final String value;
  final Widget? trailing;

  /// When set, shows a copy button that copies the row's own value.
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(value, style: const TextStyle(fontSize: 15)),
              ),
              ?trailing,
              if (onCopy != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  tooltip: 'Copy $label',
                  onPressed: onCopy,
                ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }
}

/// Error view with retry.
class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Formats a DateTime for display.
String _formatDateTime(DateTime dt) {
  return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

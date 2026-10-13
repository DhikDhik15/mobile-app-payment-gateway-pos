import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_error_kind.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_order_payments.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payment_detail_page.dart';

/// Order-scoped payment checkout page.
///
/// Flow: Order Confirmation → Continue to Payment → this page → Payment Detail.
///
/// The request contains only `payment_method` (plus the order ID in the path
/// and a stable `Idempotency-Key` header). Amount, currency, merchant identity
/// and `merchant_order_id` are derived server-side from the authenticated
/// order — they are displayed here for confirmation only and never sent.
///
/// Recovery-first retry policy: on entry (and after every failed submit) the
/// page reloads the order's recorded attempt history from the read-only
/// history endpoint and derives everything from server state, so recovery
/// survives widget reconstruction, route changes, and application restart:
///
/// - PAID present → existing-payment card, no Pay action.
/// - Active (CREATED/PENDING) present → status card, no new payment.
/// - Empty or all-terminal history → Pay with a deterministic attempt key:
///   the base key when no attempt exists, otherwise `base:retry:{m}` where
///   `m` is the number of recorded attempts. Reusing a consumed key only
///   replays its stored result (never duplicates); a provably-fresh
///   `base:retry:{k}` is used at most once per tap when history proves the
///   previous key cannot advance (stale replay with unchanged history).
/// - History unloadable → recoverable error, Pay hidden: never assume no
///   payment exists and never submit merely because recovery failed.
class PaymentCheckoutPage extends StatefulWidget {
  const PaymentCheckoutPage({
    super.key,
    required this.order,
    this.idempotencyKey,
    this.orderPayments,
  });

  /// The confirmed order being paid. Its totals are authoritative server-side.
  final Order order;

  /// Overrides the base idempotency key (used by tests). When null the
  /// stable base key `order:{orderId}:qris:v1` is used.
  final String? idempotencyKey;

  /// History use case override (used by tests). When null it is built from
  /// the shared cubit's repository in [initState].
  final ListOrderPaymentsUseCase? orderPayments;

  /// Stable base idempotency key for one logical order-payment initiation.
  ///
  /// Same order + same payment method + same key replays the original result
  /// instead of creating a duplicate payment.
  static String stableKeyFor(String orderId) => 'order:$orderId:qris:v1';

  /// Attempt key derived from the base key. Attempt 0 is the base key itself
  /// so existing integrations and tests keep working.
  @visibleForTesting
  static String attemptKeyFor(String baseKey, int attempt) =>
      attempt <= 0 ? baseKey : '$baseKey:retry:$attempt';

  @override
  State<PaymentCheckoutPage> createState() => _PaymentCheckoutPageState();
}

class _PaymentCheckoutPageState extends State<PaymentCheckoutPage> {
  /// QRIS is currently the only backend-supported payment method.
  static const _paymentMethod = 'QRIS';

  late final String _baseIdempotencyKey;
  late final PaymentCubit _paymentCubit;
  late final ListOrderPaymentsUseCase _historyUseCase;

  /// True while this page's own create-payment request is unresolved.
  ///
  /// The cubit is shared application-wide, so [PaymentCreated]/[PaymentFailure]
  /// emissions from unrelated flows must not drive this page.
  bool _awaitingResult = false;

  /// Recovery state. [_history] is null until the first successful load;
  /// [_recoveryError] is set when the load fails.
  bool _recovering = true;
  List<Payment>? _history;
  String? _recoveryError;

  /// Our own successfully created payment, if any. Once set, the Pay action
  /// is replaced with a path to the existing payment detail.
  Payment? _createdPayment;

  /// Key and history size of the last submitted request.
  int _lastSubmittedHistoryLength = 0;

  /// Highest attempt index submitted this session. Fresh fallback keys are
  /// derived above both this and the recorded history length, so they can
  /// never collide with a previously consumed key.
  int _maxSubmittedIndex = -1;

  /// Caps chained auto-submits to one per explicit user tap. Every further
  /// step requires another tap; chains always terminate.
  bool _autoChainUsed = false;

  String _keyFor(int attemptCount) =>
      PaymentCheckoutPage.attemptKeyFor(_baseIdempotencyKey, attemptCount);

  @override
  void initState() {
    super.initState();
    _baseIdempotencyKey =
        widget.idempotencyKey ?? PaymentCheckoutPage.stableKeyFor(widget.order.id);
    _paymentCubit = context.read<PaymentCubit>();
    _historyUseCase = widget.orderPayments ??
        ListOrderPaymentsUseCase(_paymentCubit.paymentRepository);
    _recover();
  }

  String _formatMoney(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remainingAfter = digits.length - i - 1;
      buffer.write(digits[i]);
      if (remainingAfter > 0 && remainingAfter % 3 == 0) buffer.write('.');
    }
    return '${widget.order.currency} ${amount < 0 ? '-' : ''}$buffer';
  }

  Future<void> _openPaymentDetail(String paymentId) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _paymentCubit,
          child: PaymentDetailPage(paymentId: paymentId),
        ),
      ),
    );
  }

  // ── Recovery ──────────────────────────────────────────────────────────────

  /// Reloads the order's recorded attempts. Returns the history scoped to
  /// this order, or null when the load failed (in which case Pay stays
  /// hidden and a retry affordance is shown instead).
  Future<List<Payment>?> _recover() async {
    final result = await _historyUseCase(
      ListOrderPaymentsParams(orderId: widget.order.id),
    );
    if (!mounted) return null;
    switch (result) {
      case PaymentSuccess(value: final payments):
        // Defensive §8 guard: only this order's payments drive this page.
        final mine = payments
            .where((p) => p.orderId == null || p.orderId == widget.order.id)
            .toList();
        setState(() {
          _history = mine;
          _recoveryError = null;
          _recovering = false;
        });
        return mine;
      case PaymentError(failure: final failure):
        setState(() {
          _recoveryError = failure.message;
          _recovering = false;
        });
        return null;
    }
  }

  static bool _isPaid(Payment p) => p.status == PaymentStatus.paid;
  static bool _isActive(Payment p) =>
      p.status == PaymentStatus.created || p.status == PaymentStatus.pending;

  Payment? _firstWhereOrNull(List<Payment> history, bool Function(Payment) test) {
    for (final p in history) {
      if (test(p)) return p;
    }
    return null;
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  /// Explicit user tap. Submits only when recovered history permits it:
  /// empty or all-terminal history, with no known active or paid payment.
  Future<void> _submit() async {
    final history = _history;
    if (history == null || _awaitingResult) return;
    if (_firstWhereOrNull(history, _isPaid) != null) return;
    if (_firstWhereOrNull(history, _isActive) != null) return;
    _autoChainUsed = false;
    // Last-resort guard: the cubit converts failures to states, but if the
    // await itself ever throws, the loading state must still clear. Never
    // resubmits here — the idempotency key for this tap is spent at most
    // once by [_submitWithKey].
    try {
      await _submitWithKey(_keyFor(history.length), history.length);
    } catch (_) {
      _failWith('An unexpected error occurred');
    }
  }

  Future<void> _submitWithKey(String key, int historyLength) async {
    final attemptIndex = _attemptIndexOf(key);
    if (attemptIndex > _maxSubmittedIndex) {
      _maxSubmittedIndex = attemptIndex;
    }
    setState(() {
      _awaitingResult = true;
      _lastSubmittedHistoryLength = historyLength;
    });
    await _paymentCubit.createOrderPayment(
      orderId: widget.order.id,
      paymentMethod: _paymentMethod,
      idempotencyKey: key,
    );
  }

  int _attemptIndexOf(String key) {
    if (key == _baseIdempotencyKey) return 0;
    final prefix = '$_baseIdempotencyKey:retry:';
    if (key.startsWith(prefix)) {
      return int.tryParse(key.substring(prefix.length)) ?? 0;
    }
    return 0;
  }

  void _failWith(String message) {
    if (!mounted) return;
    setState(() => _awaitingResult = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  /// Handles a failed submit according to the classified error kind. Never
  /// blindly advances: every further submit is derived from freshly reloaded
  /// history, capped to one chained submit per explicit tap, with
  /// server-side guards as the final backstop.
  Future<void> _handleSubmitFailure(Failure failure) async {
    if (!mounted) return;
    // The server answered (possibly with 201: the payment may exist) but
    // the payload could not be parsed. Reload history once so an existing
    // payment is shown instead of stranding the user on a spinner — and
    // never submit a new payment from this path.
    if (failure is InvalidResponseFailure) {
      await _recoverAfterUnparseableResponse(failure);
      return;
    }
    final submittedCount = _lastSubmittedHistoryLength;
    switch (classifyOrderPaymentError(failure)) {
      case PaymentErrorKind.validation:
      case PaymentErrorKind.auth:
      case PaymentErrorKind.notFound:
      case PaymentErrorKind.unknown:
        // Nothing was (or nothing more can be) created by this request.
        // Preserve the key; recovery already reflects server state.
        _failWith(failure.message);
      case PaymentErrorKind.idempotencyReused:
      case PaymentErrorKind.idempotencyProcessing:
        // Another request owns this key or is still running: reload and
        // show the resulting state instead of submitting again.
        await _recover();
        if (!mounted) return;
        setState(() => _awaitingResult = false);
        _showMessage(failure.message);
      case PaymentErrorKind.definitiveFailure:
      case PaymentErrorKind.orderConflict:
      case PaymentErrorKind.ambiguousTimeout:
      case PaymentErrorKind.unknownOutcome:
        await _recoverAndContinue(failure, submittedCount);
    }
  }

  /// Reloads attempt history once after a response that could not be parsed.
  ///
  /// The server may have created the payment (e.g. HTTP 201 with a payload
  /// shape the client cannot decode), so the existing read-only recovery
  /// endpoint is consulted with the same idempotency key still in effect:
  /// a recovered paid/active payment replaces the Pay action with no new
  /// submission. Otherwise the retained state is shown with the parsing
  /// error. This method never submits a payment.
  Future<void> _recoverAfterUnparseableResponse(Failure failure) async {
    final history = await _recover();
    if (!mounted) return;
    if (history != null &&
        (_firstWhereOrNull(history, _isPaid) != null ||
            _firstWhereOrNull(history, _isActive) != null)) {
      setState(() => _awaitingResult = false);
      return;
    }
    _failWith(failure.message);
  }

  /// Reloads history after a failure and decides the single next step:
  /// show recovered state, re-derive the key when server state advanced, or
  /// use one provably-fresh key when history proves the last key is spent.
  Future<void> _recoverAndContinue(
    Failure failure,
    int submittedCount,
  ) async {
    final history = await _recover();
    if (!mounted) return;
    if (history == null) {
      // Recovery itself failed: do not assume anything, do not submit.
      _failWith(failure.message);
      return;
    }
    if (_firstWhereOrNull(history, _isPaid) != null ||
        _firstWhereOrNull(history, _isActive) != null) {
      // The order now has a payment to show; submitting is forbidden.
      setState(() => _awaitingResult = false);
      return;
    }
    if (history.length > submittedCount && !_autoChainUsed) {
      // Server state advanced (a new terminal attempt exists): re-derive
      // the key from history and retry once within this tap.
      _autoChainUsed = true;
      await _submitWithKey(_keyFor(history.length), history.length);
      return;
    }
    if (history.length == submittedCount &&
        !_autoChainUsed &&
        _allowsFreshRetry(failure)) {
      // History is unchanged, so the last key replayed a spent result
      // without recording anything new. Exactly one fresh key is safe:
      // it is above every previously submitted index and every recorded
      // attempt, and the active/paid guards still forbid duplicates.
      _autoChainUsed = true;
      final fresh = submittedCount > _maxSubmittedIndex
          ? submittedCount + 1
          : _maxSubmittedIndex + 1;
      await _submitWithKey(_keyFor(fresh), history.length);
      return;
    }
    _failWith(failure.message);
  }

  /// Fresh keys are only spent when the failure proves no new attempt was
  /// recorded and the guards confirm none is active. Definitive failures
  /// always record an attempt, so they re-derive instead.
  bool _allowsFreshRetry(Failure failure) {
    switch (classifyOrderPaymentError(failure)) {
      case PaymentErrorKind.orderConflict:
      case PaymentErrorKind.ambiguousTimeout:
      case PaymentErrorKind.unknownOutcome:
        return true;
      case PaymentErrorKind.definitiveFailure:
      case PaymentErrorKind.idempotencyReused:
      case PaymentErrorKind.idempotencyProcessing:
      case PaymentErrorKind.validation:
      case PaymentErrorKind.auth:
      case PaymentErrorKind.notFound:
      case PaymentErrorKind.unknown:
        return false;
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _paymentCubit,
      child: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          // React only to this page's own in-flight request.
          if (!_awaitingResult) return;
          switch (state) {
            case PaymentCreated(payment: final payment):
              if (payment.orderId != null &&
                  payment.orderId != widget.order.id) {
                // §8 guard: never present another order's payment as ours.
                setState(() => _awaitingResult = false);
                _showMessage('Payment does not belong to this order.');
                return;
              }
              setState(() {
                _awaitingResult = false;
                _createdPayment = payment;
              });
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text('Payment ${payment.status.apiValue}: ${payment.merchantOrderId}'),
                  ),
                );
              _openPaymentDetail(payment.transactionId);
            case PaymentFailure(message: final message, failure: final failure):
              // The typed failure (when present) drives classified recovery;
              // otherwise fall back to an unknown failure that never advances.
              unawaited(_handleSubmitFailure(
                failure ?? UnexpectedFailure(message),
              ));
            case PaymentInitial() ||
                PaymentLoading() ||
                PaymentListLoaded() ||
                PaymentDetailLoaded() ||
                PaymentCreating() ||
                PaymentSimulating() ||
                PaymentSimulated():
              break;
          }
        },
        builder: (context, state) {
          final isCreating = state is PaymentCreating && _awaitingResult;
          return Scaffold(
            appBar: AppBar(title: const Text('Checkout')),
            body: _buildBody(context, isCreating),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool isCreating) {
    if (_recovering) {
      return const Center(child: CircularProgressIndicator());
    }
    final history = _history;
    if (history == null) {
      return _RecoveryErrorView(
        message: _recoveryError ?? 'Could not load payment status.',
        onRetry: () {
          setState(() {
            _recovering = true;
            _recoveryError = null;
          });
          _recover();
        },
      );
    }
    final created = _createdPayment;
    final paid = _firstWhereOrNull(history, _isPaid);
    final active = _firstWhereOrNull(history, _isActive);
    final known = created ?? paid ?? active;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _SectionTitle('Order Summary'),
        _DetailRow(label: 'Order ID', value: widget.order.id),
        _DetailRow(label: 'Status', value: widget.order.status),
        const SizedBox(height: 8),
        for (final item in widget.order.items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(item.productName),
            subtitle: Text('${item.quantity} × ${_formatMoney(item.unitPrice)}'),
            trailing: Text(_formatMoney(item.subtotal)),
          ),
        const Divider(),
        _DetailRow(label: 'Subtotal', value: _formatMoney(widget.order.subtotal)),
        _DetailRow(
          label: 'Total due',
          value: _formatMoney(widget.order.totalAmount),
        ),
        const SizedBox(height: 24),
        _SectionTitle('Payment Method'),
        RadioGroup<String>(
          groupValue: _paymentMethod,
          // Single supported method (QRIS); selection is fixed.
          onChanged: (_) {},
          child: const RadioListTile<String>(
            value: _paymentMethod,
            title: Text('QRIS'),
            subtitle: Text('Scan to pay (simulator / mock flow)'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        Text(
          'Amount is charged from the confirmed order total. '
          'Only the payment method is sent to the server.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        if (known != null)
          _ExistingPaymentCard(
            payment: known,
            onView: () => _openPaymentDetail(known.transactionId),
          )
        else
          FilledButton.icon(
            key: const Key('checkout-pay-button'),
            onPressed: isCreating ? null : _submit,
            icon: isCreating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2_outlined),
            label: Text(isCreating ? 'Creating payment…' : 'Pay ${_formatMoney(widget.order.totalAmount)}'),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: isCreating ? null : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_outlined),
          label: const Text('Back to Order'),
        ),
      ],
    );
  }
}

/// Shown once this checkout created (or recovered) its payment.
///
/// Replaces the Pay action so the user is guided to the existing payment
/// instead of submitting a duplicate the server would reject.
class _ExistingPaymentCard extends StatelessWidget {
  const _ExistingPaymentCard({required this.payment, required this.onView});

  final Payment payment;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('checkout-created-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Payment ${payment.status.apiValue}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              payment.merchantOrderId,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(
              key: const Key('checkout-view-payment'),
              onPressed: onView,
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('View payment details'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when attempt history cannot be loaded. Pay stays hidden: the page
/// must not assume no payment exists and must not submit blindly.
class _RecoveryErrorView extends StatelessWidget {
  const _RecoveryErrorView({required this.message, required this.onRetry});

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
            const Icon(Icons.cloud_off_outlined, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'Payment status unavailable',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          const SizedBox(width: 16),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

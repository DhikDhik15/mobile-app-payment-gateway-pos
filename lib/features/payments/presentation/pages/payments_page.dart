import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payment_detail_page.dart';
import 'package:payment_simulator/features/payments/presentation/widgets/payment_status_indicator.dart';

/// Payments list page.
///
/// Displays the paginated payment list fetched from the GO-SAAS backend.
/// Provides navigation to the payment detail page and a create-payment
/// action.
class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  late final PaymentCubit _paymentCubit;

  @override
  void initState() {
    super.initState();
    _paymentCubit = context.read<PaymentCubit>();
    _paymentCubit.loadPayments();
  }

  Future<void> _openPayment(String paymentId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _paymentCubit,
          child: PaymentDetailPage(paymentId: paymentId),
        ),
      ),
    );
    if (mounted) {
      await _paymentCubit.loadPayments();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _paymentCubit,
      child: _PaymentsBody(onPaymentSelected: _openPayment),
    );
  }
}

class _PaymentsBody extends StatefulWidget {
  const _PaymentsBody({required this.onPaymentSelected});

  final Future<void> Function(String paymentId) onPaymentSelected;

  @override
  State<_PaymentsBody> createState() => _PaymentsBodyState();
}

class _PaymentsBodyState extends State<_PaymentsBody> {
  /// Last loaded list, retained while unrelated payment states
  /// (detail/creation/simulation) pass through the shared cubit.
  List<Payment>? _lastPayments;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: BlocConsumer<PaymentCubit, PaymentState>(
        listener: (context, state) {
          if (state is PaymentListLoaded) {
            setState(() => _lastPayments = state.payments);
          }
        },
        builder: (context, state) {
          final cached = _lastPayments;
          return switch (state) {
            PaymentListLoaded(payments: final payments) => _PaymentList(
              payments: payments,
              onPaymentSelected: widget.onPaymentSelected,
            ),
            PaymentFailure(message: final message) => _ErrorView(
              message: message,
              onRetry: () => context.read<PaymentCubit>().loadPayments(),
            ),
            _ when cached != null => _PaymentList(
              payments: cached,
              onPaymentSelected: widget.onPaymentSelected,
            ),
            _ => const Center(
              child: CircularProgressIndicator(),
            ),
          };
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreatePaymentSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Create Payment'),
      ),
    );
  }
}

/// The scrollable payment list.
class _PaymentList extends StatelessWidget {
  const _PaymentList({required this.payments, required this.onPaymentSelected});

  final List<Payment> payments;
  final Future<void> Function(String paymentId) onPaymentSelected;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return _EmptyState(
        onRefresh: () async {
          await context.read<PaymentCubit>().loadPayments();
        },
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<PaymentCubit>().loadPayments();
      },
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: payments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final payment = payments[index];
          return _PaymentCard(
            payment: payment,
            onTap: () => unawaited(onPaymentSelected(payment.transactionId)),
          );
        },
      ),
    );
  }
}

/// A single payment card in the list.
class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment, required this.onTap});

  final Payment payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.payment_outlined),
        title: Text(
          payment.merchantOrderId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${payment.amount} ${payment.currency}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PaymentStatusIndicator(status: payment.status),
        onTap: onTap,
      ),
    );
  }
}

/// Empty state shown when no payments exist.
///
/// Scrollable with [AlwaysScrollableScrollPhysics] so an empty list can
/// still be pull-to-refreshed.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onRefresh});

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 64),
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No payments yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
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

/// Shows the create-payment bottom sheet.
void _showCreatePaymentSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => BlocProvider.value(
      value: context.read<PaymentCubit>(),
      child: const _CreatePaymentSheet(),
    ),
  );
}

/// Bottom sheet for creating a new payment.
class _CreatePaymentSheet extends StatefulWidget {
  const _CreatePaymentSheet();

  @override
  State<_CreatePaymentSheet> createState() => _CreatePaymentSheetState();
}

class _CreatePaymentSheetState extends State<_CreatePaymentSheet> {
  final _formKey = GlobalKey<FormState>();
  final _orderIdController = TextEditingController();
  final _amountController = TextEditingController();

  @override
  void dispose() {
    _orderIdController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentCubit, PaymentState>(
      listener: (context, state) {
        if (state is PaymentCreated) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Payment created: ${state.payment.merchantOrderId}',
              ),
            ),
          );
          // Refresh the list.
          context.read<PaymentCubit>().loadPayments();
        } else if (state is PaymentFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isCreating = state is PaymentCreating;
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Payment',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _orderIdController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant Order ID',
                    hintText: 'ORDER-2026-0001',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Order ID is required';
                    }
                    if (value.trim().length > 100) {
                      return 'Max 100 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount (IDR)',
                    hintText: '150000',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final amount = int.tryParse(value.trim());
                    if (amount == null || amount < 1) {
                      return 'Amount must be a positive integer';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isCreating
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            final params = CreatePaymentParams(
                              merchantOrderId: _orderIdController.text.trim(),
                              amount: int.parse(_amountController.text.trim()),
                              currency: 'IDR',
                              paymentMethod: 'QRIS',
                              idempotencyKey: _generateIdempotencyKey(),
                            );
                            context.read<PaymentCubit>().createPayment(params);
                          }
                        },
                  child: isCreating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Generates a simple unique idempotency key.
  ///
  /// The backend requires a unique key per payment creation request.
  /// Uses timestamp + random component for uniqueness.
  String _generateIdempotencyKey() {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final random = timestamp % 10000;
    return 'idem-$timestamp-$random';
  }
}

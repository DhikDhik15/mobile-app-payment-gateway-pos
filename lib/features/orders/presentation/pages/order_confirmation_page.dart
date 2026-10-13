import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_result.dart';
import '../../domain/usecases/get_order_by_id.dart';
import '../../../payments/presentation/bloc/payment_cubit.dart';
import '../../../payments/presentation/pages/payment_checkout_page.dart';

/// Order detail / confirmation page.
///
/// In review mode (opened from Order History or a transaction's linked
/// order) the page shows a previously created order; otherwise it celebrates
/// a fresh creation. Both modes support pull-to-refresh (plus an AppBar
/// action) that re-reads the same order by its identifier through
/// [getOrderById] when provided.
///
/// Refreshing never recreates the order, never touches the cart, and never
/// initiates a payment. When the order can no longer be loaded, the last
/// known details are retained with transient error feedback.
class OrderConfirmationPage extends StatefulWidget {
  const OrderConfirmationPage({
    super.key,
    required this.order,
    this.isReviewMode = false,
    this.getOrderById,
  });

  final Order order;

  /// When true, the page reviews a previously created order (e.g. reopened
  /// from Order History) instead of celebrating a fresh creation. The order
  /// is never recreated, resubmitted, or modified here — totals and item
  /// snapshots are display-only in both modes.
  final bool isReviewMode;

  /// Read-only fetcher used by pull-to-refresh to re-read this order.
  /// When null (e.g. legacy call sites/tests), refresh retains the current
  /// order without issuing a request.
  final GetOrderByIdUseCase? getOrderById;

  @override
  State<OrderConfirmationPage> createState() => _OrderConfirmationPageState();
}

class _OrderConfirmationPageState extends State<OrderConfirmationPage> {
  late Order _order;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  String _formatMoney(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remainingAfter = digits.length - i - 1;
      buffer.write(digits[i]);
      if (remainingAfter > 0 && remainingAfter % 3 == 0) buffer.write('.');
    }
    return '${_order.currency} ${amount < 0 ? '-' : ''}$buffer';
  }

  /// Re-reads this order by id. Collapses concurrent refreshes; failures
  /// keep the retained order with a SnackBar instead of crashing.
  Future<void> _refresh() async {
    if (_refreshing) return;
    final fetcher = widget.getOrderById;
    if (fetcher == null) return;
    _refreshing = true;
    try {
      final result = await fetcher(GetOrderByIdParams(orderId: _order.id));
      if (!mounted) return;
      switch (result) {
        case OrderSuccess(value: final order):
          setState(() => _order = order);
        case OrderError():
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              const SnackBar(
                content: Text(
                  'Could not refresh order. Showing previously loaded details.',
                ),
              ),
            );
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isReviewMode ? 'Order Details' : 'Order Confirmation',
        ),
        actions: [
          IconButton(
            key: const Key('order-detail-refresh'),
            tooltip: 'Refresh order',
            onPressed: widget.getOrderById == null ? null : _refresh,
            icon: const Icon(Icons.refresh_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Icon(
              widget.isReviewMode
                  ? Icons.receipt_long_outlined
                  : Icons.check_circle_outline,
              size: 56,
              color: widget.isReviewMode ? Colors.blue : Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              widget.isReviewMode
                  ? 'Order details'
                  : 'Order created successfully',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _DetailRow(label: 'Order ID', value: _order.id),
            _DetailRow(label: 'Status', value: _order.status),
            _DetailRow(label: 'Currency', value: _order.currency),
            _DetailRow(
              label: 'Created',
              value: _order.createdAt.toLocal().toString(),
            ),
            const SizedBox(height: 12),
            for (final item in _order.items)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  item.productName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${item.quantity} × ${_formatMoney(item.unitPrice)}',
                ),
                trailing: Text(_formatMoney(item.subtotal)),
              ),
            const Divider(),
            _DetailRow(label: 'Subtotal', value: _formatMoney(_order.subtotal)),
            _DetailRow(label: 'Total', value: _formatMoney(_order.totalAmount)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                final paymentCubit = context.read<PaymentCubit>();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: paymentCubit,
                      child: PaymentCheckoutPage(order: _order),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.credit_card_outlined),
              label: const Text('Continue to Payment'),
            ),
            const SizedBox(height: 12),
            if (!widget.isReviewMode)
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.shopping_cart_outlined),
                label: const Text('Return to Cart'),
              ),
          ],
        ),
      ),
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

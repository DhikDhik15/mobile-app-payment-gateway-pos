import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/pages/order_confirmation_page.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';

class CartPage extends StatelessWidget {
  const CartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OrderCubit, OrderState>(
      listener: (context, state) {
        switch (state) {
          case OrderCreated(order: final order):
            final paymentCubit = context.read<PaymentCubit>();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: paymentCubit,
                  child: OrderConfirmationPage(order: order),
                ),
              ),
            );
          case OrderFailure(message: final message):
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(content: Text(message)));
          case OrderInitial() || OrderLoading():
            break;
        }
      },
      builder: (context, orderState) {
        final isLoading = orderState is OrderLoading;
        return BlocBuilder<CartCubit, Cart>(
          builder: (context, cart) {
            final items = cart.items;
            return Scaffold(
              appBar: AppBar(
                title: const Text('Cart'),
                actions: [
                  if (items.isNotEmpty)
                    TextButton.icon(
                      onPressed: isLoading
                          ? null
                          : () => context.read<CartCubit>().clear(),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear'),
                    ),
                ],
              ),
              body: items.isEmpty
                  ? const _EmptyCartState()
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        for (final item in items)
                          Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${_formatPrice(item.unitPrice)} each',
                                          style: const TextStyle(
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      IconButton(
                                        tooltip: 'Decrease quantity',
                                        onPressed: isLoading
                                            ? null
                                            : () => context
                                                  .read<CartCubit>()
                                                  .setQuantity(
                                                    item.productId,
                                                    item.quantity - 1,
                                                  ),
                                        icon: const Icon(Icons.remove),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                        ),
                                        child: Text(
                                          item.quantity.toString(),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Increase quantity',
                                        onPressed: isLoading
                                            ? null
                                            : () => context
                                                  .read<CartCubit>()
                                                  .setQuantity(
                                                    item.productId,
                                                    item.quantity + 1,
                                                  ),
                                        icon: const Icon(Icons.add),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        _formatPrice(item.subtotal),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: isLoading
                                            ? null
                                            : () => context
                                                  .read<CartCubit>()
                                                  .remove(item.productId),
                                        child: const Text('Remove'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                _SummaryRow(
                                  label: 'Subtotal',
                                  value: _formatPrice(cart.subtotal),
                                ),
                                const Divider(),
                                _SummaryRow(
                                  label: 'Total',
                                  value: _formatPrice(cart.total),
                                  isTotal: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
              bottomNavigationBar: items.isEmpty
                  ? null
                  : SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                        child: FilledButton.icon(
                          onPressed: isLoading
                              ? null
                              : () => context.read<OrderCubit>().createOrder(),
                          icon: isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.receipt_long_outlined),
                          label: Text(
                            isLoading ? 'Creating Order...' : 'Create Order',
                          ),
                        ),
                      ),
                    ),
            );
          },
        );
      },
    );
  }

  static String _formatPrice(int amount) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remainingAfter = digits.length - i - 1;
      buffer.write(digits[i]);
      if (remainingAfter > 0 && remainingAfter % 3 == 0) {
        buffer.write('.');
      }
    }
    return 'Rp $buffer';
  }
}

class _EmptyCartState extends StatelessWidget {
  const _EmptyCartState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your cart is empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add products from the catalog to build a local POS sale.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to catalog'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.isTotal = false,
  });

  final String label;
  final String value;
  final bool isTotal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

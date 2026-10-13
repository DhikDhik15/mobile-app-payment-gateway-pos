import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/pages/order_confirmation_page.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';

/// Order history page.
///
/// Lists the authenticated merchant's existing orders, newest first, with
/// pagination, pull-to-refresh, and empty/error states. Tapping an order
/// reloads its latest details and reopens it in the existing read-only
/// order confirmation flow — which continues into the Phase 9C checkout
/// recovery. Nothing here creates orders or payments.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final OrderHistoryCubit _cubit;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<OrderHistoryCubit>();
    _scrollController = ScrollController()..addListener(_onScroll);
    _cubit.loadFirstPage();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _cubit.loadMore();
    }
  }

  Future<void> _openOrder(Order order) async {
    final paymentCubit = context.read<PaymentCubit>();
    final orderHistoryCubit = context.read<OrderHistoryCubit>();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: paymentCubit,
          child: OrderConfirmationPage(
            order: order,
            isReviewMode: true,
            getOrderById: orderHistoryCubit.getOrderByIdUseCase,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<OrderHistoryCubit, OrderHistoryState>(
        listener: (context, state) {
          switch (state) {
            case OrderHistoryDetailLoaded(order: final order):
              _openOrder(order);
            case OrderHistoryDetailFailure(message: final message):
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(message),
                    action: SnackBarAction(
                      label: 'Dismiss',
                      onPressed: () =>
                          context.read<OrderHistoryCubit>().dismissDetailError(),
                    ),
                  ),
                );
            case OrderHistoryInitial() ||
                OrderHistoryLoading() ||
                OrderHistoryLoaded() ||
                OrderHistoryFailure() ||
                OrderHistoryDetailLoading():
              break;
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('Order History')),
            body: switch (state) {
              OrderHistoryInitial() => const Center(
                child: CircularProgressIndicator(),
              ),
              OrderHistoryLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
              OrderHistoryLoaded(
                orders: final orders,
                hasMore: final hasMore,
                loadingMore: final loadingMore,
                loadMoreError: final loadMoreError,
              ) =>
                _OrdersList(
                  orders: orders,
                  hasMore: hasMore,
                  loadingMore: loadingMore,
                  loadMoreError: loadMoreError,
                  scrollController: _scrollController,
                  onRefresh: () => context.read<OrderHistoryCubit>().refresh(),
                  onRetryMore: () =>
                      context.read<OrderHistoryCubit>().loadMore(),
                  onOrderSelected: (order) =>
                      context.read<OrderHistoryCubit>().openOrder(order.id),
                ),
              OrderHistoryFailure(message: final message) => _ErrorView(
                message: message,
                onRetry: () =>
                    context.read<OrderHistoryCubit>().loadFirstPage(),
              ),
              OrderHistoryDetailLoading(orders: final orders) =>
                _RetainedList(orders: orders, showProgress: true),
              OrderHistoryDetailLoaded(orders: final orders) =>
                _RetainedList(orders: orders, showProgress: false),
              OrderHistoryDetailFailure(orders: final orders) =>
                _RetainedList(orders: orders, showProgress: false),
            },
          );
        },
      ),
    );
  }
}

/// Retained list shown while an order's details load (or after a detail
/// failure), so the page never blanks or loses its scroll position.
class _RetainedList extends StatelessWidget {
  const _RetainedList({required this.orders, required this.showProgress});

  final List<Order> orders;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showProgress) const LinearProgressIndicator(),
        Expanded(
          child: orders.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : _OrdersListView(orders: orders, onOrderSelected: null),
        ),
      ],
    );
  }
}

class _OrdersList extends StatelessWidget {
  const _OrdersList({
    required this.orders,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreError,
    required this.scrollController,
    required this.onRefresh,
    required this.onRetryMore,
    required this.onOrderSelected,
  });

  final List<Order> orders;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final VoidCallback onRetryMore;
  final void Function(Order order) onOrderSelected;

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return _EmptyState(onRefresh: onRefresh);
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: orders.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == orders.length) {
            return _ListFooter(
              hasMore: hasMore,
              loadingMore: loadingMore,
              loadMoreError: loadMoreError,
              onRetryMore: onRetryMore,
            );
          }
          final order = orders[index];
          return _OrderListItem(
            order: order,
            onTap: () => onOrderSelected(order),
          );
        },
      ),
    );
  }
}

/// Non-interactive order list used for retained views.
class _OrdersListView extends StatelessWidget {
  const _OrdersListView({required this.orders, required this.onOrderSelected});

  final List<Order> orders;
  final void Function(Order order)? onOrderSelected;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final order = orders[index];
        final tap = onOrderSelected;
        return _OrderListItem(
          order: order,
          onTap: tap == null ? null : () => tap(order),
        );
      },
    );
  }
}

class _OrderListItem extends StatelessWidget {
  const _OrderListItem({required this.order, required this.onTap});

  final Order order;
  final VoidCallback? onTap;

  String _abbreviatedId(String id) => id.length <= 8 ? id : id.substring(0, 8);

  String _formatMoney(int amount, String currency) {
    final digits = amount.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      final remainingAfter = digits.length - i - 1;
      buffer.write(digits[i]);
      if (remainingAfter > 0 && remainingAfter % 3 == 0) buffer.write('.');
    }
    return '$currency ${amount < 0 ? '-' : ''}$buffer';
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = order.items.fold<int>(
      0,
      (sum, item) => sum + item.quantity,
    );
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text('Order ${_abbreviatedId(order.id)}'),
        subtitle: Text(
          '$itemCount items • ${_formatMoney(order.totalAmount, order.currency)}\n'
          '${order.createdAt.toLocal()}',
        ),
        isThreeLine: true,
        trailing: Text(
          order.status,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        ),
        onTap: onTap,
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreError,
    required this.onRetryMore,
  });

  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
  final VoidCallback onRetryMore;

  @override
  Widget build(BuildContext context) {
    final error = loadMoreError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(onPressed: onRetryMore, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            'No more orders',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

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
            'No orders yet',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Orders you create will appear here for review and payment.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

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

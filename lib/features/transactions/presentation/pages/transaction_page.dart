import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/pages/order_confirmation_page.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_display.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_list_item.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_status_chip.dart';

/// Transactions list page.
///
/// Displays the paginated transaction list fetched from the GO-SAAS backend.
/// Provides navigation to the transaction detail page.
class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});

  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  late final TransactionCubit _transactionCubit;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _transactionCubit = context.read<TransactionCubit>();
    _scrollController = ScrollController()..addListener(_onScroll);
    _transactionCubit.loadTransactions();
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
      _transactionCubit.loadMore(fromScroll: true);
    }
  }

  Future<void> _openTransaction(String transactionId) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: _transactionCubit,
          child: TransactionDetailPage(transactionId: transactionId),
        ),
      ),
    );
    if (mounted) {
      await _transactionCubit.loadTransactions();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _transactionCubit,
      child: _TransactionsBody(
        onTransactionSelected: _openTransaction,
        scrollController: _scrollController,
      ),
    );
  }
}

class _TransactionsBody extends StatefulWidget {
  const _TransactionsBody({
    required this.onTransactionSelected,
    required this.scrollController,
  });

  final Future<void> Function(String transactionId) onTransactionSelected;
  final ScrollController scrollController;

  @override
  State<_TransactionsBody> createState() => _TransactionsBodyState();
}

class _TransactionsBodyState extends State<_TransactionsBody> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, state) {
          final cubit = context.read<TransactionCubit>();
          return Column(
            children: [
              _FilterBar(
                filter: cubit.filter,
                searchController: _searchController,
                onStatusChanged: (status) => cubit.setStatusFilter(status),
                onMethodChanged: (method) =>
                    cubit.setPaymentMethodFilter(method),
                onSearchSubmitted: (query) => cubit.submitSearch(query),
                onDatePressed: () => _pickDateRange(context, cubit),
                onClear: () {
                  _searchController.clear();
                  cubit.clearFilters();
                },
              ),
              Expanded(
                child: switch (state) {
                  TransactionInitial() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  TransactionLoading() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  TransactionListLoaded(
                    transactions: final transactions,
                    hasMore: final hasMore,
                    loadingMore: final loadingMore,
                    loadMoreError: final loadMoreError,
                    filter: final filter,
                  ) =>
                    _TransactionList(
                      transactions: transactions,
                      hasMore: hasMore,
                      loadingMore: loadingMore,
                      loadMoreError: loadMoreError,
                      filtered: !filter.isEmpty,
                      scrollController: widget.scrollController,
                      onTransactionSelected: widget.onTransactionSelected,
                      onRetryMore: () => cubit.loadMore(),
                    ),
                  TransactionFailure(message: final message) => _ErrorView(
                    message: message,
                    onRetry: () =>
                        context.read<TransactionCubit>().loadTransactions(),
                  ),
                  TransactionDetailLoaded() => const Center(
                    child: CircularProgressIndicator(),
                  ),
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _pickDateRange(
    BuildContext context,
    TransactionCubit cubit,
  ) async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 5);
    final lastDate = DateTime(now.year + 1);
    DateTime clamp(DateTime day) {
      if (day.isBefore(firstDate)) return firstDate;
      if (day.isAfter(lastDate)) return lastDate;
      return day;
    }
    // Invert the cubit's half-open bounds back to inclusive picked days,
    // clamped so an inconsistent stored range can never break the picker.
    var start = cubit.filter.from ?? now;
    var end = cubit.filter.to != null
        ? cubit.filter.to!.subtract(const Duration(days: 1))
        : now;
    start = clamp(start);
    end = clamp(end);
    if (start.isAfter(end)) start = end;
    final range = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: cubit.filter.from != null || cubit.filter.to != null
          ? DateTimeRange(start: start, end: end)
          : null,
    );
    if (!context.mounted) return;
    if (range != null) {
      await cubit.setDateRange(range.start, range.end);
    }
  }
}

/// The scrollable transaction list.
class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.transactions,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreError,
    required this.filtered,
    required this.scrollController,
    required this.onTransactionSelected,
    required this.onRetryMore,
  });

  final List<Transaction> transactions;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
  final bool filtered;
  final ScrollController scrollController;
  final Future<void> Function(String transactionId) onTransactionSelected;
  final VoidCallback onRetryMore;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return _EmptyState(
        filtered: filtered,
        onRefresh: () => context.read<TransactionCubit>().refresh(),
      );
    }
    return RefreshIndicator(
      onRefresh: () async {
        await context.read<TransactionCubit>().refresh();
      },
      child: ListView.separated(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: transactions.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == transactions.length) {
            return _ListFooter(
              hasMore: hasMore,
              loadingMore: loadingMore,
              loadMoreError: loadMoreError,
              onRetryMore: onRetryMore,
            );
          }
          final transaction = transactions[index];
          return TransactionListItem(
            transaction: transaction,
            onTap: () =>
                unawaited(onTransactionSelected(transaction.transactionId)),
          );
        },
      ),
    );
  }
}

/// Filter controls for status, payment method, search, and creation dates.
///
/// Search is submitted explicitly (keyboard action or search button), never
/// per keystroke, to avoid unnecessary network traffic.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.searchController,
    required this.onStatusChanged,
    required this.onMethodChanged,
    required this.onSearchSubmitted,
    required this.onDatePressed,
    required this.onClear,
  });

  final TransactionFilter filter;
  final TextEditingController searchController;
  final ValueChanged<String?> onStatusChanged;
  final ValueChanged<String?> onMethodChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onDatePressed;
  final VoidCallback onClear;

  static const _statuses = [
    'CREATED',
    'PENDING',
    'PAID',
    'FAILED',
    'EXPIRED',
    'CANCELLED',
  ];

  /// Payment methods supported by the backend contract.
  static const _methods = ['QRIS'];

  String _formatDay(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final hasDate = filter.from != null || filter.to != null;
    final dateLabel = hasDate
        ? '${filter.from != null ? _formatDay(filter.from!.toLocal()) : '…'}'
              ' → '
              '${filter.to != null ? _formatDay(filter.to!.toLocal().subtract(const Duration(days: 1))) : '…'}'
        : 'Dates';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('transaction-search-field'),
                  controller: searchController,
                  decoration: const InputDecoration(
                    hintText: 'Search ID, order, provider ref',
                    prefixIcon: Icon(Icons.search_outlined),
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: onSearchSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                key: const Key('transaction-search-submit'),
                tooltip: 'Search',
                icon: const Icon(Icons.arrow_forward_outlined),
                onPressed: () => onSearchSubmitted(searchController.text),
              ),
              if (!filter.isEmpty)
                TextButton.icon(
                  key: const Key('transaction-clear-filters'),
                  onPressed: onClear,
                  icon: const Icon(Icons.clear_outlined, size: 18),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  key: const Key('transaction-status-filter'),
                  child: DropdownButtonFormField<String?>(
                    key: Key(
                      'transaction-status-value-${filter.status ?? 'all'}',
                    ),
                    initialValue: filter.status,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All'),
                    ),
                    for (final status in _statuses)
                      DropdownMenuItem<String?>(
                        value: status,
                        child: Text(status),
                      ),
                  ],
                  onChanged: onStatusChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  key: const Key('transaction-method-filter'),
                  child: DropdownButtonFormField<String?>(
                    key: Key(
                      'transaction-method-value-${filter.paymentMethod ?? 'all'}',
                    ),
                    initialValue: filter.paymentMethod,
                  decoration: const InputDecoration(
                    labelText: 'Method',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All'),
                    ),
                    for (final method in _methods)
                      DropdownMenuItem<String?>(
                        value: method,
                        child: Text(method),
                      ),
                  ],
                  onChanged: onMethodChanged,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                key: const Key('transaction-date-filter'),
                onPressed: onDatePressed,
                icon: const Icon(Icons.date_range_outlined, size: 18),
                label: Text(dateLabel),
              ),
            ],
          ),
        ],
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
            FilledButton.tonal(
              onPressed: onRetryMore,
              child: const Text('Retry'),
            ),
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
            'No more transactions',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

/// Empty state shown when no transactions exist.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.filtered, required this.onRefresh});

  final bool filtered;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 64),
          const Icon(Icons.inbox_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            filtered ? 'No matching transactions' : 'No transactions yet',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          if (filtered)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Try adjusting or clearing the filters.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
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

/// Transaction detail page.
///
/// Displays full transaction information fetched from the GO-SAAS backend.
class TransactionDetailPage extends StatefulWidget {
  const TransactionDetailPage({super.key, required this.transactionId});

  final String transactionId;

  @override
  State<TransactionDetailPage> createState() => _TransactionDetailPageState();
}

class _TransactionDetailPageState extends State<TransactionDetailPage> {
  late final TransactionCubit _transactionCubit;

  @override
  void initState() {
    super.initState();
    _transactionCubit = context.read<TransactionCubit>();
    _transactionCubit.loadTransactionById(widget.transactionId);
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _transactionCubit,
      child: _TransactionDetailBody(transactionId: widget.transactionId),
    );
  }
}

class _TransactionDetailBody extends StatefulWidget {
  const _TransactionDetailBody({required this.transactionId});

  final String transactionId;

  @override
  State<_TransactionDetailBody> createState() => _TransactionDetailBodyState();
}

class _TransactionDetailBodyState extends State<_TransactionDetailBody> {
  /// Last transaction loaded for [widget.transactionId]. Retained while
  /// unrelated states pass through the shared cubit; never shows another
  /// transaction's data.
  Transaction? _lastTransaction;

  bool _isBusy(TransactionState state) => state is TransactionLoading;

  /// Re-reads this transaction by its identifier. Never creates payments,
  /// never changes status locally — only the backend response updates state.
  Future<void> _refresh() async {
    if (!mounted) return;
    final state = context.read<TransactionCubit>().state;
    if (_isBusy(state)) return;
    await context
        .read<TransactionCubit>()
        .loadTransactionById(widget.transactionId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Detail'),
        actions: [
          BlocBuilder<TransactionCubit, TransactionState>(
            builder: (context, state) {
              final busy = _isBusy(state);
              return IconButton(
                key: const Key('transaction-detail-refresh'),
                tooltip: 'Refresh transaction',
                onPressed: busy ? null : _refresh,
                icon: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_outlined),
              );
            },
          ),
        ],
      ),
      body: BlocListener<OrderHistoryCubit, OrderHistoryState>(
        listener: (context, state) {
          switch (state) {
            case OrderHistoryDetailLoaded(order: final order):
              final paymentCubit = context.read<PaymentCubit>();
              final orderHistoryCubit = context.read<OrderHistoryCubit>();
              Navigator.of(context).push(
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
            case OrderHistoryDetailFailure(message: final message):
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            case OrderHistoryInitial() ||
                OrderHistoryLoading() ||
                OrderHistoryLoaded() ||
                OrderHistoryFailure() ||
                OrderHistoryDetailLoading():
              break;
          }
        },
        child: BlocConsumer<TransactionCubit, TransactionState>(
        listener: (context, state) {
          if (state is TransactionDetailLoaded &&
              state.transaction.transactionId == widget.transactionId) {
            setState(() => _lastTransaction = state.transaction);
          } else if (state is TransactionFailure && _lastTransaction != null) {
            // A refresh failure must not discard retained details; surface
            // it as transient feedback instead.
            final cached = _lastTransaction;
            if (cached != null &&
                cached.transactionId == widget.transactionId) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.message)));
            }
          }
        },
        builder: (context, state) {
          final cached = _lastTransaction;
          final cachedForThisPage =
              cached != null && cached.transactionId == widget.transactionId;
          return switch (state) {
            TransactionDetailLoaded(transaction: final transaction)
                when transaction.transactionId == widget.transactionId =>
              _TransactionDetail(
                transaction: transaction,
                onRefresh: _refresh,
              ),
            TransactionFailure(message: final message) => cachedForThisPage
                ? _TransactionDetail(
                    transaction: cached,
                    onRefresh: _refresh,
                  )
                : _DetailErrorView(
                    message: message,
                    onRetry: () => context
                        .read<TransactionCubit>()
                        .loadTransactionById(widget.transactionId),
                  ),
            _ when cachedForThisPage =>
              _TransactionDetail(
                transaction: cached,
                onRefresh: _refresh,
              ),
            _ => const Center(
              child: CircularProgressIndicator(),
            ),
          };
        },
      ),
      ),
    );
  }
}

/// The full transaction detail view.
///
/// The header shows the same [transactionDisplayName] as the history list
/// so both pages stay consistent.
class _TransactionDetail extends StatelessWidget {
  const _TransactionDetail({required this.transaction, required this.onRefresh});

  final Transaction transaction;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              transactionDisplayName(transaction),
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            TransactionStatusChip(status: transaction.status),
            const SizedBox(height: 16),
            _DetailRow(
              label: 'Transaction ID',
              value: transaction.transactionId,
              copyable: true,
            ),
            // The merchant order reference doubles as the header (history
            // list title) for non-product transactions, so it is repeated
            // as a row only when the header shows a product name — keeping
            // the reference visible as secondary information.
            if (productSummaryTitle(transaction.orderSummary) != null &&
                transaction.merchantOrderId.trim().isNotEmpty)
              _DetailRow(
                label: 'Merchant Order ID',
                value: transaction.merchantOrderId,
              ),
            if (transaction.orderId != null) ...[
            _DetailRow(
              label: 'Order ID',
              value: transaction.orderId!,
              copyable: true,
            ),
            FilledButton.tonalIcon(
              key: const Key('transaction-view-order'),
              onPressed: () => context
                  .read<OrderHistoryCubit>()
                  .openOrder(transaction.orderId!),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('View order'),
            ),
            const SizedBox(height: 12),
          ],
          _DetailRow(
            label: 'Amount',
            value: '${transaction.amount} ${transaction.currency}',
          ),
          _DetailRow(label: 'Payment Method', value: transaction.paymentMethod),
          _DetailRow(
            label: 'Status',
            value: transaction.status.apiValue,
            trailing: TransactionStatusChip(status: transaction.status),
          ),
          if (transaction.provider != null)
            _DetailRow(label: 'Provider', value: transaction.provider!),
          if (transaction.providerTransactionId != null)
            _DetailRow(
              label: 'Provider Transaction ID',
              value: transaction.providerTransactionId!,
            ),
          if (transaction.paymentUrl != null)
            _DetailRow(
              label: 'Payment URL',
              value: transaction.paymentUrl!,
              copyable: true,
            ),
          if (transaction.expiredAt != null)
            _DetailRow(
              label: 'Expires At',
              value: _formatDateTime(transaction.expiredAt!),
            ),
          if (transaction.paidAt != null)
            _DetailRow(
              label: 'Paid At',
              value: _formatDateTime(transaction.paidAt!),
            ),
          _DetailRow(
            label: 'Created At',
            value: _formatDateTime(transaction.createdAt),
          ),
          _DetailRow(
            label: 'Updated At',
            value: _formatDateTime(transaction.updatedAt),
          ),
        ],
        ),
      ),
    );
  }
}

/// A single detail row with label and value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.copyable = false,
  });

  final String label;
  final String value;
  final Widget? trailing;
  final bool copyable;

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
              if (copyable)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  },
                ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }
}

/// Error view with retry for detail page.
class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.message, required this.onRetry});

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

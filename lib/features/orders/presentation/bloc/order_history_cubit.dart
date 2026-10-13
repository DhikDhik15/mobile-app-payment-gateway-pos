import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:payment_simulator/features/orders/domain/usecases/list_orders.dart';

/// Default page size for order history, following the backend convention.
const int orderHistoryPageSize = 20;

/// Cubit that manages merchant order history.
///
/// Dedicated to listing and reopening existing orders. Independent from the
/// cart-coupled [OrderCubit], which remains the only writer of new orders.
/// No method here creates orders, payments, or any other resource.
class OrderHistoryCubit extends Cubit<OrderHistoryState> {
  OrderHistoryCubit({
    required this.listOrdersUseCase,
    required this.getOrderByIdUseCase,
    this.pageSize = orderHistoryPageSize,
  }) : super(const OrderHistoryInitial());

  final ListOrdersUseCase listOrdersUseCase;
  final GetOrderByIdUseCase getOrderByIdUseCase;
  final int pageSize;

  /// Monotonic fetch epoch. Every new list fetch bumps it; completions from
  /// an older epoch (e.g. a load-more overtaken by a refresh) are ignored so
  /// a stale response can never overwrite or append to newer data.
  int _epoch = 0;

  /// Loads the first page, replacing any previously loaded orders.
  Future<void> loadFirstPage() async {
    if (state is OrderHistoryLoading) return;
    final epoch = ++_epoch;
    emit(const OrderHistoryLoading());
    final result = await listOrdersUseCase(
      ListOrdersParams(page: 1, limit: pageSize),
    );
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case OrderSuccess(value: final page):
        emit(
          OrderHistoryLoaded(
            orders: _deduplicated(const [], page.orders),
            page: page.page,
            hasMore: page.hasMore,
          ),
        );
      case OrderError(failure: final failure):
        emit(OrderHistoryFailure(failure.message));
    }
  }

  /// Refreshes the first page. Unlike [loadFirstPage], a failed refresh
  /// keeps the previously loaded orders visible.
  Future<void> refresh() async {
    final current = state;
    final retained = current is OrderHistoryLoaded ? current.orders : const <Order>[];
    if (current is! OrderHistoryLoaded) {
      return loadFirstPage();
    }
    final epoch = ++_epoch;
    final result = await listOrdersUseCase(
      ListOrdersParams(page: 1, limit: pageSize),
    );
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case OrderSuccess(value: final page):
        emit(
          OrderHistoryLoaded(
            orders: _deduplicated(const [], page.orders),
            page: page.page,
            hasMore: page.hasMore,
          ),
        );
      case OrderError():
        emit(
          OrderHistoryLoaded(
            orders: retained,
            page: current.page,
            hasMore: current.hasMore,
            loadMoreError:
                'Could not refresh orders. Showing previously loaded entries.',
          ),
        );
    }
  }

  /// Loads the next page and appends it, deduplicated by order ID.
  /// Concurrent calls collapse into one request; a failed page load keeps
  /// already loaded entries with a recoverable inline error.
  Future<void> loadMore() async {
    final current = state;
    if (current is! OrderHistoryLoaded) return;
    if (current.loadingMore || !current.hasMore) return;
    final epoch = ++_epoch;
    emit(current.copyWith(loadingMore: true, loadMoreError: null));
    final result = await listOrdersUseCase(
      ListOrdersParams(page: current.page + 1, limit: pageSize),
    );
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case OrderSuccess(value: final page):
        emit(
          OrderHistoryLoaded(
            orders: _deduplicated(current.orders, page.orders),
            page: page.page,
            hasMore: page.hasMore,
          ),
        );
      case OrderError():
        emit(
          current.copyWith(
            loadingMore: false,
            loadMoreError:
                'Could not load more orders. Check your connection and retry.',
          ),
        );
    }
  }

  /// Loads one order's latest details for reopening. Emits
  /// [OrderHistoryDetailLoaded] on success; the page listener navigates.
  /// Never creates or mutates anything.
  Future<void> openOrder(String orderId) async {
    final current = state;
    final retained = current is OrderHistoryLoaded ? current.orders : const <Order>[];
    final pageHint = current is OrderHistoryLoaded ? current.page : 1;
    final hasMoreHint =
        current is OrderHistoryLoaded ? current.hasMore : false;
    emit(
      OrderHistoryDetailLoading(
        orders: retained,
        pageHint: pageHint,
        hasMoreHint: hasMoreHint,
      ),
    );
    final result = await getOrderByIdUseCase(
      GetOrderByIdParams(orderId: orderId),
    );
    if (isClosed) return;
    switch (result) {
      case OrderSuccess(value: final order):
        emit(OrderHistoryDetailLoaded(order: order, orders: retained));
      case OrderError(failure: final failure):
        emit(
          OrderHistoryDetailFailure(
            orders: retained,
            message: failure.message,
            pageHint: pageHint,
            hasMoreHint: hasMoreHint,
          ),
        );
    }
  }

  /// Returns to the retained list after a detail failure, without refetching.
  void dismissDetailError() {
    final current = state;
    if (current is! OrderHistoryDetailFailure) return;
    emit(
      OrderHistoryLoaded(
        orders: current.orders,
        page: current.orders.isEmpty ? 1 : current.pageHint,
        hasMore: current.hasMoreHint,
      ),
    );
  }

  static List<Order> _deduplicated(List<Order> existing, List<Order> incoming) {
    final ids = {for (final order in existing) order.id};
    return [
      ...existing,
      for (final order in incoming)
        if (ids.add(order.id)) order,
    ];
  }
}

/// Order history states.
sealed class OrderHistoryState {
  const OrderHistoryState();
}

/// Initial state — no load attempted yet.
final class OrderHistoryInitial extends OrderHistoryState {
  const OrderHistoryInitial();
}

/// The first page is loading and no orders are retained.
final class OrderHistoryLoading extends OrderHistoryState {
  const OrderHistoryLoading();
}

/// Orders loaded. [loadingMore] marks an in-flight next page;
/// [loadMoreError] carries a recoverable page/refresh failure while the
/// retained [orders] stay visible.
final class OrderHistoryLoaded extends OrderHistoryState {
  const OrderHistoryLoaded({
    required this.orders,
    required this.page,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<Order> orders;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;

  OrderHistoryLoaded copyWith({
    List<Order>? orders,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? loadMoreError,
  }) {
    return OrderHistoryLoaded(
      orders: orders ?? this.orders,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: loadMoreError,
    );
  }
}

/// The first page failed and no orders are retained.
final class OrderHistoryFailure extends OrderHistoryState {
  const OrderHistoryFailure(this.message);

  final String message;
}

/// A single order's details are loading; the retained list stays visible.
final class OrderHistoryDetailLoading extends OrderHistoryState {
  const OrderHistoryDetailLoading({
    required this.orders,
    this.pageHint = 1,
    this.hasMoreHint = false,
  });

  final List<Order> orders;

  /// Pagination hints preserved so a later failure can restore the exact
  /// previous list state.
  final int pageHint;
  final bool hasMoreHint;
}

/// A single order's details loaded; the page listener navigates.
/// [orders] is retained so popping back never shows a blank page.
final class OrderHistoryDetailLoaded extends OrderHistoryState {
  const OrderHistoryDetailLoaded({required this.order, required this.orders});

  final Order order;
  final List<Order> orders;
}

/// Detail loading failed; the retained list stays visible with an error.
final class OrderHistoryDetailFailure extends OrderHistoryState {
  const OrderHistoryDetailFailure({
    required this.orders,
    required this.message,
    this.pageHint = 1,
    this.hasMoreHint = false,
  });

  final List<Order> orders;
  final String message;

  /// Pagination hints preserved across the failure so dismissing it can
  /// restore the exact previous list state.
  final int pageHint;
  final bool hasMoreHint;
}

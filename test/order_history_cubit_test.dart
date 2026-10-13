import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';
import 'package:payment_simulator/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:payment_simulator/features/orders/domain/usecases/list_orders.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';

class _FakeOrderRepository implements OrderRepository {
  Future<OrderResult<OrderPage>> Function(int page, int limit)? onList;
  Future<OrderResult<Order>> Function(String orderId)? onGet;
  int listCalls = 0;

  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async =>
      OrderError(const ServerFailure());

  @override
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  }) async {
    listCalls++;
    return onList!(page, limit);
  }

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async =>
      onGet!(orderId);
}

Order _order(String id) => Order(
  id: id,
  status: 'CREATED',
  currency: 'IDR',
  subtotal: 20000,
  totalAmount: 20000,
  createdAt: DateTime.parse('2026-10-07T08:00:00Z'),
  updatedAt: DateTime.parse('2026-10-07T08:00:00Z'),
  items: const [
    OrderItem(
      id: 'item-1',
      productId: 'p1',
      productName: 'Coffee',
      quantity: 2,
      unitPrice: 10000,
      subtotal: 20000,
    ),
  ],
);

OrderPage _page(List<Order> orders, {int page = 1, bool hasMore = false}) =>
    OrderPage(
      orders: orders,
      page: page,
      limit: 20,
      total: orders.length,
      totalPages: hasMore ? page + 1 : page,
    );

OrderHistoryCubit _cubit(_FakeOrderRepository repo) => OrderHistoryCubit(
  listOrdersUseCase: ListOrdersUseCase(repo),
  getOrderByIdUseCase: GetOrderByIdUseCase(repo),
);

void main() {
  group('OrderHistoryCubit', () {
    test('starts in OrderHistoryInitial', () {
      expect(_cubit(_FakeOrderRepository()).state, isA<OrderHistoryInitial>());
    });

    test('loads the first page with default size 20', () async {
      var requestedLimit = 0;
      final repo = _FakeOrderRepository()
        ..onList = (page, limit) async {
          requestedLimit = limit;
          return OrderSuccess(_page([_order('order-1')]));
        };
      final cubit = _cubit(repo);

      await cubit.loadFirstPage();

      expect(requestedLimit, 20);
      final state = cubit.state;
      expect(state, isA<OrderHistoryLoaded>());
      expect((state as OrderHistoryLoaded).orders.length, 1);
      expect(state.hasMore, isFalse);
    });

    test('empty list loads successfully', () async {
      final repo = _FakeOrderRepository()
        ..onList = (_, _) async => OrderSuccess(_page(const []));
      final cubit = _cubit(repo);

      await cubit.loadFirstPage();

      final state = cubit.state;
      expect(state, isA<OrderHistoryLoaded>());
      expect((state as OrderHistoryLoaded).orders, isEmpty);
    });

    test('initial failure emits failure and retry recovers', () async {
      var calls = 0;
      final repo = _FakeOrderRepository()
        ..onList = (_, _) async {
          calls++;
          return calls == 1
              ? const OrderError<OrderPage>(ServerFailure())
              : OrderSuccess(_page([_order('order-1')]));
        };
      final cubit = _cubit(repo);

      await cubit.loadFirstPage();
      expect(cubit.state, isA<OrderHistoryFailure>());

      await cubit.loadFirstPage();
      expect(cubit.state, isA<OrderHistoryLoaded>());
      expect(repo.listCalls, 2);
    });

    test('never requests a page below 1', () async {
      final pages = <int>[];
      final repo = _FakeOrderRepository()
        ..onList = (page, _) async {
          pages.add(page);
          return OrderSuccess(_page([_order('order-$page')], hasMore: true));
        };
      final cubit = _cubit(repo);

      await cubit.loadFirstPage();
      await cubit.loadMore();

      expect(pages, [1, 2]);
    });

    test('appends pages deduplicated by order id', () async {
      final repo = _FakeOrderRepository()
        ..onList = (page, _) async {
          if (page == 1) {
            return OrderSuccess(
              _page([_order('order-1'), _order('order-2')], hasMore: true),
            );
          }
          // Overlapping second page repeats order-2.
          return OrderSuccess(
            _page([_order('order-2'), _order('order-3')]),
          );
        };
      final cubit = _cubit(repo);

      await cubit.loadFirstPage();
      await cubit.loadMore();

      final state = cubit.state as OrderHistoryLoaded;
      expect(state.orders.map((o) => o.id), ['order-1', 'order-2', 'order-3']);
      expect(state.hasMore, isFalse);
    });

    test('concurrent loadMore calls collapse into one request', () async {
      final gate = Completer<OrderResult<OrderPage>>();
      final repo = _FakeOrderRepository()
        ..onList = (page, _) async {
          if (page == 1) return OrderSuccess(_page([_order('o1')], hasMore: true));
          return gate.future;
        };
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();

      final first = cubit.loadMore();
      final second = cubit.loadMore();
      await Future<void>.delayed(Duration.zero);
      // Page 1 + exactly one page-2 request while both callers wait.
      expect(repo.listCalls, 2);
      gate.complete(OrderSuccess(_page([_order('o2')])));
      await Future.wait([first, second]);
      final state = cubit.state as OrderHistoryLoaded;
      expect(state.orders.length, 2);
    });

    test('loadMore stops when no more pages exist', () async {
      final repo = _FakeOrderRepository()
        ..onList = (_, _) async => OrderSuccess(_page([_order('o1')]));
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();

      await cubit.loadMore();

      expect(repo.listCalls, 1);
    });

    test('loadMore failure preserves entries with a retry path', () async {
      var calls = 0;
      final repo = _FakeOrderRepository()
        ..onList = (page, _) async {
          calls++;
          if (page == 1) {
            return OrderSuccess(_page([_order('o1')], hasMore: true));
          }
          if (calls == 2) return const OrderError<OrderPage>(ServerFailure());
          return OrderSuccess(_page([_order('o2')]));
        };
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();

      await cubit.loadMore();
      var state = cubit.state as OrderHistoryLoaded;
      expect(state.orders.length, 1);
      expect(state.loadMoreError, isNotNull);

      await cubit.loadMore();
      state = cubit.state as OrderHistoryLoaded;
      expect(state.orders.length, 2);
      expect(state.loadMoreError, isNull);
    });

    test('refresh replaces stale data', () async {
      var calls = 0;
      final repo = _FakeOrderRepository()
        ..onList = (_, _) async {
          calls++;
          return calls == 1
              ? OrderSuccess(_page([_order('old')], hasMore: true))
              : OrderSuccess(_page([_order('new')]));
        };
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();
      await cubit.refresh();

      final state = cubit.state as OrderHistoryLoaded;
      expect(state.orders.map((o) => o.id), ['new']);
      expect(state.hasMore, isFalse);
    });

    test('failed refresh keeps previously loaded entries', () async {
      var calls = 0;
      final repo = _FakeOrderRepository()
        ..onList = (_, _) async {
          calls++;
          return calls == 1
              ? OrderSuccess(_page([_order('o1')], hasMore: true))
              : const OrderError<OrderPage>(ConnectionFailure());
        };
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();
      await cubit.refresh();

      final state = cubit.state as OrderHistoryLoaded;
      expect(state.orders.length, 1);
      expect(state.loadMoreError, isNotNull);
    });

    test('stale overlapping responses are ignored', () async {
      final gate = Completer<OrderResult<OrderPage>>();
      final repo = _FakeOrderRepository()
        ..onList = (page, _) {
          if (page == 2) return gate.future;
          return Future.value(OrderSuccess(_page([_order('fresh')])));
        };
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();

      // Re-seed page 1 with more content, then start a page-2 load that a
      // refresh overtakes.
      repo.onList = (page, _) {
        if (page == 1) {
          return Future.value(
            OrderSuccess(_page([_order('fresh')], hasMore: true)),
          );
        }
        return gate.future;
      };
      await cubit.refresh();
      final loadingMore = cubit.loadMore();
      await cubit.refresh();
      gate.complete(OrderSuccess(_page([_order('stale')])));
      await loadingMore;

      final state = cubit.state as OrderHistoryLoaded;
      expect(state.orders.map((o) => o.id), ['fresh']);
    });

    test('openOrder loads details for navigation', () async {
      final repo = _FakeOrderRepository();
      repo.onList = (_, _) async => OrderSuccess(_page([_order('o1')]));
      repo.onGet = (id) async => OrderSuccess(_order(id));
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();

      await cubit.openOrder('o1');

      final state = cubit.state;
      expect(state, isA<OrderHistoryDetailLoaded>());
      expect((state as OrderHistoryDetailLoaded).order.id, 'o1');
      expect(state.orders.length, 1);
    });

    test('openOrder failure retains the list', () async {
      final repo = _FakeOrderRepository();
      repo.onList = (_, _) async => OrderSuccess(_page([_order('o1')]));
      repo.onGet = (_) async =>
          const OrderError<Order>(ApiFailure(404, 'missing'));
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();

      await cubit.openOrder('gone');

      final state = cubit.state;
      expect(state, isA<OrderHistoryDetailFailure>());
      expect((state as OrderHistoryDetailFailure).orders.length, 1);
    });

    test('dismissDetailError restores the retained list state', () async {
      final repo = _FakeOrderRepository();
      repo.onList = (page, _) async => page == 1
          ? OrderSuccess(_page([_order('o1')], hasMore: true))
          : OrderSuccess(_page([_order('o2')], page: page));
      repo.onGet = (_) async =>
          const OrderError<Order>(ApiFailure(404, 'missing'));
      final cubit = _cubit(repo);
      await cubit.loadFirstPage();
      await cubit.loadMore();
      await cubit.openOrder('gone');

      expect(cubit.state, isA<OrderHistoryDetailFailure>());

      cubit.dismissDetailError();

      final state = cubit.state;
      expect(state, isA<OrderHistoryLoaded>());
      final loaded = state as OrderHistoryLoaded;
      expect(loaded.orders.map((o) => o.id), ['o1', 'o2']);
      expect(loaded.page, 2);
      expect(loaded.hasMore, isFalse);
      expect(loaded.loadMoreError, isNull);
    });
  });
}

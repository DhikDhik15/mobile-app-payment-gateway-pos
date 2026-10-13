import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/orders/data/datasources/order_remote_data_source.dart';
import 'package:payment_simulator/features/orders/data/repositories/order_repository_impl.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';

class _FakeOrderRemoteDataSource implements OrderRemoteDataSource {
  AppException? error;
  Order? result;
  OrderPage? listResult;

  @override
  Future<Order> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async {
    if (error != null) throw error!;
    return result!;
  }

  @override
  Future<OrderPage> listOrders({
    required int page,
    required int limit,
  }) async {
    if (error != null) throw error!;
    return listResult!;
  }

  @override
  Future<Order> getOrderById(String orderId) async {
    if (error != null) throw error!;
    return result!;
  }
}

Order _order() => Order(
  id: 'order-1',
  status: 'CREATED',
  currency: 'IDR',
  subtotal: 20000,
  totalAmount: 20000,
  createdAt: DateTime.parse('2026-10-07T08:00:00Z'),
  updatedAt: DateTime.parse('2026-10-07T08:00:00Z'),
  items: const [],
);

void main() {
  test('returns the parsed order on success', () async {
    final expected = _order();
    final remote = _FakeOrderRemoteDataSource()..result = expected;
    final repository = OrderRepositoryImpl(remote);

    final result = await repository.createOrder(
      items: const [OrderItemInput(productId: 'p1', quantity: 2)],
      idempotencyKey: 'order-key-1',
    );

    expect(result, isA<OrderSuccess<Order>>());
    expect((result as OrderSuccess<Order>).value, same(expected));
  });

  for (final status in [400, 401, 403, 409, 500]) {
    test('maps HTTP $status into a user-safe API failure', () async {
      final remote = _FakeOrderRemoteDataSource()
        ..error = ApiException(status, 'raw server detail');
      final repository = OrderRepositoryImpl(remote);

      final result = await repository.createOrder(
        items: const [OrderItemInput(productId: 'p1', quantity: 1)],
        idempotencyKey: 'order-key-1',
      );

      expect(result, isA<OrderError<Order>>());
      final failure = (result as OrderError<Order>).failure;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, status);
      expect(failure.message, isNot('raw server detail'));
      expect(failure.message, isNot(contains('DioException')));
    });
  }

  test('maps network timeouts into domain failures', () async {
    final remote = _FakeOrderRemoteDataSource()
      ..error = const NetworkTimeoutException();
    final repository = OrderRepositoryImpl(remote);

    final result = await repository.createOrder(
      items: const [OrderItemInput(productId: 'p1', quantity: 1)],
      idempotencyKey: 'order-key-1',
    );

    expect(result, isA<OrderError<Order>>());
    expect((result as OrderError<Order>).failure, isA<TimeoutFailure>());
  });

  test('maps connection failures into domain failures', () async {
    final remote = _FakeOrderRemoteDataSource()
      ..error = const ConnectionNetworkException();
    final repository = OrderRepositoryImpl(remote);

    final result = await repository.createOrder(
      items: const [OrderItemInput(productId: 'p1', quantity: 1)],
      idempotencyKey: 'order-key-1',
    );

    expect(result, isA<OrderError<Order>>());
    expect((result as OrderError<Order>).failure, isA<ConnectionFailure>());
  });

  test('returns a parsed order page on list success', () async {
    final remote = _FakeOrderRemoteDataSource()
      ..listResult = OrderPage(
        orders: [_order()],
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
      );
    final repository = OrderRepositoryImpl(remote);

    final result = await repository.listOrders(page: 1, limit: 20);

    expect(result, isA<OrderSuccess<OrderPage>>());
    final page = (result as OrderSuccess<OrderPage>).value;
    expect(page.orders.length, 1);
    expect(page.hasMore, isFalse);
  });

  test('maps list failures without leaking server details', () async {
    final remote = _FakeOrderRemoteDataSource()
      ..error = const ApiException(500, 'raw server detail');
    final repository = OrderRepositoryImpl(remote);

    final result = await repository.listOrders(page: 1, limit: 20);

    expect(result, isA<OrderError<OrderPage>>());
    final failure = (result as OrderError<OrderPage>).failure;
    expect(failure, isA<ApiFailure>());
    expect(failure.message, isNot('raw server detail'));
  });

  test('returns the parsed order on detail success', () async {
    final remote = _FakeOrderRemoteDataSource()..result = _order();
    final repository = OrderRepositoryImpl(remote);

    final result = await repository.getOrderById('order-1');

    expect(result, isA<OrderSuccess<Order>>());
    expect((result as OrderSuccess<Order>).value.id, 'order-1');
  });

  test('maps a missing or foreign order into a not-found failure', () async {
    final remote = _FakeOrderRemoteDataSource()
      ..error = const ApiException(404, 'Order not found');
    final repository = OrderRepositoryImpl(remote);

    final result = await repository.getOrderById('order-1');

    expect(result, isA<OrderError<Order>>());
    final failure = (result as OrderError<Order>).failure;
    expect(failure, isA<ApiFailure>());
    expect((failure as ApiFailure).statusCode, 404);
    expect(failure.message, 'The order could not be found.');
  });
}

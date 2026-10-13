import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';
import 'package:payment_simulator/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:payment_simulator/features/orders/domain/usecases/list_orders.dart';

class _FakeOrderRepository implements OrderRepository {
  OrderResult<OrderPage>? listResult;
  OrderResult<Order>? getResult;
  ListOrdersParams? lastListParams;
  String? lastGetId;

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
    lastListParams = ListOrdersParams(page: page, limit: limit);
    return listResult!;
  }

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async {
    lastGetId = orderId;
    return getResult!;
  }
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

void main() {
  group('ListOrdersUseCase', () {
    test('delegates pagination and returns the page', () async {
      final repo = _FakeOrderRepository()
        ..listResult = OrderSuccess(
          OrderPage(
            orders: [_order('order-1')],
            page: 2,
            limit: 20,
            total: 21,
            totalPages: 2,
          ),
        );
      final useCase = ListOrdersUseCase(repo);

      final result = await useCase(
        const ListOrdersParams(page: 2, limit: 20),
      );

      expect(result, isA<OrderSuccess<OrderPage>>());
      expect(repo.lastListParams?.page, 2);
      expect(repo.lastListParams?.limit, 20);
      expect((result as OrderSuccess<OrderPage>).value.orders.length, 1);
    });

    test('propagates repository failures', () async {
      final repo = _FakeOrderRepository()
        ..listResult = const OrderError(ServerFailure());
      final useCase = ListOrdersUseCase(repo);

      final result = await useCase(
        const ListOrdersParams(page: 1, limit: 20),
      );

      expect(result, isA<OrderError<OrderPage>>());
    });
  });

  group('GetOrderByIdUseCase', () {
    test('delegates the lookup and returns the order', () async {
      final repo = _FakeOrderRepository()
        ..getResult = OrderSuccess(_order('order-1'));
      final useCase = GetOrderByIdUseCase(repo);

      final result = await useCase(
        const GetOrderByIdParams(orderId: 'order-1'),
      );

      expect(result, isA<OrderSuccess<Order>>());
      expect(repo.lastGetId, 'order-1');
      expect((result as OrderSuccess<Order>).value.id, 'order-1');
    });

    test('propagates repository failures', () async {
      final repo = _FakeOrderRepository()
        ..getResult = const OrderError(ApiFailure(404, 'missing'));
      final useCase = GetOrderByIdUseCase(repo);

      final result = await useCase(
        const GetOrderByIdParams(orderId: 'order-1'),
      );

      expect(result, isA<OrderError<Order>>());
    });
  });
}

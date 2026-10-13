import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart_item.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';
import 'package:payment_simulator/features/orders/domain/usecases/create_order.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_cubit.dart';

class _FakeOrderRepository implements OrderRepository {
  OrderResult<Order>? result;
  Completer<OrderResult<Order>>? pending;
  int calls = 0;
  final List<List<OrderItemInput>> submittedItems = [];
  final List<String> idempotencyKeys = [];

  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) {
    calls++;
    submittedItems.add(List.of(items));
    idempotencyKeys.add(idempotencyKey);
    if (pending != null) return pending!.future;
    return Future.value(result ?? OrderError(const ServerFailure()));
  }

  @override
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  }) async =>
      OrderError(const ServerFailure());

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async =>
      OrderError(const ServerFailure());
}

Order _order() => Order(
  id: 'order-1',
  status: 'CREATED',
  currency: 'IDR',
  subtotal: 35000,
  totalAmount: 35000,
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
    OrderItem(
      id: 'item-2',
      productId: 'p2',
      productName: 'Cake',
      quantity: 1,
      unitPrice: 15000,
      subtotal: 15000,
    ),
  ],
);

void main() {
  group('OrderCubit', () {
    late CartCubit cartCubit;
    late _FakeOrderRepository repository;
    late OrderCubit cubit;

    setUp(() {
      cartCubit = CartCubit();
      repository = _FakeOrderRepository();
      cubit = OrderCubit(
        createOrderUseCase: CreateOrderUseCase(repository),
        cartCubit: cartCubit,
      );
    });

    tearDown(() async {
      await cubit.close();
      await cartCubit.close();
    });

    test('starts in OrderInitial', () {
      expect(cubit.state, isA<OrderInitial>());
    });

    test(
      'submits only IDs and quantities and clears cart on success',
      () async {
        cartCubit
          ..add(
            const CartItem(
              productId: 'p1',
              name: 'Local coffee name',
              quantity: 2,
              unitPrice: 1,
            ),
          )
          ..add(
            const CartItem(
              productId: 'p2',
              name: 'Local cake name',
              quantity: 1,
              unitPrice: 999999,
            ),
          );
        repository.result = OrderSuccess(_order());
        final states = <OrderState>[];
        final subscription = cubit.stream.listen(states.add);

        await cubit.createOrder();

        expect(cubit.state, isA<OrderCreated>());
        expect(states, contains(isA<OrderLoading>()));
        expect(cartCubit.state.items, isEmpty);
        expect(cartCubit.state.total, 0);
        expect(
          repository.submittedItems.single
              .map((item) => (item.productId, item.quantity))
              .toList(),
          [('p1', 2), ('p2', 1)],
        );
        expect(repository.idempotencyKeys.single, startsWith('order-'));
        await subscription.cancel();
      },
    );

    test('retains the cart on failure and reuses key for retry', () async {
      cartCubit.add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 2,
          unitPrice: 10000,
        ),
      );
      repository.result = OrderError(const ApiFailure(409, 'Conflict'));

      await cubit.createOrder();
      final firstKey = repository.idempotencyKeys.single;
      expect(cubit.state, isA<OrderFailure>());
      expect(cartCubit.state.items, hasLength(1));

      await cubit.createOrder();

      expect(repository.idempotencyKeys, [firstKey, firstKey]);
      expect(cartCubit.state.items, hasLength(1));
    });

    test('does not submit duplicate requests while loading', () async {
      cartCubit.add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 1,
          unitPrice: 10000,
        ),
      );
      repository.pending = Completer<OrderResult<Order>>();

      final firstRequest = cubit.createOrder();
      await Future<void>.delayed(Duration.zero);
      await cubit.createOrder();

      expect(cubit.state, isA<OrderLoading>());
      expect(repository.calls, 1);

      repository.pending!.complete(OrderSuccess(_order()));
      await firstRequest;
      expect(cubit.state, isA<OrderCreated>());
      expect(cartCubit.state.items, isEmpty);
    });

    test('changed cart gets a new idempotency key', () async {
      cartCubit.add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 1,
          unitPrice: 10000,
        ),
      );
      repository.result = OrderError(const ApiFailure(500));
      await cubit.createOrder();
      final firstKey = repository.idempotencyKeys.single;

      cartCubit.setQuantity('p1', 2);
      await cubit.createOrder();

      expect(repository.idempotencyKeys.last, isNot(firstKey));
    });

    test('reset invalidates a pending result after logout', () async {
      cartCubit.add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 1,
          unitPrice: 10000,
        ),
      );
      repository.pending = Completer<OrderResult<Order>>();
      final request = cubit.createOrder();
      await Future<void>.delayed(Duration.zero);

      cubit.reset();
      repository.pending!.complete(OrderSuccess(_order()));
      await request;

      expect(cubit.state, isA<OrderInitial>());
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart_item.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/cart/presentation/pages/cart_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';
import 'package:payment_simulator/features/orders/domain/usecases/create_order.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_cubit.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';

class _FakeOrderRepository implements OrderRepository {
  _FakeOrderRepository(this.result);

  final OrderResult<Order> result;

  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async => result;

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

Order _createdOrder() => Order(
  id: 'order-123',
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

/// Minimal [PaymentRepository] fake so CartPage's Order-created navigation
/// (which threads the shared [PaymentCubit] forward) resolves in tests.
class _FakePaymentRepository implements PaymentRepository {
  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async => PaymentError(const ServerFailure());
}

PaymentCubit _testPaymentCubit() => PaymentCubit(
  listPayments: ListPaymentsUseCase(_FakePaymentRepository()),
  getPayment: GetPaymentUseCase(_FakePaymentRepository()),
  createPayment: CreatePaymentUseCase(_FakePaymentRepository()),
  simulateSuccess: SimulatePaymentSuccessUseCase(_FakePaymentRepository()),
  simulateFail: SimulatePaymentFailUseCase(_FakePaymentRepository()),
);

Widget _cartApp({required OrderResult<Order> result, required CartCubit cart}) {
  final orderCubit = OrderCubit(
    createOrderUseCase: CreateOrderUseCase(_FakeOrderRepository(result)),
    cartCubit: cart,
  );
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: cart),
      BlocProvider.value(value: orderCubit),
      BlocProvider.value(value: _testPaymentCubit()),
    ],
    child: const MaterialApp(home: CartPage()),
  );
}

void main() {
  testWidgets('successful create shows confirmation and leaves cart empty', (
    tester,
  ) async {
    final cart = CartCubit()
      ..add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 2,
          unitPrice: 10000,
        ),
      );
    await tester.pumpWidget(
      _cartApp(result: OrderSuccess(_createdOrder()), cart: cart),
    );

    await tester.tap(find.text('Create Order'));
    await tester.pumpAndSettle();

    expect(find.text('Order created successfully'), findsOneWidget);
    expect(find.text('order-123'), findsOneWidget);
    expect(find.text('CREATED'), findsOneWidget);
    expect(cart.state.items, isEmpty);
    expect(cart.state.total, 0);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Your cart is empty'), findsOneWidget);
  });

  testWidgets('failed create preserves cart for retry', (tester) async {
    final cart = CartCubit()
      ..add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 2,
          unitPrice: 10000,
        ),
      );
    await tester.pumpWidget(
      _cartApp(
        result: const OrderError(
          ApiFailure(400, 'The product is unavailable.'),
        ),
        cart: cart,
      ),
    );

    await tester.tap(find.text('Create Order'));
    await tester.pumpAndSettle();

    expect(find.text('The product is unavailable.'), findsOneWidget);
    expect(find.text('Coffee'), findsOneWidget);
    expect(find.text('Create Order'), findsOneWidget);
    expect(cart.state.items, hasLength(1));
    expect(cart.state.total, 20000);
  });
}

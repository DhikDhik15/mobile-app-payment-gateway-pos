import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
import 'package:payment_simulator/features/orders/presentation/pages/orders_page.dart';
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
  Future<OrderResult<OrderPage>> Function(int page, int limit)? onList;
  Future<OrderResult<Order>> Function(String orderId)? onGet;
  int createCalls = 0;

  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async {
    createCalls++;
    return OrderError(const ServerFailure());
  }

  @override
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  }) async =>
      onList!(page, limit);

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async =>
      onGet!(orderId);
}

class _FakePaymentRepository implements PaymentRepository {
  Future<PaymentResult<List<Payment>>> Function(String orderId)?
  orderPaymentsHandler;

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
  ) async {
    if (orderPaymentsHandler != null) {
      return orderPaymentsHandler!(orderId);
    }
    return const PaymentSuccess(<Payment>[]);
  }
}

Order _order(String id, {String status = 'CREATED'}) => Order(
  id: id,
  status: status,
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

Payment _payment({PaymentStatus status = PaymentStatus.paid}) => Payment(
  transactionId: 'tx-001',
  orderId: '11111111-1111-1111-1111-111111111111',
  merchantOrderId: 'order-order-1-a',
  amount: 20000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: status,
  createdAt: DateTime.parse('2026-10-07T08:00:00Z'),
  updatedAt: DateTime.parse('2026-10-07T08:00:00Z'),
);

OrderHistoryCubit _historyCubit(_FakeOrderRepository repo) => OrderHistoryCubit(
  listOrdersUseCase: ListOrdersUseCase(repo),
  getOrderByIdUseCase: GetOrderByIdUseCase(repo),
);

PaymentCubit _paymentCubit(_FakePaymentRepository repo) => PaymentCubit(
  listPayments: ListPaymentsUseCase(repo),
  getPayment: GetPaymentUseCase(repo),
  createPayment: CreatePaymentUseCase(repo),
  simulateSuccess: SimulatePaymentSuccessUseCase(repo),
  simulateFail: SimulatePaymentFailUseCase(repo),
);

Widget _ordersApp({
  required OrderHistoryCubit historyCubit,
  required PaymentCubit paymentCubit,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider.value(value: paymentCubit),
        BlocProvider.value(value: historyCubit),
      ],
      child: const OrdersPage(),
    ),
  );
}

Future<void> _tapOrderTile(WidgetTester tester, String idPrefix) async {
  final finder = find.textContaining(idPrefix);
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  // Flush the tap frame plus the cubit notification frame.
  await tester.pump();
  await tester.pump();
}

void main() {
  group('OrdersPage', () {
    testWidgets('loads and lists orders', (tester) async {
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (_, _) async =>
          OrderSuccess(_page([_order('11111111-1111-1111-1111-111111111111'), _order('22222222-2222-2222-2222-222222222222')]));
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: _historyCubit(orderRepo),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Order History'), findsOneWidget);
      expect(find.textContaining('11111111'), findsOneWidget);
      expect(find.textContaining('22222222'), findsOneWidget);
      expect(find.text('CREATED', skipOffstage: false), findsWidgets);
    });

    testWidgets('empty history shows the empty state', (tester) async {
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (_, _) async => OrderSuccess(_page(const []));
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: _historyCubit(orderRepo),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No orders yet'), findsOneWidget);
      expect(find.byType(ListTile), findsNothing);
    });

    testWidgets('initial failure shows retry and recovers', (tester) async {
      var calls = 0;
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (_, _) async {
        calls++;
        return calls == 1
            ? const OrderError<OrderPage>(ServerFailure())
            : OrderSuccess(_page([_order('11111111-1111-1111-1111-111111111111')]));
      };
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: _historyCubit(orderRepo),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
      expect(find.textContaining('11111111'), findsNothing);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.textContaining('11111111'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('pull-to-refresh replaces stale data', (tester) async {
      List<Order> seed(String tag) => [
            for (var i = 0; i < 10; i++) _order('$tag-0000-0000-000$i-00000000000$i'),
          ];
      var calls = 0;
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (_, _) async {
        calls++;
        return calls == 1
            ? OrderSuccess(_page(seed('aaaaaaaa')))
            : OrderSuccess(_page(seed('bbbbbbbb')));
      };
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: _historyCubit(orderRepo),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('aaaaaaaa'), findsWidgets);

      await tester.fling(
        find.byType(ListView).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('bbbbbbbb'), findsWidgets);
      expect(find.textContaining('aaaaaaaa'), findsNothing);
      expect(calls, 2);
    });

    testWidgets('scrolling loads the next page once', (tester) async {
      List<Order> seed(String tag) => [
            for (var i = 0; i < 10; i++) _order('$tag-0000-0000-000$i-00000000000$i'),
          ];
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (page, _) async => page == 1
          ? OrderSuccess(_page(seed('11111111'), hasMore: true))
          : OrderSuccess(_page(seed('22222222'), page: page));
      final historyCubit = _historyCubit(orderRepo);
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: historyCubit,
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('11111111'), findsWidgets);
      expect(find.textContaining('22222222'), findsWidgets);
    });

    testWidgets('tap reopens the order in review mode', (tester) async {
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (_, _) async => OrderSuccess(_page([_order('11111111-1111-1111-1111-111111111111')]));
      orderRepo.onGet = (id) async => OrderSuccess(_order(id));
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: _historyCubit(orderRepo),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await _tapOrderTile(tester, '11111111');
      await tester.pumpAndSettle();

      // Review mode: details header, continue action, no cart return, and
      // the order was reloaded — never recreated.
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.text('Order created successfully'), findsNothing);
      expect(find.text('Return to Cart'), findsNothing);
      expect(find.text('Continue to Payment'), findsOneWidget);
      expect(orderRepo.createCalls, 0);
    });

    testWidgets('continue reaches checkout with paid recovery', (
      tester,
    ) async {
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (_, _) async => OrderSuccess(_page([_order('11111111-1111-1111-1111-111111111111')]));
      orderRepo.onGet = (id) async => OrderSuccess(_order(id));
      final paymentRepo = _FakePaymentRepository();
      paymentRepo.orderPaymentsHandler =
          (_) async => PaymentSuccess([_payment(status: PaymentStatus.paid)]);
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: _historyCubit(orderRepo),
          paymentCubit: _paymentCubit(paymentRepo),
        ),
      );
      await tester.pumpAndSettle();

      await _tapOrderTile(tester, '11111111');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Continue to Payment'));
      await tester.pump();
      await tester.tap(find.text('Continue to Payment'));
      await tester.pumpAndSettle();

      // Phase 9C recovery: paid history hides Pay, offers the payment.
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Payment PAID'), findsOneWidget);
      expect(find.byKey(const Key('checkout-pay-button')), findsNothing);
    });

    testWidgets('foreign order shows an error without navigating', (
      tester,
    ) async {
      final orderRepo = _FakeOrderRepository();
      orderRepo.onList = (_, _) async => OrderSuccess(_page([_order('11111111-1111-1111-1111-111111111111')]));
      orderRepo.onGet = (_) async =>
          const OrderError<Order>(ApiFailure(404, 'missing'));
      await tester.pumpWidget(
        _ordersApp(
          historyCubit: _historyCubit(orderRepo),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await _tapOrderTile(tester, '11111111');
      await tester.pumpAndSettle();

      // A visible error with no navigation; the list is retained and no
      // order is created. (Message mapping itself is covered at the
      // repository layer; the fake surfaces the raw failure here.)
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Order Details'), findsNothing);
      expect(find.textContaining('11111111'), findsOneWidget);
      expect(orderRepo.createCalls, 0);
    });
  });
}

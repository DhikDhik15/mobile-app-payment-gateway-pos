import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payment_checkout_page.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payment_detail_page.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _PostCall {
  _PostCall(this.path, this.body, this.headers);
  final String path;
  final Object? body;
  final Map<String, String>? headers;
}

class _FakeApiClient implements ApiClient {
  NetworkResponse? postResponse;
  final List<_PostCall> postCalls = [];

  @override
  void setAuthToken(String? token) {}

  @override
  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    postCalls.add(_PostCall(path, body, headers));
    return postResponse!;
  }

  @override
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  Future<NetworkResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  Future<NetworkResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();
}

class _FakePaymentRepository implements PaymentRepository {
  Future<PaymentResult<Payment>> Function({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  })? orderPaymentHandler;
  Future<PaymentResult<List<Payment>>> Function(String orderId)?
      orderPaymentsHandler;
  PaymentResult<Payment>? getResult;
  PaymentResult<Payment>? simulateSuccessResult;
  int orderPaymentCalls = 0;
  int orderPaymentsCalls = 0;
  String? lastIdempotencyKey;
  final List<String> idempotencyKeys = [];

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async =>
      getResult ?? PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async =>
      simulateSuccessResult ?? PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    orderPaymentCalls++;
    lastIdempotencyKey = idempotencyKey;
    idempotencyKeys.add(idempotencyKey);
    return orderPaymentHandler!(
      orderId: orderId,
      paymentMethod: paymentMethod,
      idempotencyKey: idempotencyKey,
    );
  }

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async {
    orderPaymentsCalls++;
    if (orderPaymentsHandler != null) {
      return orderPaymentsHandler!(orderId);
    }
    // Default: no recorded attempts, so existing tests exercise the Pay path.
    return const PaymentSuccess(<Payment>[]);
  }
}

// ─── Fixtures ────────────────────────────────────────────────────────────────

Order _order() => Order(
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

Payment _payment({
  PaymentStatus status = PaymentStatus.pending,
  String? orderId,
  String transactionId = 'tx-001',
}) =>
    Payment(
      transactionId: transactionId,
      orderId: orderId,
      merchantOrderId: 'order-order-123-attempt-1',
      amount: 20000,
      currency: 'IDR',
      paymentMethod: 'QRIS',
      status: status,
      createdAt: DateTime.parse('2026-10-07T08:00:00Z'),
      updatedAt: DateTime.parse('2026-10-07T08:00:00Z'),
    );

NetworkResponse _createdPaymentResponse() => NetworkResponse(
  statusCode: 201,
  data: {
    'transaction_id': 'tx-001',
    'order_id': 'order-123',
    'merchant_order_id': 'order-order-123-attempt-1',
    'amount': 20000,
    'currency': 'IDR',
    'payment_method': 'QRIS',
    'provider': 'mock',
    'provider_transaction_id': 'prov-tx-001',
    'payment_url': 'http://localhost:5173/pay/mock-1',
    'status': 'PENDING',
    'created_at': '2026-10-07T08:00:00Z',
    'updated_at': '2026-10-07T08:00:00Z',
  },
);

PaymentCubit _cubit(_FakePaymentRepository repo) => PaymentCubit(
  listPayments: ListPaymentsUseCase(repo),
  getPayment: GetPaymentUseCase(repo),
  createPayment: CreatePaymentUseCase(repo),
  simulateSuccess: SimulatePaymentSuccessUseCase(repo),
  simulateFail: SimulatePaymentFailUseCase(repo),
);

/// Scrolls an action into view before tapping it. Checkout content exceeds
/// the 800x600 test viewport, so bare taps would miss below-the-fold buttons.
/// Uses bounded pumps: quiescence waiting can hang on scroll animations.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
}

Widget _checkoutApp(PaymentCubit cubit, {String? idempotencyKey}) {
  return MaterialApp(
    home: BlocProvider.value(
      value: cubit,
      child: PaymentCheckoutPage(
        order: _order(),
        idempotencyKey: idempotencyKey,
      ),
    ),
  );
}

void main() {
  group('createOrderPayment request contract', () {
    test('posts only payment_method to the order payments endpoint', () async {
      final api = _FakeApiClient()..postResponse = _createdPaymentResponse();
      final remote = PaymentRemoteDataSourceImpl(api);

      await remote.createOrderPayment(
        orderId: 'order-123',
        paymentMethod: 'QRIS',
        idempotencyKey: 'order:order-123:qris:v1',
      );

      expect(api.postCalls, hasLength(1));
      final call = api.postCalls.single;
      expect(call.path, '/api/v1/dashboard/orders/order-123/payments');
      expect(call.body, {'payment_method': 'QRIS'});
      final body = call.body as Map<String, dynamic>;
      for (final forbidden in [
        'amount',
        'currency',
        'merchant_id',
        'total_amount',
        'subtotal',
        'unit_price',
        'merchant_order_id',
      ]) {
        expect(body.containsKey(forbidden), isFalse, reason: forbidden);
      }
      expect(call.headers?['Idempotency-Key'], 'order:order-123:qris:v1');
    });
  });

  group('PaymentCheckoutPage', () {
    testWidgets('renders order summary with QRIS selected', (tester) async {
      final repo = _FakePaymentRepository();
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('order-123'), findsOneWidget);
      expect(find.text('QRIS'), findsOneWidget);
      expect(find.text('Coffee'), findsOneWidget);
      expect(find.byKey(const Key('checkout-pay-button')), findsOneWidget);
      // No amount/currency inputs — totals are display-only.
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('pay uses the stable idempotency key', (tester) async {
      final repo = _FakePaymentRepository()
        ..orderPaymentHandler =
            ({required orderId, required paymentMethod, required idempotencyKey}) async =>
                PaymentSuccess(_payment());
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();

      expect(repo.orderPaymentCalls, 1);
      expect(repo.lastIdempotencyKey, 'order:order-123:qris:v1');
    });

    testWidgets('duplicate taps while creating issue a single request', (
      tester,
    ) async {
      final gate = Completer<PaymentResult<Payment>>();
      final repo = _FakePaymentRepository()
        ..orderPaymentHandler =
            ({required orderId, required paymentMethod, required idempotencyKey}) =>
                gate.future;
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout-pay-button')));
      await tester.pump();
      // Button disables while PaymentCreating — second tap is a no-op.
      await tester.tap(find.byKey(const Key('checkout-pay-button')));
      await tester.pump();

      expect(repo.orderPaymentCalls, 1);

      gate.complete(PaymentSuccess(_payment()));
      await tester.pumpAndSettle();
      expect(repo.orderPaymentCalls, 1);
    });

    testWidgets('successful payment navigates to payment detail', (
      tester,
    ) async {
      final created = _payment(status: PaymentStatus.pending);
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async =>
              PaymentSuccess(created);
      repo.getResult = PaymentSuccess(created);
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();

      // Navigated to the detail page for the created transaction.
      expect(find.text('Payment Detail'), findsOneWidget);
      expect(find.text('tx-001'), findsOneWidget);
    });

    testWidgets('failed payment shows an error and stays on checkout', (
      tester,
    ) async {
      final repo = _FakePaymentRepository()
        ..orderPaymentHandler =
            ({required orderId, required paymentMethod, required idempotencyKey}) async =>
                PaymentError(const ApiFailure(409, 'Order already has an active payment'));
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();

      expect(find.text('Order already has an active payment'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Payment Detail'), findsNothing);
    });

    testWidgets('back button returns to the order', (tester) async {
      final repo = _FakePaymentRepository();
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      expect(find.text('Back to Order'), findsOneWidget);
    });

    testWidgets('ignores unrelated PaymentCreated emissions', (tester) async {
      final repo = _FakePaymentRepository()
        ..orderPaymentHandler =
            ({required orderId, required paymentMethod, required idempotencyKey}) async =>
                PaymentSuccess(_payment());
      final cubit = _cubit(repo);
      await tester.pumpWidget(_checkoutApp(cubit));
      await tester.pumpAndSettle();

      // A PaymentCreated from another flow must not navigate this checkout.
      cubit.emit(PaymentCreated(_payment()));
      await tester.pumpAndSettle();

      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Payment Detail'), findsNothing);
      expect(repo.orderPaymentCalls, 0);
    });

    testWidgets('definitive failure recovers via history-derived key', (
      tester,
    ) async {
      final failed = _payment(status: PaymentStatus.failed);
      var historyCalls = 0;
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async {
            if (idempotencyKey == 'order:order-123:qris:v1') {
              return PaymentError(
                const ApiFailure(502, 'provider failed', 'PAYMENT_PROVIDER_ERROR'),
              );
            }
            return PaymentSuccess(_payment());
          };
      repo.orderPaymentsHandler = (_) async {
        historyCalls++;
        // First load: nothing recorded. After the failed submit the backend
        // recorded the terminal attempt, so recovery sees it.
        if (historyCalls == 1) return const PaymentSuccess(<Payment>[]);
        return PaymentSuccess([failed]);
      };
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      // One explicit tap: base attempt fails definitively, recovery derives
      // the fresh attempt key, and the chained retry succeeds.
      await _tapVisible(tester, find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();

      expect(repo.idempotencyKeys, [
        'order:order-123:qris:v1',
        'order:order-123:qris:v1:retry:1',
      ]);
      expect(find.text('Payment Detail'), findsOneWidget);
    });

    testWidgets('reconstructed checkout resumes from FAILED history', (
      tester,
    ) async {
      // Simulates a fresh page after restart: no in-memory counter, but the
      // backend reports the terminal attempt, so Pay uses retry:1 directly.
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async =>
              PaymentSuccess(_payment());
      repo.orderPaymentsHandler =
          (_) async => PaymentSuccess([_payment(status: PaymentStatus.failed)]);
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();

      expect(repo.idempotencyKeys, ['order:order-123:qris:v1:retry:1']);
    });

    testWidgets('active history hides Pay and offers the payment', (
      tester,
    ) async {
      var submitted = false;
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async {
            submitted = true;
            return PaymentSuccess(_payment());
          };
      repo.orderPaymentsHandler = (_) async => PaymentSuccess([
            _payment(status: PaymentStatus.pending, orderId: 'order-123'),
          ]);
      repo.getResult = PaymentSuccess(
        _payment(status: PaymentStatus.pending, orderId: 'order-123'),
      );
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkout-pay-button')), findsNothing);
      expect(find.text('Payment PENDING'), findsOneWidget);
      expect(submitted, isFalse);

      await _tapVisible(tester, find.byKey(const Key('checkout-view-payment')));
      await tester.pumpAndSettle();
      expect(find.text('Payment Detail'), findsOneWidget);
      expect(submitted, isFalse);
    });

    testWidgets('paid history hides Pay and offers the payment', (
      tester,
    ) async {
      var submitted = false;
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async {
            submitted = true;
            return PaymentSuccess(_payment());
          };
      repo.orderPaymentsHandler = (_) async => PaymentSuccess([
            _payment(status: PaymentStatus.paid, orderId: 'order-123'),
          ]);
      repo.getResult = PaymentSuccess(
        _payment(status: PaymentStatus.paid, orderId: 'order-123'),
      );
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('checkout-pay-button')), findsNothing);
      expect(find.text('Payment PAID'), findsOneWidget);
      expect(submitted, isFalse);
    });

    testWidgets('recovery failure blocks Pay until history loads', (
      tester,
    ) async {
      var submitted = false;
      var historyCalls = 0;
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async {
            submitted = true;
            return PaymentSuccess(_payment());
          };
      repo.orderPaymentsHandler = (_) async {
        historyCalls++;
        if (historyCalls == 1) {
          return PaymentError(const ConnectionFailure());
        }
        return const PaymentSuccess(<Payment>[]);
      };
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      // No Pay action while the payment state is unknown.
      expect(find.text('Payment status unavailable'), findsOneWidget);
      expect(find.byKey(const Key('checkout-pay-button')), findsNothing);
      expect(submitted, isFalse);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('checkout-pay-button')), findsOneWidget);
      expect(submitted, isFalse);
    });

    testWidgets('ambiguous timeout keeps its key when history is unchanged', (
      tester,
    ) async {
      // 504 with an empty history that stays empty: the timed-out request
      // recorded nothing new, so exactly one provably-fresh key is spent
      // (guards still forbid any duplicate server-side).
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async {
            if (idempotencyKey == 'order:order-123:qris:v1') {
              return PaymentError(
                const ApiFailure(504, 'provider timed out', 'PAYMENT_PROVIDER_TIMEOUT'),
              );
            }
            return PaymentSuccess(_payment());
          };
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();

      expect(repo.idempotencyKeys, [
        'order:order-123:qris:v1',
        'order:order-123:qris:v1:retry:1',
      ]);
    });

    testWidgets('stale conflict replays once, then spends a fresh key', (
      tester,
    ) async {
      // History already terminal, but the derived key replays a stored
      // conflict: exactly one fresh key follows, then recovery stops.
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async {
            if (idempotencyKey == 'order:order-123:qris:v1:retry:2') {
              return PaymentSuccess(_payment());
            }
            return PaymentError(
              const ApiFailure(409, 'conflict', 'INVALID_TRANSACTION_STATE'),
            );
          };
      repo.orderPaymentsHandler = (_) async => PaymentSuccess([
            _payment(status: PaymentStatus.failed, orderId: 'order-123'),
          ]);
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();

      expect(repo.idempotencyKeys, [
        'order:order-123:qris:v1:retry:1',
        'order:order-123:qris:v1:retry:2',
      ]);
    });

    testWidgets('foreign-order history items are ignored', (tester) async {
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async =>
              PaymentSuccess(_payment());
      repo.orderPaymentsHandler = (_) async => PaymentSuccess([
            _payment(status: PaymentStatus.paid, orderId: 'order-OTHER'),
          ]);
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      // Only this order's payments drive the page.
      expect(find.byKey(const Key('checkout-pay-button')), findsOneWidget);
    });

    testWidgets('created payment replaces Pay with a detail path', (
      tester,
    ) async {
      final created = _payment(status: PaymentStatus.pending);
      final repo = _FakePaymentRepository();
      repo.orderPaymentHandler =
          ({required orderId, required paymentMethod, required idempotencyKey}) async =>
              PaymentSuccess(created);
      repo.getResult = PaymentSuccess(created);
      await tester.pumpWidget(_checkoutApp(_cubit(repo)));
      await tester.pumpAndSettle();

      await _tapVisible(tester, find.byKey(const Key('checkout-pay-button')));
      await tester.pumpAndSettle();
      expect(find.text('Payment Detail'), findsOneWidget);

      // Back on checkout: Pay is gone, existing payment is offered instead.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.byKey(const Key('checkout-pay-button')), findsNothing);
      expect(find.byKey(const Key('checkout-created-card')), findsOneWidget);

      await _tapVisible(tester, find.byKey(const Key('checkout-view-payment')));
      await tester.pumpAndSettle();
      expect(find.text('Payment Detail'), findsOneWidget);
      expect(repo.orderPaymentCalls, 1);
    });
  });

  group('PaymentDetailPage states', () {
    testWidgets('renders PaymentSimulated the same as a loaded detail', (
      tester,
    ) async {
      final paid = _payment(status: PaymentStatus.paid);
      final repo = _FakePaymentRepository();
      repo.getResult = PaymentSuccess(paid);
      repo.simulateSuccessResult = PaymentSuccess(paid);
      final cubit = _cubit(repo);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const PaymentDetailPage(paymentId: 'tx-001'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // loadPayment → PaymentDetailLoaded renders the detail.
      expect(find.text('tx-001'), findsOneWidget);

      // Simulate success → PaymentSimulated must keep rendering the detail.
      await cubit.simulateSuccess('tx-001');
      await tester.pumpAndSettle();
      expect(cubit.state, isA<PaymentSimulated>());
      expect(find.text('Payment Detail'), findsOneWidget);
      expect(find.text('tx-001'), findsOneWidget);
    });
  });
}

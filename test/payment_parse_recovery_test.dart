import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:payment_simulator/features/payments/data/models/payment_model.dart';
import 'package:payment_simulator/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payment_checkout_page.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeApiClient implements ApiClient {
  NetworkResponse? Function(String path)? onGet;
  NetworkResponse? postResponse;
  final List<String> postPaths = [];
  final List<Map<String, String>?> postHeaders = [];
  int getCalls = 0;

  @override
  void setAuthToken(String? token) {}

  @override
  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    getCalls++;
    return onGet!(path)!;
  }

  @override
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    postPaths.add(path);
    postHeaders.add(headers);
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

/// Repository whose remote throws a raw (non-[AppException]) error, as the
/// pre-fix parsing path did.
class _ThrowingRemoteDataSource extends PaymentRemoteDataSource {
  @override
  Future<PaymentModel> createPayment({
    required String merchantOrderId,
    required int amount,
    required String currency,
    required String paymentMethod,
    required String idempotencyKey,
  }) async => throw UnimplementedError();

  @override
  Future<PaymentModel> getPayment(String paymentId) async =>
      throw UnimplementedError();

  @override
  Future<List<PaymentModel>> listPayments() async =>
      throw UnimplementedError();

  @override
  Future<PaymentModel> simulateSuccess(String paymentId) async =>
      throw UnimplementedError();

  @override
  Future<PaymentModel> simulateFail(String paymentId) async =>
      throw UnimplementedError();

  @override
  Future<PaymentModel> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    // The exact pre-fix failure: null cast inside fromJson.
    throw TypeError();
  }

  @override
  Future<List<PaymentModel>> listOrderPayments(String orderId) async =>
      throw UnimplementedError();
}

// ─── Sanitized fixtures ──────────────────────────────────────────────────────
//
// Shapes mirror the backend DTOs in
// pay-gate-backend/internal/model/transaction.go:
// * `PaymentResponse` (GET/detail/history) always carries `updated_at`.
// * `CreatePaymentResponse` (POST .../orders/{id}/payments, HTTP 201) carries
//   no `updated_at` and no `paid_at`.

Map<String, dynamic> _paymentResponseJson() => {
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
  'expired_at': '2026-10-08T08:00:00Z',
  'created_at': '2026-10-07T08:00:00Z',
  'updated_at': '2026-10-07T08:00:00Z',
};

/// HTTP 201 body for order-scoped creation: no `updated_at`, no `paid_at`.
Map<String, dynamic> _createPaymentResponseJson() => {
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
};

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

PaymentCubit _cubitWith(ApiClient api) {
  final repo = PaymentRepositoryImpl(PaymentRemoteDataSourceImpl(api));
  return PaymentCubit(
    listPayments: ListPaymentsUseCase(repo),
    getPayment: GetPaymentUseCase(repo),
    createPayment: CreatePaymentUseCase(repo),
    simulateSuccess: SimulatePaymentSuccessUseCase(repo),
    simulateFail: SimulatePaymentFailUseCase(repo),
  );
}

Future<void> _tapPay(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('checkout-pay-button')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(find.byKey(const Key('checkout-pay-button')));
}

void main() {
  group('PaymentModel.fromJson contract', () {
    test('parses a valid payment response', () {
      final payment = PaymentModel.fromJson(_paymentResponseJson());

      expect(payment.transactionId, 'tx-001');
      expect(payment.merchantOrderId, 'order-order-123-attempt-1');
      expect(payment.status, PaymentStatus.pending);
      expect(payment.updatedAt, DateTime.parse('2026-10-07T08:00:00Z'));
    });

    test('parses a 201 creation response without updated_at', () {
      final payment = PaymentModel.fromJson(_createPaymentResponseJson());

      expect(payment.transactionId, 'tx-001');
      expect(payment.orderId, 'order-123');
      expect(payment.status, PaymentStatus.pending);
      // A just-created payment has no update yet: falls back to creation.
      // Nothing is fabricated — no URL, ID, or status is invented.
      expect(payment.updatedAt, payment.createdAt);
      expect(payment.paidAt, isNull);
    });

    test('missing updated_at key parses (was the reported crash)', () {
      final json = _createPaymentResponseJson()..remove('updated_at');
      expect(() => PaymentModel.fromJson(json), returnsNormally);
    });

    test('missing required transaction_id still throws', () {
      final json = _paymentResponseJson()..remove('transaction_id');
      expect(() => PaymentModel.fromJson(json), throwsA(isA<TypeError>()));
    });

    test('missing required created_at still throws', () {
      final json = _paymentResponseJson()..remove('created_at');
      expect(() => PaymentModel.fromJson(json), throwsA(isA<TypeError>()));
    });
  });

  group('PaymentRemoteDataSource.createOrderPayment parsing', () {
    test('201 without updated_at parses and keeps the idempotency key', () async {
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(
          statusCode: 201,
          data: _createPaymentResponseJson(),
        );
      final remote = PaymentRemoteDataSourceImpl(api);

      final payment = await remote.createOrderPayment(
        orderId: 'order-123',
        paymentMethod: 'QRIS',
        idempotencyKey: 'order:order-123:qris:v1',
      );

      expect(payment.transactionId, 'tx-001');
      expect(payment.updatedAt, payment.createdAt);
      // No new key is generated to work around parsing: the same key goes out.
      expect(api.postPaths, hasLength(1));
      expect(
        api.postHeaders.single?['Idempotency-Key'],
        'order:order-123:qris:v1',
      );
    });

    test('missing required field throws typed InvalidResponseException', () async {
      final json = _createPaymentResponseJson()..remove('transaction_id');
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(statusCode: 201, data: json);
      final remote = PaymentRemoteDataSourceImpl(api);

      expect(
        () => remote.createOrderPayment(
          orderId: 'order-123',
          paymentMethod: 'QRIS',
          idempotencyKey: 'order:order-123:qris:v1',
        ),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('unknown status throws typed InvalidResponseException', () async {
      final json = _createPaymentResponseJson()..['status'] = 'MYSTERIOUS';
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(statusCode: 201, data: json);
      final remote = PaymentRemoteDataSourceImpl(api);

      expect(
        () => remote.createOrderPayment(
          orderId: 'order-123',
          paymentMethod: 'QRIS',
          idempotencyKey: 'order:order-123:qris:v1',
        ),
        throwsA(isA<InvalidResponseException>()),
      );
    });
  });

  group('PaymentRepositoryImpl.createOrderPayment (integrated stack)', () {
    PaymentRepositoryImpl repoWith(Map<String, dynamic> body) {
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(statusCode: 201, data: body);
      return PaymentRepositoryImpl(PaymentRemoteDataSourceImpl(api));
    }

    test('maps a malformed payload to InvalidResponseFailure, not a throw', () async {
      final json = _createPaymentResponseJson()..remove('transaction_id');
      final repo = repoWith(json);

      // Must return a typed result: the UI loading state depends on it.
      final result = await repo.createOrderPayment(
        orderId: 'order-123',
        paymentMethod: 'QRIS',
        idempotencyKey: 'order:order-123:qris:v1',
      );

      expect(result, isA<PaymentError<Payment>>());
      final failure = (result as PaymentError<Payment>).failure;
      expect(failure, isA<InvalidResponseFailure>());
    });

    test('returns success for the 201 creation shape', () async {
      final repo = repoWith(_createPaymentResponseJson());

      final result = await repo.createOrderPayment(
        orderId: 'order-123',
        paymentMethod: 'QRIS',
        idempotencyKey: 'order:order-123:qris:v1',
      );

      expect(result, isA<PaymentSuccess<Payment>>());
    });
  });

  group('PaymentCubit.createOrderPayment robustness', () {
    test('raw remote throw becomes PaymentFailure instead of hanging', () async {
      final cubit = PaymentCubit(
        listPayments: ListPaymentsUseCase(
          PaymentRepositoryImpl(_ThrowingRemoteDataSource()),
        ),
        getPayment: GetPaymentUseCase(
          PaymentRepositoryImpl(_ThrowingRemoteDataSource()),
        ),
        createPayment: CreatePaymentUseCase(
          PaymentRepositoryImpl(_ThrowingRemoteDataSource()),
        ),
        simulateSuccess: SimulatePaymentSuccessUseCase(
          PaymentRepositoryImpl(_ThrowingRemoteDataSource()),
        ),
        simulateFail: SimulatePaymentFailUseCase(
          PaymentRepositoryImpl(_ThrowingRemoteDataSource()),
        ),
      );
      addTearDown(cubit.close);

      // Must not throw: the cubit converts it to a failure state so the
      // checkout loading indicator can clear.
      await cubit.createOrderPayment(
        orderId: 'order-123',
        paymentMethod: 'QRIS',
        idempotencyKey: 'order:order-123:qris:v1',
      );

      expect(cubit.state, isA<PaymentFailure>());
    });
  });

  group('PaymentCheckoutPage parse-recovery (end to end)', () {
    testWidgets('201 creation shape pays and navigates (no spinner hang)', (
      tester,
    ) async {
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(
          statusCode: 201,
          data: _createPaymentResponseJson(),
        )
        ..onGet = (path) {
          if (path.endsWith('/payments')) {
            return NetworkResponse(statusCode: 200, data: const <dynamic>[]);
          }
          return NetworkResponse(
            statusCode: 200,
            data: _paymentResponseJson(),
          );
        };
      final cubit = _cubitWith(api);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: PaymentCheckoutPage(order: _order()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapPay(tester);
      await tester.pumpAndSettle();

      // Existing success flow: navigates to the created payment detail.
      expect(find.text('Payment Detail'), findsOneWidget);
      expect(find.text('tx-001'), findsWidgets);
      // Exactly one creation POST with the stable key — no duplicates.
      expect(api.postPaths, hasLength(1));
      expect(
        api.postHeaders.single?['Idempotency-Key'],
        'order:order-123:qris:v1',
      );
    });

    testWidgets('unparseable 201 clears loading with an error, no resubmit', (
      tester,
    ) async {
      final invalid = _createPaymentResponseJson()
        ..remove('transaction_id');
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(statusCode: 201, data: invalid)
        ..onGet = (_) =>
            NetworkResponse(statusCode: 200, data: const <dynamic>[]);
      final cubit = _cubitWith(api);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: PaymentCheckoutPage(order: _order()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapPay(tester);
      await tester.pumpAndSettle();

      // Loading cleared: Pay is offered again instead of spinning forever.
      expect(find.byKey(const Key('checkout-pay-button')), findsOneWidget);
      expect(find.text('Creating payment…'), findsNothing);
      // Actionable typed error, still on checkout.
      expect(find.text('The server returned an invalid response'), findsOneWidget);
      expect(find.text('Checkout'), findsOneWidget);
      expect(find.text('Payment Detail'), findsNothing);
      // No automatic duplicate: one creation POST, same key preserved.
      expect(api.postPaths, hasLength(1));
      expect(
        api.postHeaders.single?['Idempotency-Key'],
        'order:order-123:qris:v1',
      );
    });

    testWidgets('unparseable 201 recovers the created payment from history', (
      tester,
    ) async {
      final invalid = _createPaymentResponseJson()
        ..remove('transaction_id');
      var historyCalls = 0;
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(statusCode: 201, data: invalid)
        ..onGet = (path) {
          if (path.endsWith('/payments')) {
            historyCalls++;
            // Initial recovery: nothing recorded. After the failed submit the
            // server holds the created attempt, so recovery finds it.
            if (historyCalls == 1) {
              return NetworkResponse(
                statusCode: 200,
                data: const <dynamic>[],
              );
            }
            return NetworkResponse(
              statusCode: 200,
              data: [_paymentResponseJson()],
            );
          }
          return NetworkResponse(
            statusCode: 200,
            data: _paymentResponseJson(),
          );
        };
      final cubit = _cubitWith(api);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: PaymentCheckoutPage(order: _order()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapPay(tester);
      await tester.pumpAndSettle();

      // Guided recovery: the existing payment is shown, Pay is gone, and no
      // second creation POST was ever issued.
      expect(find.text('Payment PENDING'), findsOneWidget);
      expect(find.byKey(const Key('checkout-pay-button')), findsNothing);
      expect(api.postPaths, hasLength(1));
    });

    testWidgets('existing successful checkout behavior is preserved', (
      tester,
    ) async {
      final api = _FakeApiClient()
        ..postResponse = NetworkResponse(
          statusCode: 201,
          data: _paymentResponseJson(),
        )
        ..onGet = (path) {
          if (path.endsWith('/payments')) {
            return NetworkResponse(statusCode: 200, data: const <dynamic>[]);
          }
          return NetworkResponse(
            statusCode: 200,
            data: _paymentResponseJson(),
          );
        };
      final cubit = _cubitWith(api);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: PaymentCheckoutPage(order: _order()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _tapPay(tester);
      await tester.pumpAndSettle();

      expect(find.text('Payment Detail'), findsOneWidget);
      expect(api.postPaths, hasLength(1));
    });
  });
}

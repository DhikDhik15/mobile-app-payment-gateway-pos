import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';

/// A fake [PaymentRepository] for testing the cubit.
class _FakePaymentRepository implements PaymentRepository {
  PaymentResult<Payment>? createResult;
  PaymentResult<Payment>? getResult;
  PaymentResult<List<Payment>>? listResult;
  PaymentResult<Payment>? simulateSuccessResult;
  PaymentResult<Payment>? simulateFailResult;
  PaymentResult<Payment>? orderPaymentResult;
  String? lastOrderId;
  String? lastOrderPaymentMethod;
  String? lastOrderIdempotencyKey;
  int orderPaymentCalls = 0;

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async {
    return createResult ?? PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async {
    return getResult ?? PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async {
    return listResult ?? PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async {
    return simulateSuccessResult ?? PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async {
    return simulateFailResult ?? PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    orderPaymentCalls++;
    lastOrderId = orderId;
    lastOrderPaymentMethod = paymentMethod;
    lastOrderIdempotencyKey = idempotencyKey;
    return orderPaymentResult ?? PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async {
    return PaymentError(const ServerFailure());
  }
}

Payment _payment() => Payment(
      transactionId: 'tx-001',
      merchantOrderId: 'ORDER-001',
      amount: 150000,
      currency: 'IDR',
      paymentMethod: 'QRIS',
      status: PaymentStatus.created,
      createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
      updatedAt: DateTime.parse('2026-01-01T10:00:00Z'),
    );

PaymentCubit _cubit(_FakePaymentRepository repo) => PaymentCubit(
      listPayments: ListPaymentsUseCase(repo),
      getPayment: GetPaymentUseCase(repo),
      createPayment: CreatePaymentUseCase(repo),
      simulateSuccess: SimulatePaymentSuccessUseCase(repo),
      simulateFail: SimulatePaymentFailUseCase(repo),
    );

void main() {
  group('PaymentCubit', () {
    test('starts in PaymentInitial', () {
      final cubit = _cubit(_FakePaymentRepository());
      expect(cubit.state, isA<PaymentInitial>());
    });

    group('loadPayments', () {
      test('emits PaymentLoading then PaymentListLoaded on success', () async {
        final repo = _FakePaymentRepository()..listResult = PaymentSuccess([_payment()]);
        final cubit = _cubit(repo);
        final states = <PaymentState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.loadPayments();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<PaymentListLoaded>());
        final loaded = cubit.state as PaymentListLoaded;
        expect(loaded.payments.length, 1);
        expect(loaded.payments.first.merchantOrderId, 'ORDER-001');
        expect(states.any((s) => s is PaymentLoading), isTrue);
        await sub.cancel();
      });

      test('emits PaymentLoading then PaymentFailure on error', () async {
        final repo = _FakePaymentRepository()..listResult = PaymentError(const ConnectionFailure());
        final cubit = _cubit(repo);
        final states = <PaymentState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.loadPayments();
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<PaymentFailure>());
        final failure = cubit.state as PaymentFailure;
        expect(failure.message, 'Could not reach the server');
        expect(states.any((s) => s is PaymentLoading), isTrue);
        await sub.cancel();
      });
    });

    group('loadPayment', () {
      test('emits PaymentLoading then PaymentDetailLoaded on success', () async {
        final repo = _FakePaymentRepository()..getResult = PaymentSuccess(_payment());
        final cubit = _cubit(repo);

        await cubit.loadPayment('tx-001');

        expect(cubit.state, isA<PaymentDetailLoaded>());
        final loaded = cubit.state as PaymentDetailLoaded;
        expect(loaded.payment.transactionId, 'tx-001');
      });

      test('emits PaymentFailure on error', () async {
        final repo = _FakePaymentRepository()..getResult = PaymentError(const ApiFailure(404, 'Transaction not found'));
        final cubit = _cubit(repo);

        await cubit.loadPayment('nonexistent');

        expect(cubit.state, isA<PaymentFailure>());
        final failure = cubit.state as PaymentFailure;
        expect(failure.message, 'Transaction not found');
      });
    });

    group('createPayment', () {
      test('emits PaymentCreating then PaymentCreated on success', () async {
        final repo = _FakePaymentRepository()..createResult = PaymentSuccess(_payment());
        final cubit = _cubit(repo);
        final states = <PaymentState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.createPayment(
          const CreatePaymentParams(
            merchantOrderId: 'ORDER-001',
            amount: 150000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key-001',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<PaymentCreated>());
        final created = cubit.state as PaymentCreated;
        expect(created.payment.merchantOrderId, 'ORDER-001');
        expect(states.any((s) => s is PaymentCreating), isTrue);
        await sub.cancel();
      });

      test('emits PaymentCreating then PaymentFailure on error', () async {
        final repo = _FakePaymentRepository()..createResult = PaymentError(const ApiFailure(409, 'DUPLICATE_ORDER'));
        final cubit = _cubit(repo);
        final states = <PaymentState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.createPayment(
          const CreatePaymentParams(
            merchantOrderId: 'ORDER-001',
            amount: 150000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key-001',
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<PaymentFailure>());
        final failure = cubit.state as PaymentFailure;
        expect(failure.message, 'DUPLICATE_ORDER');
        expect(states.any((s) => s is PaymentCreating), isTrue);
        await sub.cancel();
      });
    });
    group('createOrderPayment', () {
      test('emits PaymentCreating then PaymentCreated on success', () async {
        final repo = _FakePaymentRepository()
          ..orderPaymentResult = PaymentSuccess(_payment());
        final cubit = _cubit(repo);
        final states = <PaymentState>[];
        final sub = cubit.stream.listen(states.add);

        await cubit.createOrderPayment(
          orderId: 'order-123',
          paymentMethod: 'QRIS',
          idempotencyKey: 'order:order-123:qris:v1',
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state, isA<PaymentCreated>());
        expect(repo.orderPaymentCalls, 1);
        expect(repo.lastOrderId, 'order-123');
        expect(repo.lastOrderPaymentMethod, 'QRIS');
        expect(repo.lastOrderIdempotencyKey, 'order:order-123:qris:v1');
        expect(states.any((s) => s is PaymentCreating), isTrue);
        await sub.cancel();
      });

      test('emits PaymentCreating then PaymentFailure on error', () async {
        final repo = _FakePaymentRepository()
          ..orderPaymentResult = PaymentError(
            const ApiFailure(409, 'Order already has an active payment'),
          );
        final cubit = _cubit(repo);

        await cubit.createOrderPayment(
          orderId: 'order-123',
          paymentMethod: 'QRIS',
          idempotencyKey: 'order:order-123:qris:v1',
        );

        expect(cubit.state, isA<PaymentFailure>());
        final failure = cubit.state as PaymentFailure;
        expect(failure.message, 'Order already has an active payment');
      });

      test('forwards a stable idempotency key unchanged', () async {
        final repo = _FakePaymentRepository()
          ..orderPaymentResult = PaymentSuccess(_payment());
        final cubit = _cubit(repo);

        await cubit.createOrderPayment(
          orderId: 'order-123',
          paymentMethod: 'QRIS',
          idempotencyKey: 'order:order-123:qris:v1',
        );
        await cubit.createOrderPayment(
          orderId: 'order-123',
          paymentMethod: 'QRIS',
          idempotencyKey: 'order:order-123:qris:v1',
        );

        expect(repo.orderPaymentCalls, 2);
        expect(repo.lastOrderIdempotencyKey, 'order:order-123:qris:v1');
      });
    });
  });
}

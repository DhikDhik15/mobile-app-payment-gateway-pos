import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_order_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';


/// A fake [PaymentRepository] for testing use cases.
class _FakePaymentRepository implements PaymentRepository {
  PaymentResult<Payment>? createResult;
  PaymentResult<Payment>? getResult;
  PaymentResult<List<Payment>>? listResult;
  PaymentResult<Payment>? simulateSuccessResult;
  PaymentResult<Payment>? simulateFailResult;
  PaymentResult<Payment>? orderPaymentResult;
  PaymentResult<List<Payment>>? orderPaymentsResult;
  String? lastOrderPaymentsId;

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async {
    return createResult!;
  }

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async {
    return getResult!;
  }

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async {
    return listResult!;
  }

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async {
    return simulateSuccessResult!;
  }

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async {
    return simulateFailResult!;
  }

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    return orderPaymentResult!;
  }

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async {
    lastOrderPaymentsId = orderId;
    return orderPaymentsResult!;
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

void main() {
  group('CreatePaymentUseCase', () {
    test('delegates to repository and returns result', () async {
      final repo = _FakePaymentRepository()..createResult = PaymentSuccess(_payment());
      final useCase = CreatePaymentUseCase(repo);

      final result = await useCase(
        const CreatePaymentParams(
          merchantOrderId: 'ORDER-001',
          amount: 150000,
          currency: 'IDR',
          paymentMethod: 'QRIS',
          idempotencyKey: 'key-001',
        ),
      );

      expect(result, isA<PaymentSuccess<Payment>>());
      expect((result as PaymentSuccess<Payment>).value.merchantOrderId, 'ORDER-001');
    });

    test('propagates error from repository', () async {
      final repo = _FakePaymentRepository()..createResult = PaymentError(const ServerFailure());
      final useCase = CreatePaymentUseCase(repo);

      final result = await useCase(
        const CreatePaymentParams(
          merchantOrderId: 'ORDER-001',
          amount: 150000,
          currency: 'IDR',
          paymentMethod: 'QRIS',
          idempotencyKey: 'key-001',
        ),
      );

      expect(result, isA<PaymentError<Payment>>());
    });
  });

  group('GetPaymentUseCase', () {
    test('delegates to repository and returns result', () async {
      final repo = _FakePaymentRepository()..getResult = PaymentSuccess(_payment());
      final useCase = GetPaymentUseCase(repo);

      final result = await useCase(
        const GetPaymentParams(paymentId: 'tx-001'),
      );

      expect(result, isA<PaymentSuccess<Payment>>());
      expect((result as PaymentSuccess<Payment>).value.transactionId, 'tx-001');
    });
  });

  group('ListPaymentsUseCase', () {
    test('delegates to repository and returns result', () async {
      final repo = _FakePaymentRepository()..listResult = PaymentSuccess([_payment()]);
      final useCase = ListPaymentsUseCase(repo);

      final result = await useCase(const NoParams());

      expect(result, isA<PaymentSuccess<List<Payment>>>());
      expect((result as PaymentSuccess<List<Payment>>).value.length, 1);
    });
  });

  group('ListOrderPaymentsUseCase', () {
    test('delegates scoped history to the repository', () async {
      final repo = _FakePaymentRepository()
        ..orderPaymentsResult = PaymentSuccess([_payment()]);
      final useCase = ListOrderPaymentsUseCase(repo);

      final result = await useCase(
        const ListOrderPaymentsParams(orderId: 'order-123'),
      );

      expect(result, isA<PaymentSuccess<List<Payment>>>());
      expect(repo.lastOrderPaymentsId, 'order-123');
      expect((result as PaymentSuccess<List<Payment>>).value.length, 1);
    });
  });
}

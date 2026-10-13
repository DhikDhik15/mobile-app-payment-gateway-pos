import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:payment_simulator/features/payments/data/models/payment_model.dart';
import 'package:payment_simulator/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';

/// A fake [PaymentRemoteDataSource] for testing the repository.
class _FakePaymentRemoteDataSource extends PaymentRemoteDataSource {
  PaymentModel? createResult;
  PaymentModel? getResult;
  List<PaymentModel>? listResult;
  PaymentModel? simulateSuccessResult;
  PaymentModel? simulateFailResult;
  PaymentModel? orderPaymentResult;
  List<PaymentModel>? orderPaymentsResult;
  AppException? createError;
  AppException? getError;
  AppException? listError;
  AppException? simulateSuccessError;
  AppException? simulateFailError;
  AppException? orderPaymentError;
  AppException? orderPaymentsError;
  Map<String, String>? lastOrderPaymentCall;
  String? lastOrderPaymentsCall;

  @override
  Future<PaymentModel> createPayment({
    required String merchantOrderId,
    required int amount,
    required String currency,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    if (createError != null) throw createError!;
    return createResult!;
  }

  @override
  Future<PaymentModel> getPayment(String paymentId) async {
    if (getError != null) throw getError!;
    return getResult!;
  }

  @override
  Future<List<PaymentModel>> listPayments() async {
    if (listError != null) throw listError!;
    return listResult!;
  }

  @override
  Future<PaymentModel> simulateSuccess(String paymentId) async {
    if (simulateSuccessError != null) throw simulateSuccessError!;
    return simulateSuccessResult!;
  }

  @override
  Future<PaymentModel> simulateFail(String paymentId) async {
    if (simulateFailError != null) throw simulateFailError!;
    return simulateFailResult!;
  }

  @override
  Future<PaymentModel> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    lastOrderPaymentCall = {
      'orderId': orderId,
      'paymentMethod': paymentMethod,
      'idempotencyKey': idempotencyKey,
    };
    if (orderPaymentError != null) throw orderPaymentError!;
    return orderPaymentResult!;
  }

  @override
  Future<List<PaymentModel>> listOrderPayments(String orderId) async {
    lastOrderPaymentsCall = orderId;
    if (orderPaymentsError != null) throw orderPaymentsError!;
    return orderPaymentsResult!;
  }
}

PaymentModel _paymentModel() => PaymentModel(
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
  group('PaymentRepositoryImpl', () {
    late _FakePaymentRemoteDataSource fakeRemote;
    late PaymentRepositoryImpl repository;

    setUp(() {
      fakeRemote = _FakePaymentRemoteDataSource();
      repository = PaymentRepositoryImpl(fakeRemote);
    });

    group('createPayment', () {
      test('returns PaymentSuccess on successful creation', () async {
        fakeRemote.createResult = _paymentModel();

        final result = await repository.createPayment(
          const CreatePaymentParams(
            merchantOrderId: 'ORDER-001',
            amount: 150000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key-001',
          ),
        );

        expect(result, isA<PaymentSuccess<Payment>>());
        final success = result as PaymentSuccess<Payment>;
        expect(success.value.merchantOrderId, 'ORDER-001');
      });

      test('returns PaymentError on ApiException', () async {
        fakeRemote.createError = const ApiException(409, 'DUPLICATE_ORDER');

        final result = await repository.createPayment(
          const CreatePaymentParams(
            merchantOrderId: 'ORDER-001',
            amount: 150000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key-001',
          ),
        );

        expect(result, isA<PaymentError<Payment>>());
        final error = result as PaymentError<Payment>;
        expect(error.failure, isA<ApiFailure>());
        expect((error.failure as ApiFailure).statusCode, 409);
      });

      test('maps ConnectionNetworkException to ConnectionFailure', () async {
        fakeRemote.createError = const ConnectionNetworkException();

        final result = await repository.createPayment(
          const CreatePaymentParams(
            merchantOrderId: 'ORDER-001',
            amount: 150000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key-001',
          ),
        );

        final error = result as PaymentError<Payment>;
        expect(error.failure, isA<ConnectionFailure>());
      });

      test('maps NetworkTimeoutException to TimeoutFailure', () async {
        fakeRemote.createError = const NetworkTimeoutException();

        final result = await repository.createPayment(
          const CreatePaymentParams(
            merchantOrderId: 'ORDER-001',
            amount: 150000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key-001',
          ),
        );

        final error = result as PaymentError<Payment>;
        expect(error.failure, isA<TimeoutFailure>());
      });

      test('maps InvalidResponseException to InvalidResponseFailure', () async {
        fakeRemote.createError = const InvalidResponseException();

        final result = await repository.createPayment(
          const CreatePaymentParams(
            merchantOrderId: 'ORDER-001',
            amount: 150000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key-001',
          ),
        );

        final error = result as PaymentError<Payment>;
        expect(error.failure, isA<InvalidResponseFailure>());
      });
    });

    group('getPayment', () {
      test('returns PaymentSuccess on successful retrieval', () async {
        fakeRemote.getResult = _paymentModel();

        final result = await repository.getPayment('tx-001');

        expect(result, isA<PaymentSuccess<Payment>>());
        final success = result as PaymentSuccess<Payment>;
        expect(success.value.transactionId, 'tx-001');
      });

      test('returns PaymentError on failure', () async {
        fakeRemote.getError = const ApiException(404, 'TRANSACTION_NOT_FOUND');

        final result = await repository.getPayment('nonexistent');

        expect(result, isA<PaymentError<Payment>>());
        final error = result as PaymentError<Payment>;
        expect((error.failure as ApiFailure).statusCode, 404);
      });
    });

    group('listPayments', () {
      test('returns PaymentSuccess with list on success', () async {
        fakeRemote.listResult = [_paymentModel(), _paymentModel()];

        final result = await repository.listPayments();

        expect(result, isA<PaymentSuccess<List<Payment>>>());
        final success = result as PaymentSuccess<List<Payment>>;
        expect(success.value.length, 2);
      });

      test('returns empty list when no payments exist', () async {
        fakeRemote.listResult = [];

        final result = await repository.listPayments();

        final success = result as PaymentSuccess<List<Payment>>;
        expect(success.value, isEmpty);
      });

      test('returns PaymentError on failure', () async {
        fakeRemote.listError = const ApiException(500, 'INTERNAL_ERROR');

        final result = await repository.listPayments();

        expect(result, isA<PaymentError<List<Payment>>>());
        final error = result as PaymentError<List<Payment>>;
        expect((error.failure as ApiFailure).statusCode, 500);
      });
    });

    group('listOrderPayments', () {
      test('returns history scoped to the order', () async {
        fakeRemote.orderPaymentsResult = [_paymentModel(), _paymentModel()];

        final result = await repository.listOrderPayments('order-123');

        expect(result, isA<PaymentSuccess<List<Payment>>>());
        expect(fakeRemote.lastOrderPaymentsCall, 'order-123');
        final success = result as PaymentSuccess<List<Payment>>;
        expect(success.value.length, 2);
      });

      test('returns empty list when no attempt exists', () async {
        fakeRemote.orderPaymentsResult = [];

        final result = await repository.listOrderPayments('order-123');

        final success = result as PaymentSuccess<List<Payment>>;
        expect(success.value, isEmpty);
      });

      test('maps the backend error code through', () async {
        fakeRemote.orderPaymentsError = const ApiException(
          404,
          'Order not found',
          'RESOURCE_NOT_FOUND',
        );

        final result = await repository.listOrderPayments('order-123');

        expect(result, isA<PaymentError<List<Payment>>>());
        final failure =
            (result as PaymentError<List<Payment>>).failure as ApiFailure;
        expect(failure.statusCode, 404);
        expect(failure.code, 'RESOURCE_NOT_FOUND');
      });
    });
  });
}

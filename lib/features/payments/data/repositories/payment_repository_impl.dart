import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';

/// Data-layer implementation of [PaymentRepository].
///
/// Delegates HTTP access to [PaymentRemoteDataSource] (which uses the shared
/// core `ApiClient`) and translates any [AppException] into a domain
/// [Failure] — raw exceptions never escape this boundary.
class PaymentRepositoryImpl implements PaymentRepository {
  const PaymentRepositoryImpl(this._remote);

  final PaymentRemoteDataSource _remote;

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async {
    try {
      final payment = await _remote.createPayment(
        merchantOrderId: params.merchantOrderId,
        amount: params.amount,
        currency: params.currency,
        paymentMethod: params.paymentMethod,
        idempotencyKey: params.idempotencyKey,
      );
      return PaymentSuccess(payment);
    } on AppException catch (error) {
      return PaymentError(_mapError(error));
    }
  }

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async {
    try {
      final payment = await _remote.getPayment(paymentId);
      return PaymentSuccess(payment);
    } on AppException catch (error) {
      return PaymentError(_mapError(error));
    }
  }

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async {
    try {
      final payments = await _remote.listPayments();
      return PaymentSuccess(payments);
    } on AppException catch (error) {
      return PaymentError(_mapError(error));
    }
  }

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async {
    try {
      final payment = await _remote.simulateSuccess(paymentId);
      return PaymentSuccess(payment);
    } on AppException catch (error) {
      return PaymentError(_mapError(error));
    }
  }

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async {
    try {
      final payment = await _remote.simulateFail(paymentId);
      return PaymentSuccess(payment);
    } on AppException catch (error) {
      return PaymentError(_mapError(error));
    }
  }

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    try {
      final payment = await _remote.createOrderPayment(
        orderId: orderId,
        paymentMethod: paymentMethod,
        idempotencyKey: idempotencyKey,
      );
      return PaymentSuccess(payment);
    } on AppException catch (error) {
      return PaymentError(_mapError(error));
    }
  }

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async {
    try {
      final payments = await _remote.listOrderPayments(orderId);
      return PaymentSuccess(payments);
    } on AppException catch (error) {
      return PaymentError(_mapError(error));
    }
  }

  /// Maps a network-layer [AppException] to a domain [Failure] with a
  /// user-safe message.
  Failure _mapError(AppException error) {
    return switch (error) {
      NetworkTimeoutException() => const TimeoutFailure(),
      ConnectionNetworkException() => const ConnectionFailure(),
      ApiException() => ApiFailure(error.statusCode, error.message, error.code),
      InvalidResponseException() => const InvalidResponseFailure(),
      _ => const ServerFailure(),
    };
  }
}

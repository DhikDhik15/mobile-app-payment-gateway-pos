import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';

/// Use case that retrieves a single payment by its transaction UUID.
class GetPaymentUseCase implements UseCase<PaymentResult<Payment>, GetPaymentParams> {
  const GetPaymentUseCase(this._repository);

  final PaymentRepository _repository;

  @override
  Future<PaymentResult<Payment>> call(GetPaymentParams params) =>
      _repository.getPayment(params.paymentId);
}

/// Parameters for [GetPaymentUseCase].
class GetPaymentParams {
  const GetPaymentParams({required this.paymentId});

  /// Transaction UUID of the payment to retrieve.
  final String paymentId;
}

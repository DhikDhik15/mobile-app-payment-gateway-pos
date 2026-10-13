import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';

/// Use case that simulates a failed payment outcome.
class SimulatePaymentFailUseCase
    implements UseCase<PaymentResult<Payment>, SimulatePaymentParams> {
  const SimulatePaymentFailUseCase(this._repository);

  final PaymentRepository _repository;

  @override
  Future<PaymentResult<Payment>> call(SimulatePaymentParams params) =>
      _repository.simulateFail(params.paymentId);
}

/// Parameters for simulation use cases.
class SimulatePaymentParams {
  const SimulatePaymentParams({required this.paymentId});

  /// Transaction UUID of the payment to simulate.
  final String paymentId;
}

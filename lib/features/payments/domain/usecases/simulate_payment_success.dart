import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';

/// Use case that simulates a successful payment outcome.
class SimulatePaymentSuccessUseCase
    implements UseCase<PaymentResult<Payment>, SimulatePaymentParams> {
  const SimulatePaymentSuccessUseCase(this._repository);

  final PaymentRepository _repository;

  @override
  Future<PaymentResult<Payment>> call(SimulatePaymentParams params) =>
      _repository.simulateSuccess(params.paymentId);
}

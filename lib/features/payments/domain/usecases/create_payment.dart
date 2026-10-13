import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';

/// Use case that initiates a new payment via the GO-SAAS backend.
class CreatePaymentUseCase
    implements UseCase<PaymentResult<Payment>, CreatePaymentParams> {
  const CreatePaymentUseCase(this._repository);

  final PaymentRepository _repository;

  @override
  Future<PaymentResult<Payment>> call(CreatePaymentParams params) =>
      _repository.createPayment(params);

  PaymentRepository get repository => _repository;
}

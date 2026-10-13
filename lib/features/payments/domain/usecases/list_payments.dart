import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';

/// Use case that retrieves the paginated payment list for the
/// authenticated merchant.
class ListPaymentsUseCase
    implements UseCase<PaymentResult<List<Payment>>, NoParams> {
  const ListPaymentsUseCase(this._repository);

  final PaymentRepository _repository;

  @override
  Future<PaymentResult<List<Payment>>> call(NoParams params) =>
      _repository.listPayments();
}

import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';

/// Parameters for listing an order's recorded payment attempts.
class ListOrderPaymentsParams {
  const ListOrderPaymentsParams({required this.orderId});

  /// Order UUID; scoped server-side to the authenticated merchant.
  final String orderId;
}

/// Use case that retrieves the recorded payment attempts for an order,
/// newest first, via the read-only order-payments endpoint.
class ListOrderPaymentsUseCase
    implements UseCase<PaymentResult<List<Payment>>, ListOrderPaymentsParams> {
  const ListOrderPaymentsUseCase(this._repository);

  final PaymentRepository _repository;

  @override
  Future<PaymentResult<List<Payment>>> call(
    ListOrderPaymentsParams params,
  ) =>
      _repository.listOrderPayments(params.orderId);

  PaymentRepository get repository => _repository;
}

import '../entities/order.dart';
import '../entities/order_result.dart';
import '../repositories/order_repository.dart';

class GetOrderByIdParams {
  const GetOrderByIdParams({required this.orderId});

  final String orderId;
}

class GetOrderByIdUseCase {
  const GetOrderByIdUseCase(this._repository);

  final OrderRepository _repository;

  Future<OrderResult<Order>> call(GetOrderByIdParams params) =>
      _repository.getOrderById(params.orderId);
}

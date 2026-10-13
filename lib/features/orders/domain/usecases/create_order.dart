import '../entities/order.dart';
import '../entities/order_result.dart';
import '../repositories/order_repository.dart';

class CreateOrderParams {
  const CreateOrderParams({required this.items, required this.idempotencyKey});

  final List<OrderItemInput> items;
  final String idempotencyKey;
}

class CreateOrderUseCase {
  const CreateOrderUseCase(this._repository);

  final OrderRepository _repository;

  Future<OrderResult<Order>> call(CreateOrderParams params) => _repository
      .createOrder(items: params.items, idempotencyKey: params.idempotencyKey);
}

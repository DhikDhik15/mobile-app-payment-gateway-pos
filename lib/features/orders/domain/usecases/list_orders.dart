import '../entities/order_page.dart';
import '../entities/order_result.dart';
import '../repositories/order_repository.dart';

class ListOrdersParams {
  const ListOrdersParams({required this.page, required this.limit});

  final int page;
  final int limit;
}

class ListOrdersUseCase {
  const ListOrdersUseCase(this._repository);

  final OrderRepository _repository;

  Future<OrderResult<OrderPage>> call(ListOrdersParams params) =>
      _repository.listOrders(page: params.page, limit: params.limit);
}

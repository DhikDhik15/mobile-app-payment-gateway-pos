import '../../domain/repositories/order_repository.dart';

class CreateOrderRequestModel {
  const CreateOrderRequestModel(this.items);

  final List<OrderItemInput> items;

  Map<String, dynamic> toJson() => {
    'items': [
      for (final item in items)
        {'product_id': item.productId, 'quantity': item.quantity},
    ],
  };
}

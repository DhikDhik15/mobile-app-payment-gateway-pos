import '../entities/order.dart';
import '../entities/order_page.dart';
import '../entities/order_result.dart';

class OrderItemInput {
  const OrderItemInput({required this.productId, required this.quantity});

  final String productId;
  final int quantity;
}

abstract class OrderRepository {
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  });

  /// Returns one page of the authenticated merchant's orders, newest first.
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  });

  /// Returns a single order with its item snapshots. A missing or foreign
  /// order surfaces as a failure (HTTP 404, indistinguishable by design).
  Future<OrderResult<Order>> getOrderById(String orderId);
}

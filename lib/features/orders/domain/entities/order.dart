import 'order_item.dart';

class Order {
  const Order({
    required this.id,
    required this.status,
    required this.currency,
    required this.subtotal,
    required this.totalAmount,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  final String id;
  final String status;
  final String currency;
  final int subtotal;
  final int totalAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<OrderItem> items;
}

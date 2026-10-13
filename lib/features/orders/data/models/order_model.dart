import '../../domain/entities/order.dart';
import '../../domain/entities/order_item.dart';

class OrderModel extends Order {
  const OrderModel({
    required super.id,
    required super.status,
    required super.currency,
    required super.subtotal,
    required super.totalAmount,
    required super.createdAt,
    required super.updatedAt,
    required super.items,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    if (items is! List) {
      throw const FormatException('Order items must be a list');
    }
    return OrderModel(
      id: json['id'] as String,
      status: json['status'] as String,
      currency: json['currency'] as String,
      subtotal: (json['subtotal'] as num).toInt(),
      totalAmount: (json['total_amount'] as num).toInt(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      items: [
        for (final item in items)
          OrderItemModel.fromJson(item as Map<String, dynamic>),
      ],
    );
  }
}

class OrderItemModel extends OrderItem {
  const OrderItemModel({
    required super.id,
    required super.productId,
    required super.productName,
    required super.quantity,
    required super.unitPrice,
    required super.subtotal,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String,
      productId: json['product_id'] as String?,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toInt(),
      unitPrice: (json['unit_price'] as num).toInt(),
      subtotal: (json['subtotal'] as num).toInt(),
    );
  }
}

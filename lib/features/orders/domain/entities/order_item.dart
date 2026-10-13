class OrderItem {
  const OrderItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  final String id;
  final String? productId;
  final String productName;
  final int quantity;
  final int unitPrice;
  final int subtotal;
}

/// A single line in a POS cart.
///
/// Pure client-side domain object. Product metadata is captured locally at
/// sale time — no backend Product API exists yet.
class CartItem {
  const CartItem({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    this.active = true,
  }) : assert(quantity > 0, 'quantity must be positive'),
       assert(unitPrice >= 0, 'unitPrice cannot be negative');

  /// Identifier of the product as known on this device.
  final String productId;

  /// Display name captured when the item was added.
  final String name;

  /// Number of units.
  final int quantity;

  /// Unit price in the smallest currency unit (IDR: rupiah).
  final int unitPrice;

  /// Whether this snapshot is currently available for local POS sale.
  final bool active;

  /// Line total (`unitPrice * quantity`).
  int get subtotal => unitPrice * quantity;

  CartItem copyWith({int? quantity, bool? active}) {
    return CartItem(
      productId: productId,
      name: name,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      active: active ?? this.active,
    );
  }
}

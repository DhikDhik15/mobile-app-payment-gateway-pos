import 'cart_item.dart';

/// A client-side POS cart.
///
/// Pure domain model — no server-side cart exists in the backend contract,
/// so this lives entirely on the device.
class Cart {
  const Cart({this.items = const []});

  final List<CartItem> items;

  int get subtotal => items.fold(0, (sum, item) => sum + item.subtotal);

  int get total => subtotal;

  bool get isEmpty => items.isEmpty;

  Cart copyWith({List<CartItem>? items}) {
    return Cart(items: items ?? this.items);
  }
}

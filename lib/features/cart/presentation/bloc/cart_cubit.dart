import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/cart.dart';
import '../../domain/entities/cart_item.dart';

/// Cubit managing the client-side POS cart.
///
/// Adds, removes, and adjusts line items locally. Order creation is handled
/// separately by the orders feature.
class CartCubit extends Cubit<Cart> {
  CartCubit() : super(const Cart());

  /// Adds [item] or increments its quantity when the product is already in
  /// the cart.
  void add(CartItem item) {
    if (!item.active || item.quantity <= 0) {
      return;
    }

    final index = state.items.indexWhere((i) => i.productId == item.productId);
    final items = List<CartItem>.of(state.items);
    if (index >= 0) {
      final existing = items[index];
      items[index] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
      );
    } else {
      items.add(item);
    }
    emit(state.copyWith(items: items));
  }

  /// Removes the line for [productId].
  void remove(String productId) {
    emit(
      state.copyWith(
        items: state.items.where((i) => i.productId != productId).toList(),
      ),
    );
  }

  /// Sets the quantity for [productId]; removes the line when [quantity]
  /// drops to zero or below.
  void setQuantity(String productId, int quantity) {
    if (quantity <= 0) {
      remove(productId);
      return;
    }
    emit(
      state.copyWith(
        items: state.items
            .map(
              (i) =>
                  i.productId == productId ? i.copyWith(quantity: quantity) : i,
            )
            .toList(),
      ),
    );
  }

  /// Clears the cart.
  void clear() => emit(const Cart());
}

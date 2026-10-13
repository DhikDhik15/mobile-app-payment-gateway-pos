import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart_item.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';

void main() {
  group('Cart', () {
    test('subtotal and total use only line subtotals', () {
      const cart = Cart(
        items: [
          CartItem(
            productId: 'p1',
            name: 'Coffee',
            quantity: 2,
            unitPrice: 10000,
          ),
          CartItem(
            productId: 'p2',
            name: 'Cake',
            quantity: 1,
            unitPrice: 15000,
          ),
        ],
      );
      expect(cart.subtotal, 35000);
      expect(cart.total, 35000);
    });
  });

  group('CartCubit', () {
    late CartCubit cubit;

    setUp(() => cubit = CartCubit());
    tearDown(() => cubit.close());

    const item = CartItem(
      productId: 'p1',
      name: 'Coffee',
      quantity: 1,
      unitPrice: 15000,
      active: true,
    );

    test('active product can be added', () {
      cubit.add(item);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.total, 15000);
    });

    test('inactive product cannot be added', () {
      cubit.add(
        const CartItem(
          productId: 'p2',
          name: 'Unavailable item',
          quantity: 1,
          unitPrice: 5000,
          active: false,
        ),
      );

      expect(cubit.state.items, isEmpty);
      expect(cubit.state.total, 0);
    });

    test('add of the same product increments quantity', () {
      cubit.add(item);
      cubit.add(item);
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.items.first.quantity, 2);
    });

    test('setQuantity updates total and zero removes', () {
      cubit.add(item);
      cubit.setQuantity('p1', 3);
      expect(cubit.state.items.first.quantity, 3);
      expect(cubit.state.total, 45000);
      cubit.setQuantity('p1', 0);
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.total, 0);
    });

    test('remove deletes the line', () {
      cubit.add(item);
      cubit.remove('p1');
      expect(cubit.state.items, isEmpty);
      expect(cubit.state.total, 0);
    });

    test('clear empties the cart and resets total to zero', () {
      cubit.add(item);
      cubit.clear();
      expect(cubit.state, const Cart());
      expect(cubit.state.total, 0);
    });

    test('multiple line items accumulate total without adjustments', () {
      cubit.add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 2,
          unitPrice: 10000,
        ),
      );
      cubit.add(
        const CartItem(
          productId: 'p2',
          name: 'Cake',
          quantity: 1,
          unitPrice: 15000,
        ),
      );

      expect(cubit.state.total, 35000);
    });

    test('removing an item changes total correctly', () {
      cubit.add(
        const CartItem(
          productId: 'p1',
          name: 'Coffee',
          quantity: 2,
          unitPrice: 10000,
        ),
      );
      cubit.add(
        const CartItem(
          productId: 'p2',
          name: 'Cake',
          quantity: 1,
          unitPrice: 15000,
        ),
      );

      cubit.remove('p1');

      expect(cubit.state.total, 15000);
    });
  });
}

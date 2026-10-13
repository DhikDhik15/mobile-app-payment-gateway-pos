import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_result.dart';
import '../../domain/repositories/order_repository.dart';
import '../../domain/usecases/create_order.dart';

class OrderCubit extends Cubit<OrderState> {
  OrderCubit({required this.createOrderUseCase, required this.cartCubit})
    : super(const OrderInitial()) {
    _cartSubscription = cartCubit.stream.listen(_onCartChanged);
  }

  final CreateOrderUseCase createOrderUseCase;
  final CartCubit cartCubit;
  late final StreamSubscription<Cart> _cartSubscription;
  List<OrderItemInput>? _keyItems;
  String? _idempotencyKey;
  int _generation = 0;

  Future<void> createOrder() async {
    if (state is OrderLoading || cartCubit.state.isEmpty) return;

    final items = [
      for (final item in cartCubit.state.items)
        OrderItemInput(productId: item.productId, quantity: item.quantity),
    ];
    if (!_sameItems(_keyItems, items)) {
      _keyItems = items;
      _idempotencyKey = _newIdempotencyKey();
    }

    emit(const OrderLoading());
    final generation = _generation;
    final result = await createOrderUseCase(
      CreateOrderParams(items: items, idempotencyKey: _idempotencyKey!),
    );
    if (generation != _generation) return;
    switch (result) {
      case OrderSuccess(value: final order):
        emit(OrderCreated(order));
        cartCubit.clear();
      case OrderError(failure: final failure):
        emit(OrderFailure(failure.message));
    }
  }

  void reset() {
    _generation++;
    _keyItems = null;
    _idempotencyKey = null;
    if (state is! OrderInitial) emit(const OrderInitial());
  }

  void _onCartChanged(Cart cart) {
    final currentItems = [
      for (final item in cart.items)
        OrderItemInput(productId: item.productId, quantity: item.quantity),
    ];
    if (!_sameItems(_keyItems, currentItems)) {
      _keyItems = null;
      _idempotencyKey = null;
    }
  }

  bool _sameItems(List<OrderItemInput>? left, List<OrderItemInput> right) {
    if (left == null || left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index].productId != right[index].productId ||
          left[index].quantity != right[index].quantity) {
        return false;
      }
    }
    return true;
  }

  String _newIdempotencyKey() {
    // Backend order keys are durable, so retries of the same cart snapshot
    // reuse this key; cart changes invalidate it.
    final random = Random.secure().nextInt(1 << 32);
    return 'order-${DateTime.now().microsecondsSinceEpoch}-$random';
  }

  @override
  Future<void> close() async {
    await _cartSubscription.cancel();
    await super.close();
  }
}

sealed class OrderState {
  const OrderState();
}

final class OrderInitial extends OrderState {
  const OrderInitial();
}

final class OrderLoading extends OrderState {
  const OrderLoading();
}

final class OrderCreated extends OrderState {
  const OrderCreated(this.order);

  final Order order;
}

final class OrderFailure extends OrderState {
  const OrderFailure(this.message);

  final String message;
}

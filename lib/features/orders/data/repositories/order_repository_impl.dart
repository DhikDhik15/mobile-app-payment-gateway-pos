import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_page.dart';
import '../../domain/entities/order_result.dart';
import '../../domain/repositories/order_repository.dart';
import '../datasources/order_remote_data_source.dart';

class OrderRepositoryImpl implements OrderRepository {
  const OrderRepositoryImpl(this._remote);

  final OrderRemoteDataSource _remote;

  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async {
    try {
      final order = await _remote.createOrder(
        items: items,
        idempotencyKey: idempotencyKey,
      );
      return OrderSuccess(order);
    } on NetworkTimeoutException {
      return const OrderError(TimeoutFailure());
    } on ConnectionNetworkException {
      return const OrderError(ConnectionFailure());
    } on ApiException catch (error) {
      return OrderError(_mapApiFailure(error, 'create'));
    } on InvalidResponseException {
      return const OrderError(InvalidResponseFailure());
    } on AppException {
      return const OrderError(ServerFailure());
    }
  }

  @override
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  }) async {
    try {
      final orders = await _remote.listOrders(page: page, limit: limit);
      return OrderSuccess(orders);
    } on NetworkTimeoutException {
      return const OrderError(TimeoutFailure());
    } on ConnectionNetworkException {
      return const OrderError(ConnectionFailure());
    } on ApiException catch (error) {
      return OrderError(_mapApiFailure(error, 'list'));
    } on InvalidResponseException {
      return const OrderError(InvalidResponseFailure());
    } on AppException {
      return const OrderError(ServerFailure());
    }
  }

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async {
    try {
      final order = await _remote.getOrderById(orderId);
      return OrderSuccess(order);
    } on NetworkTimeoutException {
      return const OrderError(TimeoutFailure());
    } on ConnectionNetworkException {
      return const OrderError(ConnectionFailure());
    } on ApiException catch (error) {
      return OrderError(_mapApiFailure(error, 'read'));
    } on InvalidResponseException {
      return const OrderError(InvalidResponseFailure());
    } on AppException {
      return const OrderError(ServerFailure());
    }
  }

  Failure _mapApiFailure(ApiException error, String operation) {
    if (operation == 'read') {
      final message = switch (error.statusCode) {
        400 => 'The order identifier is invalid.',
        401 => 'Your session has expired. Sign in again to view orders.',
        403 => 'Your account is not allowed to view orders.',
        404 => 'The order could not be found.',
        >= 500 => 'The order service is temporarily unavailable. Try again.',
        _ => 'The order could not be loaded. Try again.',
      };
      return ApiFailure(error.statusCode, message);
    }
    final message = switch (error.statusCode) {
      400 => operation == 'list'
          ? 'The order list request was invalid.'
          : 'The order could not be created. Check the selected products.',
      401 => 'Your session has expired. Sign in again.',
      403 => 'Your account is not allowed to perform this order action.',
      404 => 'An order resource could not be found.',
      409 => 'This order request conflicts with an earlier request. Retry with the current cart.',
      422 => 'The order request did not pass validation.',
      >= 500 => 'The order service is temporarily unavailable. Try again.',
      _ => 'The order request could not be completed. Try again.',
    };
    return ApiFailure(error.statusCode, message);
  }
}

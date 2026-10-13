import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/network_response.dart';

import '../../domain/entities/order.dart';
import '../../domain/entities/order_page.dart';
import '../../domain/repositories/order_repository.dart';
import '../models/create_order_request_model.dart';
import '../models/order_model.dart';

abstract class OrderRemoteDataSource {
  Future<Order> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  });

  /// `GET /api/v1/dashboard/orders?page={page}&limit={limit}`
  ///
  /// Returns one page of the authenticated merchant's orders, newest first,
  /// with pagination metadata from the response envelope.
  Future<OrderPage> listOrders({required int page, required int limit});

  /// `GET /api/v1/dashboard/orders/{order_id}`
  ///
  /// Returns the order with its immutable item snapshots. A missing or
  /// foreign order surfaces as an [ApiException] with status 404.
  Future<Order> getOrderById(String orderId);
}

class OrderRemoteDataSourceImpl implements OrderRemoteDataSource {
  const OrderRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Order> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.dashboardOrders,
      body: CreateOrderRequestModel(items).toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _parseOrder(response);
  }

  @override
  Future<OrderPage> listOrders({
    required int page,
    required int limit,
  }) async {
    final path = Uri(
      path: ApiEndpoints.dashboardOrders,
      queryParameters: {'page': '$page', 'limit': '$limit'},
    ).toString();
    final response = await _apiClient.get(path);
    final data = response.data;
    if (data is! List) {
      throw const InvalidResponseException(
        'Expected an order list but received an unexpected payload',
      );
    }
    try {
      final orders = [
        for (final item in data)
          OrderModel.fromJson(item as Map<String, dynamic>),
      ];
      return OrderPage(
        orders: orders,
        page: _metaInt(response.meta, 'page', page),
        limit: _metaInt(response.meta, 'limit', limit),
        total: _metaInt(response.meta, 'total', orders.length),
        totalPages: _metaInt(
          response.meta,
          'total_pages',
          orders.length < limit ? page : page + 1,
        ),
      );
    } on FormatException {
      throw const InvalidResponseException(
        'The server returned an invalid order response',
      );
    } on TypeError {
      throw const InvalidResponseException(
        'The server returned an invalid order response',
      );
    }
  }

  @override
  Future<Order> getOrderById(String orderId) async {
    final path = ApiEndpoints.dashboardOrderById.replaceAll(
      '{order_id}',
      orderId,
    );
    final response = await _apiClient.get(path);
    return _parseOrder(response);
  }

  int _metaInt(dynamic meta, String key, int fallback) {
    if (meta is Map<String, dynamic>) {
      final value = meta[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return fallback;
  }

  Order _parseOrder(NetworkResponse response) {    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Expected an order object but received an unexpected payload',
      );
    }
    try {
      return OrderModel.fromJson(data);
    } on FormatException {
      throw const InvalidResponseException(
        'The server returned an invalid order response',
      );
    } on TypeError {
      throw const InvalidResponseException(
        'The server returned an invalid order response',
      );
    }
  }
}

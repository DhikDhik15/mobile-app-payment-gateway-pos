import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/orders/data/datasources/order_remote_data_source.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';

class _FakeApiClient implements ApiClient {
  NetworkResponse? response;
  AppException? error;
  String? path;
  Object? body;
  Map<String, String>? headers;
  String? getPath;

  @override
  void setAuthToken(String? token) {}

  @override
  Future<NetworkResponse> get(String path, {Map<String, String>? headers}) async {
    getPath = path;
    this.headers = headers;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    this.path = path;
    this.body = body;
    this.headers = headers;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<NetworkResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => throw UnimplementedError();

  @override
  Future<NetworkResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) => throw UnimplementedError();
}

Map<String, dynamic> _orderJson() => {
  'id': 'order-1',
  'merchant_id': 'merchant-1',
  'status': 'CREATED',
  'currency': 'IDR',
  'subtotal': 35000,
  'total_amount': 35000,
  'created_at': '2026-10-07T08:00:00Z',
  'updated_at': '2026-10-07T08:00:00Z',
  'items': [
    {
      'id': 'item-1',
      'order_id': 'order-1',
      'merchant_id': 'merchant-1',
      'product_id': 'p1',
      'product_name': 'Coffee',
      'quantity': 2,
      'unit_price': 10000,
      'subtotal': 20000,
      'created_at': '2026-10-07T08:00:00Z',
    },
    {
      'id': 'item-2',
      'order_id': 'order-1',
      'merchant_id': 'merchant-1',
      'product_id': 'p2',
      'product_name': 'Cake',
      'quantity': 1,
      'unit_price': 15000,
      'subtotal': 15000,
      'created_at': '2026-10-07T08:00:00Z',
    },
  ],
};

void main() {
  group('OrderRemoteDataSourceImpl', () {
    late _FakeApiClient client;
    late OrderRemoteDataSourceImpl dataSource;

    setUp(() {
      client = _FakeApiClient();
      dataSource = OrderRemoteDataSourceImpl(client);
    });

    test(
      'sends only product IDs and quantities, then parses the order',
      () async {
        client.response = NetworkResponse(statusCode: 201, data: _orderJson());

        final order = await dataSource.createOrder(
          items: const [
            OrderItemInput(productId: 'p1', quantity: 2),
            OrderItemInput(productId: 'p2', quantity: 1),
          ],
          idempotencyKey: 'order-key-1',
        );

        expect(client.path, '/api/v1/dashboard/orders');
        expect(client.body, {
          'items': [
            {'product_id': 'p1', 'quantity': 2},
            {'product_id': 'p2', 'quantity': 1},
          ],
        });
        expect(client.headers, {'Idempotency-Key': 'order-key-1'});
        expect(order.id, 'order-1');
        expect(order.status, 'CREATED');
        expect(order.currency, 'IDR');
        expect(order.totalAmount, 35000);
        expect(order.items.first.unitPrice, 10000);
        expect(order.items.first.subtotal, 20000);

        final body = client.body as Map<String, dynamic>;
        final firstItem = (body['items'] as List).first as Map<String, dynamic>;
        expect(body.keys, {'items'});
        expect(firstItem.keys, {'product_id', 'quantity'});
        expect(body.containsKey('merchant_id'), isFalse);
        expect(firstItem.containsKey('unit_price'), isFalse);
        expect(firstItem.containsKey('subtotal'), isFalse);
        expect(firstItem.containsKey('total'), isFalse);
      },
    );

    test('rejects a malformed backend order response', () async {
      client.response = const NetworkResponse(statusCode: 201, data: []);

      expect(
        () => dataSource.createOrder(
          items: const [OrderItemInput(productId: 'p1', quantity: 1)],
          idempotencyKey: 'order-key-1',
        ),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('propagates API failures to the repository boundary', () async {
      client.error = const ApiException(409, 'conflict');

      expect(
        () => dataSource.createOrder(
          items: const [OrderItemInput(productId: 'p1', quantity: 1)],
          idempotencyKey: 'order-key-1',
        ),
        throwsA(isA<ApiException>()),
      );
    });

  group('listOrders', () {
    test('sends page/limit and parses data with meta', () async {
      client.response = NetworkResponse(
        statusCode: 200,
        data: [_orderJson()],
        meta: {
          'page': 1,
          'limit': 20,
          'total': 1,
          'total_pages': 1,
        },
      );

      final page = await dataSource.listOrders(page: 1, limit: 20);

      expect(client.getPath, contains('/api/v1/dashboard/orders'));
      expect(client.getPath, contains('page=1'));
      expect(client.getPath, contains('limit=20'));
      expect(page.orders.length, 1);
      expect(page.orders.first.id, 'order-1');
      expect(page.page, 1);
      expect(page.total, 1);
      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('parses an empty list with zero totals', () async {
      client.response = const NetworkResponse(
        statusCode: 200,
        data: [],
        meta: {'page': 1, 'limit': 20, 'total': 0, 'total_pages': 0},
      );

      final page = await dataSource.listOrders(page: 1, limit: 20);

      expect(page.orders, isEmpty);
      expect(page.hasMore, isFalse);
    });

    test('falls back deterministically when meta is absent', () async {
      client.response = NetworkResponse(statusCode: 200, data: [_orderJson()]);

      final fullPage = await dataSource.listOrders(page: 1, limit: 1);
      expect(fullPage.hasMore, isTrue);

      client.response = const NetworkResponse(statusCode: 200, data: []);
      final emptyPage = await dataSource.listOrders(page: 2, limit: 20);
      expect(emptyPage.hasMore, isFalse);
    });

    test('rejects a non-list payload', () async {
      client.response = const NetworkResponse(
        statusCode: 200,
        data: {'not': 'a list'},
      );

      expect(
        () => dataSource.listOrders(page: 1, limit: 20),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('rejects malformed order entries', () async {
      client.response = const NetworkResponse(
        statusCode: 200,
        data: [
          {'id': 'order-1'},
        ],
      );

      expect(
        () => dataSource.listOrders(page: 1, limit: 20),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('propagates API failures', () async {
      client.error = const ApiException(401, 'expired');

      expect(
        () => dataSource.listOrders(page: 1, limit: 20),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('getOrderById', () {
    test('requests the order path and parses the order', () async {
      client.response = NetworkResponse(
        statusCode: 200,
        data: _orderJson(),
      );

      final order = await dataSource.getOrderById('order-1');

      expect(client.getPath, '/api/v1/dashboard/orders/order-1');
      expect(order.id, 'order-1');
      expect(order.items.length, 2);
    });

    test('propagates the 404 for a missing or foreign order', () async {
      client.error = const ApiException(404, 'Order not found');

      expect(
        () => dataSource.getOrderById('order-1'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.statusCode,
            'statusCode',
            404,
          ),
        ),
      );
    });

    test('rejects a malformed order payload', () async {
      client.response = const NetworkResponse(
        statusCode: 200,
        data: {'id': 'order-1'},
      );

      expect(
        () => dataSource.getOrderById('order-1'),
        throwsA(isA<InvalidResponseException>()),
      );
    });
  });
  });
}

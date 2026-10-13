import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/products/data/datasources/product_remote_datasource.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';

class _FakeApiClient implements ApiClient {
  NetworkResponse? response;
  AppException? error;
  String? getPath;

  @override
  void setAuthToken(String? token) {}

  @override
  Future<NetworkResponse> get(String path, {Map<String, String>? headers}) async {
    getPath = path;
    if (error != null) throw error!;
    return response!;
  }

  @override
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  Future<NetworkResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  Future<NetworkResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();
}

Map<String, dynamic> _productJson(String id) => {
  'id': id,
  'merchant_id': 'merchant-1',
  'category_id': 'cat-1',
  'name': 'Product $id',
  'sku': 'SKU-$id',
  'description': 'Description $id',
  'price': 12000,
  'currency': 'IDR',
  'image_url': 'https://cdn.example.com/$id.png',
  'active': true,
  'created_at': '2026-10-07T08:00:00Z',
  'updated_at': '2026-10-07T08:00:00Z',
};

NetworkResponse _pageResponse(
  List<Map<String, dynamic>> items, {
  Map<String, dynamic>? meta,
}) => NetworkResponse(
  statusCode: 200,
  data: items,
  meta:
      meta ??
      {'page': 1, 'limit': 20, 'total': items.length, 'total_pages': 1},
);

void main() {
  group('ProductRemoteDataSourceImpl.listProducts', () {
    late _FakeApiClient client;
    late ProductRemoteDataSourceImpl dataSource;

    setUp(() {
      client = _FakeApiClient();
      dataSource = ProductRemoteDataSourceImpl(client);
    });

    test('sends default pagination and parses data with meta', () async {
      client.response = _pageResponse([_productJson('prod-1')]);

      final page = await dataSource.listProducts();

      final uri = Uri.parse(client.getPath!);
      expect(uri.path, '/api/v1/dashboard/products');
      expect(uri.queryParameters['page'], '1');
      expect(uri.queryParameters['limit'], '20');
      expect(page.products.length, 1);
      expect(page.products.first.imageUrl, 'https://cdn.example.com/prod-1.png');
      expect(page.page, 1);
      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('sends filters with explicit pagination', () async {
      client.response = _pageResponse(
        [_productJson('prod-1')],
        meta: {'page': 2, 'limit': 5, 'total': 12, 'total_pages': 3},
      );

      final page = await dataSource.listProducts(
        categoryId: 'cat-1',
        active: true,
        search: '  tea  ',
        page: 2,
        limit: 5,
      );

      final uri = Uri.parse(client.getPath!);
      expect(uri.queryParameters['category_id'], 'cat-1');
      expect(uri.queryParameters['active'], 'true');
      expect(uri.queryParameters['search'], 'tea');
      expect(uri.queryParameters['page'], '2');
      expect(uri.queryParameters['limit'], '5');
      expect(page.page, 2);
      expect(page.total, 12);
      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);
    });

    test('omits empty filters but always sends pagination', () async {
      client.response = _pageResponse([]);

      await dataSource.listProducts(search: '   ');

      final uri = Uri.parse(client.getPath!);
      expect(uri.queryParameters.containsKey('search'), isFalse);
      expect(uri.queryParameters.containsKey('category_id'), isFalse);
      expect(uri.queryParameters['page'], '1');
      expect(uri.queryParameters['limit'], '20');
    });

    test('falls back deterministically when meta is absent', () async {
      client.response = const NetworkResponse(statusCode: 200, data: []);

      final empty = await dataSource.listProducts();
      expect(empty.products, isEmpty);
      expect(empty.hasMore, isFalse);
    });

    test('rejects a non-list payload', () async {
      client.response = const NetworkResponse(
        statusCode: 200,
        data: {'not': 'a list'},
      );

      expect(
        () => dataSource.listProducts(),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('propagates API failures', () async {
      client.error = const ApiException(401, 'expired');

      expect(
        () => dataSource.listProducts(),
        throwsA(isA<ApiException>()),
      );
    });

    test('parses legacy items without image_url', () async {
      final item = _productJson('prod-legacy')..remove('image_url');
      client.response = _pageResponse([item]);

      final page = await dataSource.listProducts();

      expect(page.products.single.imageUrl, isNull);
      expect(
        page.products.single,
        isA<Product>(),
      );
    });
  });
}

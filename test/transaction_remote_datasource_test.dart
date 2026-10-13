import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';

class _FakeApiClient implements ApiClient {
  NetworkResponse? getResponse;
  AppException? getError;
  final List<String> getCalls = [];

  @override
  void setAuthToken(String? token) {}

  @override
  Future<NetworkResponse> get(
    String path, {
    Map<String, String>? headers,
  }) async {
    getCalls.add(path);
    if (getError != null) throw getError!;
    return getResponse!;
  }

  @override
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async => throw UnimplementedError();

  @override
  Future<NetworkResponse> post(
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

Map<String, dynamic> _item(String id, {String? orderId}) {
  final map = <String, dynamic>{
    'transaction_id': id,
    'merchant_order_id': 'merchant-$id',
  'amount': 20000,
  'currency': 'IDR',
  'payment_method': 'QRIS',
  'status': 'PENDING',
    'created_at': '2026-01-01T10:00:00Z',
    'updated_at': '2026-01-01T10:00:00Z',
  };
  final oid = orderId;
  if (oid != null) map['order_id'] = oid;
  return map;
}

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
  group('TransactionRemoteDataSourceImpl.getTransactions', () {
    late _FakeApiClient fakeClient;
    late TransactionRemoteDataSourceImpl dataSource;

    setUp(() {
      fakeClient = _FakeApiClient();
      dataSource = TransactionRemoteDataSourceImpl(fakeClient);
    });

    test('sends default pagination and parses data with meta', () async {
      fakeClient.getResponse = _pageResponse([
        _item('tx-1', orderId: 'order-1'),
      ]);

      final page = await dataSource.getTransactions();

      final uri = Uri.parse(fakeClient.getCalls.single);
      expect(uri.path, '/api/v1/dashboard/payments');
      expect(uri.queryParameters['page'], '1');
      expect(uri.queryParameters['limit'], '20');
      expect(uri.queryParameters.containsKey('status'), isFalse);
      expect(uri.queryParameters.containsKey('search'), isFalse);
      expect(page.transactions.length, 1);
      expect(page.transactions.first.orderId, 'order-1');
      expect(page.page, 1);
      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('sends status, method, and search filters', () async {
      fakeClient.getResponse = _pageResponse([]);

      await dataSource.getTransactions(
        const TransactionFilter(
          status: 'PAID',
          paymentMethod: 'QRIS',
          search: '  ORDER-1  ',
        ),
      );

      final uri = Uri.parse(fakeClient.getCalls.single);
      expect(uri.queryParameters['status'], 'PAID');
      expect(uri.queryParameters['payment_method'], 'QRIS');
      // Search is trimmed before sending.
      expect(uri.queryParameters['search'], 'ORDER-1');
    });

    test('sends the half-open date range unchanged', () async {
      fakeClient.getResponse = _pageResponse([]);
      final from = DateTime.utc(2026, 1, 1);
      final to = DateTime.utc(2026, 2, 1);

      await dataSource.getTransactions(
        TransactionFilter(from: from, to: to),
      );

      final uri = Uri.parse(fakeClient.getCalls.single);
      expect(uri.queryParameters['created_from'], from.toIso8601String());
      expect(uri.queryParameters['created_to'], to.toIso8601String());
    });

    test('omits empty and null optionals', () async {
      fakeClient.getResponse = _pageResponse([]);

      await dataSource.getTransactions(
        const TransactionFilter(page: 2, search: '   '),
      );

      final uri = Uri.parse(fakeClient.getCalls.single);
      expect(uri.queryParameters.containsKey('status'), isFalse);
      expect(uri.queryParameters.containsKey('payment_method'), isFalse);
      expect(uri.queryParameters.containsKey('search'), isFalse);
      expect(uri.queryParameters.containsKey('created_from'), isFalse);
      expect(uri.queryParameters.containsKey('created_to'), isFalse);
      // Pagination always travels.
      expect(uri.queryParameters['page'], '2');
      expect(uri.queryParameters['limit'], '20');
    });

    test('respects backend pagination metadata', () async {
      fakeClient.getResponse = _pageResponse(
        [_item('tx-1')],
        meta: {'page': 1, 'limit': 1, 'total': 3, 'total_pages': 3},
      );

      final page = await dataSource.getTransactions(
        const TransactionFilter(page: 1, limit: 1),
      );

      expect(page.page, 1);
      expect(page.total, 3);
      expect(page.totalPages, 3);
      expect(page.hasMore, isTrue);
    });

    test('rejects a non-list payload', () async {
      fakeClient.getResponse = const NetworkResponse(
        statusCode: 200,
        data: {'not': 'a list'},
      );

      expect(
        () => dataSource.getTransactions(),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('rejects malformed entries', () async {
      fakeClient.getResponse = _pageResponse([
        {'transaction_id': 'tx-1'},
      ]);

      expect(
        () => dataSource.getTransactions(),
        throwsA(isA<InvalidResponseException>()),
      );
    });

    test('propagates API failures', () async {
      fakeClient.getError = const ApiException(400, 'bad status');

      expect(
        () => dataSource.getTransactions(
          const TransactionFilter(status: 'BOGUS'),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('parses legacy items without order_id', () async {
      fakeClient.getResponse = _pageResponse([_item('tx-legacy')]);

      final page = await dataSource.getTransactions();

      expect(page.transactions.single.orderId, isNull);
      expect(page.transactions.single.status, TransactionStatus.pending);
    });
  });
}

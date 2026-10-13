import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';

/// A fake [ApiClient] for testing the payment remote data source.
class _FakeApiClient implements ApiClient {
  NetworkResponse? getResponse;
  NetworkResponse? postResponse;
  AppException? getError;
  AppException? postError;

  final List<String> getCalls = [];
  final List<_PostCall> postCalls = [];

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
  Future<NetworkResponse> post(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    postCalls.add(_PostCall(path, body, headers));
    if (postError != null) throw postError!;
    return postResponse!;
  }

  @override
  Future<NetworkResponse> put(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<NetworkResponse> patch(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<NetworkResponse> delete(
    String path, {
    Object? body,
    Map<String, String>? headers,
  }) async {
    throw UnimplementedError();
  }
}

class _PostCall {
  _PostCall(this.path, this.body, this.headers);
  final String path;
  final Object? body;
  final Map<String, String>? headers;
}

NetworkResponse _paymentResponse() => NetworkResponse(
      statusCode: 200,
      data: {
        'transaction_id': '550e8400-e29b-41d4-a716-446655440000',
        'merchant_order_id': 'ORDER-2026-0001',
        'amount': 150000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'provider': 'mock',
        'provider_transaction_id': 'prov-tx-001',
        'payment_url': 'https://pay.example.com/checkout/abc',
        'status': 'CREATED',
        'expired_at': '2026-01-01T12:00:00Z',
        'paid_at': null,
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-01T10:00:00Z',
      },
    );

void main() {
  group('PaymentRemoteDataSourceImpl', () {
    late _FakeApiClient fakeClient;
    late PaymentRemoteDataSourceImpl dataSource;

    setUp(() {
      fakeClient = _FakeApiClient();
      dataSource = PaymentRemoteDataSourceImpl(fakeClient);
    });

    group('createPayment', () {
      test('sends correct request and parses response', () async {
        fakeClient.postResponse = NetworkResponse(
          statusCode: 201,
          data: {
            'transaction_id': '550e8400-e29b-41d4-a716-446655440000',
            'merchant_order_id': 'ORDER-2026-0001',
            'amount': 150000,
            'currency': 'IDR',
            'payment_method': 'QRIS',
            'provider': 'mock',
            'provider_transaction_id': 'prov-tx-001',
            'status': 'CREATED',
            'payment_url': 'https://pay.example.com/checkout/abc',
            'expired_at': '2026-01-01T12:00:00Z',
            'created_at': '2026-01-01T10:00:00Z',
            'updated_at': '2026-01-01T10:00:00Z',
          },
        );

        final result = await dataSource.createPayment(
          merchantOrderId: 'ORDER-2026-0001',
          amount: 150000,
          currency: 'IDR',
          paymentMethod: 'QRIS',
          idempotencyKey: 'idem-key-001',
        );

        expect(result.transactionId, '550e8400-e29b-41d4-a716-446655440000');
        expect(result.merchantOrderId, 'ORDER-2026-0001');
        expect(result.amount, 150000);
        expect(result.status, PaymentStatus.created);

        // Verify the request was sent correctly.
        expect(fakeClient.postCalls.length, 1);
        final call = fakeClient.postCalls.first;
        expect(call.path, '/api/v1/dashboard/payments');
        expect(call.body, {
          'merchant_order_id': 'ORDER-2026-0001',
          'amount': 150000,
          'currency': 'IDR',
          'payment_method': 'QRIS',
        });
        expect(call.headers?['Idempotency-Key'], 'idem-key-001');
      });

      test('throws InvalidResponseException on non-map data', () async {
        fakeClient.postResponse = NetworkResponse(
          statusCode: 201,
          data: 'not a map',
        );

        expect(
          () => dataSource.createPayment(
            merchantOrderId: 'ORDER-001',
            amount: 1000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key',
          ),
          throwsA(isA<InvalidResponseException>()),
        );
      });

      test('propagates AppException from client', () async {
        fakeClient.postError = const ApiException(409, 'DUPLICATE_ORDER');

        expect(
          () => dataSource.createPayment(
            merchantOrderId: 'ORDER-001',
            amount: 1000,
            currency: 'IDR',
            paymentMethod: 'QRIS',
            idempotencyKey: 'key',
          ),
          throwsA(isA<ApiException>()),
        );
      });
    });

    group('getPayment', () {
      test('sends correct request and parses response', () async {
        fakeClient.getResponse = _paymentResponse();

        final result = await dataSource.getPayment('550e8400-e29b-41d4-a716-446655440000');

        expect(result.transactionId, '550e8400-e29b-41d4-a716-446655440000');
        expect(fakeClient.getCalls.length, 1);
        expect(
          fakeClient.getCalls.first,
          '/api/v1/dashboard/payments/550e8400-e29b-41d4-a716-446655440000',
        );
      });

      test('throws InvalidResponseException on non-map data', () async {
        fakeClient.getResponse = NetworkResponse(
          statusCode: 200,
          data: 'not a map',
        );

        expect(
          () => dataSource.getPayment('some-id'),
          throwsA(isA<InvalidResponseException>()),
        );
      });
    });

    group('listPayments', () {
      test('sends correct request and parses response list', () async {
        fakeClient.getResponse = NetworkResponse(
          statusCode: 200,
          data: [
            {
              'transaction_id': '550e8400-e29b-41d4-a716-446655440000',
              'merchant_order_id': 'ORDER-001',
              'amount': 1000,
              'currency': 'IDR',
              'payment_method': 'QRIS',
              'status': 'CREATED',
              'created_at': '2026-01-01T10:00:00Z',
              'updated_at': '2026-01-01T10:00:00Z',
            },
            {
              'transaction_id': '660e8400-e29b-41d4-a716-446655440001',
              'merchant_order_id': 'ORDER-002',
              'amount': 2000,
              'currency': 'IDR',
              'payment_method': 'QRIS',
              'status': 'PAID',
              'created_at': '2026-01-02T10:00:00Z',
              'updated_at': '2026-01-02T10:00:00Z',
            },
          ],
        );

        final results = await dataSource.listPayments();

        expect(results.length, 2);
        expect(results[0].merchantOrderId, 'ORDER-001');
        expect(results[1].merchantOrderId, 'ORDER-002');
        expect(results[1].status, PaymentStatus.paid);
        expect(fakeClient.getCalls.length, 1);
        expect(fakeClient.getCalls.first, '/api/v1/dashboard/payments');
      });

      test('throws InvalidResponseException on non-list data', () async {
        fakeClient.getResponse = NetworkResponse(
          statusCode: 200,
          data: {'not': 'a list'},
        );

        expect(
          () => dataSource.listPayments(),
          throwsA(isA<InvalidResponseException>()),
        );
      });

      test('returns empty list when data is empty', () async {
        fakeClient.getResponse = NetworkResponse(
          statusCode: 200,
          data: [],
        );

        final results = await dataSource.listPayments();
        expect(results, isEmpty);
      });
    });

    group('listOrderPayments', () {
      test('gets the order-scoped history path and parses items', () async {
        fakeClient.getResponse = NetworkResponse(
          statusCode: 200,
          data: [
            {
              'transaction_id': 'tx-new',
              'order_id': 'order-123',
              'merchant_order_id': 'order-order-123-b',
              'amount': 20000,
              'currency': 'IDR',
              'payment_method': 'QRIS',
              'status': 'PENDING',
              'created_at': '2026-01-02T10:00:00Z',
              'updated_at': '2026-01-02T10:00:00Z',
            },
            {
              'transaction_id': 'tx-old',
              'order_id': 'order-123',
              'merchant_order_id': 'order-order-123-a',
              'amount': 20000,
              'currency': 'IDR',
              'payment_method': 'QRIS',
              'status': 'FAILED',
              'created_at': '2026-01-01T10:00:00Z',
              'updated_at': '2026-01-01T10:00:00Z',
            },
          ],
        );

        final results = await dataSource.listOrderPayments('order-123');

        expect(fakeClient.getCalls.length, 1);
        expect(
          fakeClient.getCalls.first,
          '/api/v1/dashboard/orders/order-123/payments',
        );
        expect(results.length, 2);
        expect(results[0].orderId, 'order-123');
        expect(results[0].status, PaymentStatus.pending);
        expect(results[1].status, PaymentStatus.failed);
      });

      test('throws InvalidResponseException on non-list data', () async {
        fakeClient.getResponse = NetworkResponse(
          statusCode: 200,
          data: {'not': 'a list'},
        );

        expect(
          () => dataSource.listOrderPayments('order-123'),
          throwsA(isA<InvalidResponseException>()),
        );
      });

      test('returns empty list when no attempt exists', () async {
        fakeClient.getResponse = NetworkResponse(statusCode: 200, data: []);

        expect(await dataSource.listOrderPayments('order-123'), isEmpty);
      });
    });
  });
}

import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/transactions/data/models/transaction_model.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';

/// Contract for remote transaction data sources.
///
/// Implementations handle actual HTTP calls through the shared core
/// [ApiClient]. All endpoints use the Dashboard API surface
/// (`/api/v1/dashboard/payments`) authenticated via the Bearer JWT managed
/// by the API client — never the Merchant API (`/api/v1/payments`) which
/// requires a separate `X-API-Key` credential.
abstract class TransactionRemoteDataSource {
  const TransactionRemoteDataSource();

  /// `GET /api/v1/dashboard/payments`
  ///
  /// Returns one page of the paginated transaction list for the
  /// authenticated merchant. Only the filter criteria set on [filter] are
  /// sent as query parameters; absent or blank values are omitted.
  /// Defaults to the first page with the backend page size.
  Future<TransactionPage> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]);

  /// `GET /api/v1/dashboard/payments/{payment_id}`
  ///
  /// Returns a single transaction with its timeline.
  Future<TransactionModel> getTransactionById(String transactionId);
}

/// HTTP implementation of [TransactionRemoteDataSource] backed by the shared
/// core [ApiClient].
class TransactionRemoteDataSourceImpl extends TransactionRemoteDataSource {
  const TransactionRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<TransactionPage> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    final query = <String, String>{
      'page': '${filter.page}',
      'limit': '${filter.limit}',
    };
    if (filter.status != null && filter.status!.isNotEmpty) {
      query['status'] = filter.status!;
    }
    if (filter.paymentMethod != null && filter.paymentMethod!.isNotEmpty) {
      query['payment_method'] = filter.paymentMethod!;
    }
    final search = filter.search?.trim();
    if (search != null && search.isNotEmpty) {
      query['search'] = search;
    }
    if (filter.from != null) {
      query['created_from'] = filter.from!.toUtc().toIso8601String();
    }
    if (filter.to != null) {
      query['created_to'] = filter.to!.toUtc().toIso8601String();
    }
    final path = Uri(
      path: ApiEndpoints.dashboardPayments,
      queryParameters: query,
    ).toString();
    final response = await _apiClient.get(path);
    final data = response.data;
    if (data is! List) {
      throw const InvalidResponseException(
        'Expected a transaction list but received an unexpected payload',
      );
    }
    try {
      final transactions = [
        for (final item in data)
          TransactionModel.fromJson(item as Map<String, dynamic>),
      ];
      return TransactionPage(
        transactions: transactions,
        page: _metaInt(response.meta, 'page', filter.page),
        limit: _metaInt(response.meta, 'limit', filter.limit),
        total: _metaInt(response.meta, 'total', transactions.length),
        totalPages: _metaInt(
          response.meta,
          'total_pages',
          transactions.length < filter.limit ? filter.page : filter.page + 1,
        ),
      );
    } on FormatException {
      throw const InvalidResponseException(
        'The server returned an invalid transaction response',
      );
    } on TypeError {
      throw const InvalidResponseException(
        'The server returned an invalid transaction response',
      );
    }
  }

  int _metaInt(dynamic meta, String key, int fallback) {
    if (meta is Map<String, dynamic>) {
      final value = meta[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return fallback;
  }

  @override
  Future<TransactionModel> getTransactionById(String transactionId) async {
    final path = ApiEndpoints.dashboardPaymentById
        .replaceAll('{payment_id}', transactionId);
    final response = await _apiClient.get(path);
    return _parseTransaction(response);
  }

  /// Unwraps the success envelope data into a [TransactionModel].
  ///
  /// The shared API client already unwraps `{"success": true, "data": ...}`,
  /// so [NetworkResponse.data] is the inner payload directly.
  TransactionModel _parseTransaction(NetworkResponse response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Expected a transaction object but received an unexpected payload',
      );
    }
    return TransactionModel.fromJson(data);
  }
}

import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/core/network/network_response.dart';
import 'package:payment_simulator/features/payments/data/models/payment_model.dart';

/// Contract for remote payment data sources.
///
/// Implementations handle actual HTTP calls through the shared core
/// [ApiClient]. All endpoints use the Dashboard API surface
/// (`/api/v1/dashboard/payments`) authenticated via the Bearer JWT managed
/// by the API client — never the Merchant API (`/api/v1/payments`) which
/// requires a separate `X-API-Key` credential.
abstract class PaymentRemoteDataSource {
  const PaymentRemoteDataSource();

  /// `POST /api/v1/dashboard/payments`
  ///
  /// Creates a new payment. The [idempotencyKey] is sent as the
  /// `Idempotency-Key` header (required by the backend for every
  /// payment creation call).
  Future<PaymentModel> createPayment({
    required String merchantOrderId,
    required int amount,
    required String currency,
    required String paymentMethod,
    required String idempotencyKey,
  });

  /// `GET /api/v1/dashboard/payments/{payment_id}`
  ///
  /// Returns a single payment with its timeline.
  Future<PaymentModel> getPayment(String paymentId);

  /// `GET /api/v1/dashboard/payments`
  ///
  /// Returns the paginated payment list for the authenticated merchant.
  Future<List<PaymentModel>> listPayments();

  /// `POST /api/v1/dashboard/payments/{payment_id}/simulate/success`
  ///
  /// Simulates a successful payment outcome through the dashboard simulation
  /// endpoint. Returns the updated payment.
  Future<PaymentModel> simulateSuccess(String paymentId);

  /// `POST /api/v1/dashboard/payments/{payment_id}/simulate/fail`
  ///
  /// Simulates a failed payment outcome through the dashboard simulation
  /// endpoint. Returns the updated payment.
  Future<PaymentModel> simulateFail(String paymentId);

  /// `POST /api/v1/dashboard/orders/{order_id}/payments`
  ///
  /// Creates a payment scoped to an existing order. Only `payment_method` is
  /// sent in the body; pricing, currency, merchant and merchant_order_id are
  /// derived server-side. The [idempotencyKey] is required.
  Future<PaymentModel> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  });

  /// `GET /api/v1/dashboard/orders/{order_id}/payments`
  ///
  /// Returns the recorded payment attempts for an order, newest first. The
  /// endpoint is strictly read-only: it never creates or mutates anything,
  /// so it is safe to call for checkout recovery. An empty list means no
  /// attempt exists yet.
  Future<List<PaymentModel>> listOrderPayments(String orderId);
}

/// HTTP implementation of [PaymentRemoteDataSource] backed by the shared
/// core [ApiClient].
class PaymentRemoteDataSourceImpl extends PaymentRemoteDataSource {
  const PaymentRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<PaymentModel> createPayment({
    required String merchantOrderId,
    required int amount,
    required String currency,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    final response = await _apiClient.post(
      ApiEndpoints.dashboardPayments,
      body: {
        'merchant_order_id': merchantOrderId,
        'amount': amount,
        'currency': currency,
        'payment_method': paymentMethod,
      },
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _parsePayment(response);
  }

  @override
  Future<PaymentModel> getPayment(String paymentId) async {
    final path = ApiEndpoints.dashboardPaymentById
        .replaceAll('{payment_id}', paymentId);
    final response = await _apiClient.get(path);
    return _parsePayment(response);
  }

  @override
  Future<List<PaymentModel>> listPayments() async {
    final response = await _apiClient.get(ApiEndpoints.dashboardPayments);
    final data = response.data;
    if (data is! List) {
      throw const InvalidResponseException(
        'Expected a payment list but received an unexpected payload',
      );
    }
    try {
      return data
          .map((item) => PaymentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    } on TypeError {
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    } on ArgumentError {
      // Unknown status enum value — the backend contract is closed, so this
      // indicates a contract change, surfaced as a typed parsing error.
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    }
  }

  @override
  Future<PaymentModel> simulateSuccess(String paymentId) async {
    final path = ApiEndpoints.dashboardPaymentSimulateSuccess
        .replaceAll('{payment_id}', paymentId);
    await _apiClient.post(path);
    // The simulate endpoint only acknowledges the transition
    // (`{"status": "PAID"}`); re-fetch the payment so callers get the
    // updated resource.
    return getPayment(paymentId);
  }

  @override
  Future<PaymentModel> simulateFail(String paymentId) async {
    final path = ApiEndpoints.dashboardPaymentSimulateFail
        .replaceAll('{payment_id}', paymentId);
    await _apiClient.post(path);
    return getPayment(paymentId);
  }

  /// Unwraps the success envelope data into a [PaymentModel].
  ///
  /// The shared API client already unwraps `{"success": true, "data": ...}`,
  /// so [NetworkResponse.data] is the inner payload directly.
  @override
  Future<PaymentModel> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    final path =
        ApiEndpoints.dashboardOrderPayments.replaceAll('{order_id}', orderId);
    final response = await _apiClient.post(
      path,
      body: {'payment_method': paymentMethod},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    return _parsePayment(response);
  }

  PaymentModel _parsePayment(NetworkResponse response) {
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Expected a payment object but received an unexpected payload',
      );
    }
    try {
      return PaymentModel.fromJson(data);
    } on FormatException {
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    } on TypeError {
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    } on ArgumentError {
      // Unknown status enum value — the backend contract is closed, so this
      // indicates a contract change, surfaced as a typed parsing error.
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    }
  }

  @override
  Future<List<PaymentModel>> listOrderPayments(String orderId) async {
    final path =
        ApiEndpoints.dashboardOrderPayments.replaceAll('{order_id}', orderId);
    final response = await _apiClient.get(path);
    final data = response.data;
    if (data is! List) {
      throw const InvalidResponseException(
        'Expected a payment list but received an unexpected payload',
      );
    }
    try {
      return data
          .map((item) => PaymentModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } on FormatException {
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    } on TypeError {
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    } on ArgumentError {
      throw const InvalidResponseException(
        'The server returned an invalid payment response',
      );
    }
  }
}

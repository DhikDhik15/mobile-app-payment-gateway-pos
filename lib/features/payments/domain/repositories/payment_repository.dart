import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';

/// Parameters for creating a payment.
class CreatePaymentParams {
  const CreatePaymentParams({
    required this.merchantOrderId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.idempotencyKey,
  });

  /// Merchant's unique order identifier (1–100 chars).
  final String merchantOrderId;

  /// Amount in smallest currency unit (must be >= 1).
  final int amount;

  /// Currency code (ISO 4217). Backend supports `IDR`.
  final String currency;

  /// Payment method. Backend supports `QRIS`.
  final String paymentMethod;

  /// Merchant-scoped idempotency key (1–255 chars). Required by the backend
  /// for every POST /payments call.
  final String idempotencyKey;
}

/// Contract for payment data operations.
///
/// All methods return a [PaymentResult] — raw HTTP responses, status codes,
/// and exceptions never escape this boundary.
abstract class PaymentRepository {
  /// Initiates a new payment for the authenticated merchant.
  Future<PaymentResult<Payment>> createPayment(CreatePaymentParams params);

  /// Returns a single payment by its transaction UUID.
  Future<PaymentResult<Payment>> getPayment(String paymentId);

  /// Returns the paginated list of payments for the authenticated merchant.
  Future<PaymentResult<List<Payment>>> listPayments();

  /// Simulates a successful payment outcome.
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId);

  /// Simulates a failed payment outcome.
  Future<PaymentResult<Payment>> simulateFail(String paymentId);

  /// Initiates a payment scoped to an existing order.
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  });

  /// Returns the recorded payment attempts for an order, newest first.
  Future<PaymentResult<List<Payment>>> listOrderPayments(String orderId);
}

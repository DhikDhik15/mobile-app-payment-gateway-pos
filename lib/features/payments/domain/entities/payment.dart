/// Domain entity representing a payment.
///
/// Pure domain object with no dependency on Flutter, Dio, or any
/// serialization framework. All fields map directly to the GO-SAAS
/// `PaymentResponse` / `CreatePaymentResponse` JSON contract.
class Payment {
  const Payment({
    required this.transactionId,
    required this.merchantOrderId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.provider,
    this.providerTransactionId,
    this.paymentUrl,
    this.expiredAt,
    this.paidAt,
  });

  /// Transaction UUID (primary identifier).
  final String transactionId;

  /// Internal Order UUID for order-backed payments.
  ///
  /// Present on order-scoped payment responses (`order_id`); absent on
  /// legacy non-order payments. Never sent by the client.
  final String? orderId;

  /// Merchant's unique order identifier.
  final String merchantOrderId;

  /// Amount in smallest currency unit (IDR: rupiah). Maps to backend int64.
  final int amount;

  /// Currency code (ISO 4217). Backend supports `IDR`.
  final String currency;

  /// Payment method. Backend supports `QRIS`.
  final String paymentMethod;

  /// Payment provider name (nullable, only present after provider call).
  final String? provider;

  /// Provider's transaction identifier (nullable).
  final String? providerTransactionId;

  /// URL to redirect the customer for payment (nullable).
  final String? paymentUrl;

  /// Current payment lifecycle status.
  final PaymentStatus status;

  /// Expiration timestamp (nullable).
  final DateTime? expiredAt;

  /// Confirmation timestamp (nullable, set when status becomes PAID).
  final DateTime? paidAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;
}

/// Payment lifecycle statuses as defined by the GO-SAAS backend.
///
/// These are the exact API values — do not invent others.
enum PaymentStatus {
  created('CREATED'),
  pending('PENDING'),
  paid('PAID'),
  failed('FAILED'),
  expired('EXPIRED'),
  cancelled('CANCELLED');

  const PaymentStatus(this.apiValue);

  /// The exact string value used by the backend API.
  final String apiValue;

  /// Parses a backend status string into a [PaymentStatus].
  ///
  /// Throws [ArgumentError] for unknown values — the backend contract is
  /// closed, so an unknown status indicates a contract change.
  static PaymentStatus fromApi(String value) {
    for (final status in PaymentStatus.values) {
      if (status.apiValue == value) return status;
    }
    throw ArgumentError('Unknown payment status: $value');
  }
}

import 'order_summary.dart';

/// Domain entity representing a financial transaction.
///
/// Pure domain object with no dependency on Flutter, Dio, or any
/// serialization framework. All fields map directly to the GO-SAAS
/// `PaymentResponse` JSON contract (transactions and payments are the
/// same entity in the backend — the database table is `transactions`
/// but the API uses `payment` terminology).
class Transaction {
  const Transaction({
    required this.transactionId,
    required this.merchantOrderId,
    required this.amount,
    required this.currency,
    required this.paymentMethod,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.orderSummary,
    this.provider,
    this.providerTransactionId,
    this.paymentUrl,
    this.expiredAt,
    this.paidAt,
  });

  /// Transaction UUID (primary identifier).
  final String transactionId;

  /// Internal Order UUID for order-backed transactions.
  ///
  /// Present on order-scoped payment responses (`order_id`); absent on
  /// legacy or generic merchant transactions. Never inferred from
  /// `merchant_order_id` — only the explicit backend field is used.
  final String? orderId;

  /// Product makeup of the linked order, when the backend embedded
  /// `order_summary` (built from immutable order-item snapshots).
  ///
  /// Null for legacy payloads and non-order transactions; naming logic
  /// falls back to [merchantOrderId] then identifiers.
  final OrderSummary? orderSummary;

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

  /// Current transaction lifecycle status.
  final TransactionStatus status;

  /// Expiration timestamp (nullable).
  final DateTime? expiredAt;

  /// Confirmation timestamp (nullable, set when status becomes PAID).
  final DateTime? paidAt;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last update timestamp.
  final DateTime updatedAt;
}

/// Transaction lifecycle statuses as defined by the GO-SAAS backend.
///
/// These are the exact API values — do not invent others.
enum TransactionStatus {
  created('CREATED'),
  pending('PENDING'),
  paid('PAID'),
  failed('FAILED'),
  expired('EXPIRED'),
  cancelled('CANCELLED');

  const TransactionStatus(this.apiValue);

  /// The exact string value used by the backend API.
  final String apiValue;

  /// Parses a backend status string into a [TransactionStatus].
  ///
  /// Throws [ArgumentError] for unknown values — the backend contract is
  /// closed, so an unknown status indicates a contract change.
  static TransactionStatus fromApi(String value) {
    for (final status in TransactionStatus.values) {
      if (status.apiValue == value) return status;
    }
    throw ArgumentError('Unknown transaction status: $value');
  }
}

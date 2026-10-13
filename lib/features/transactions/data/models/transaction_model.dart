import '../../domain/entities/order_summary.dart';
import '../../domain/entities/transaction.dart';

/// Data model for [Transaction] that handles JSON serialization.
///
/// Maps the GO-SAAS `PaymentResponse` JSON contract. All field names and
/// types match the backend exactly.
class TransactionModel extends Transaction {
  const TransactionModel({
    required super.transactionId,
    required super.merchantOrderId,
    required super.amount,
    required super.currency,
    required super.paymentMethod,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.orderId,
    super.orderSummary,
    super.provider,
    super.providerTransactionId,
    super.paymentUrl,
    super.expiredAt,
    super.paidAt,
  });

  /// Parses a backend JSON object into a [TransactionModel].
  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    return TransactionModel(
      transactionId: json['transaction_id'] as String,
      orderId: json['order_id'] as String?,
      orderSummary: _parseOrderSummary(json['order_summary']),
      merchantOrderId: json['merchant_order_id'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      paymentMethod: json['payment_method'] as String,
      provider: json['provider'] as String?,
      providerTransactionId: json['provider_transaction_id'] as String?,
      paymentUrl: json['payment_url'] as String?,
      status: TransactionStatus.fromApi(json['status'] as String),
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Serializes this model to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    final summary = orderSummary;
    return {
      'transaction_id': transactionId,
      'order_id': orderId,
      'order_summary': summary == null
          ? null
          : {
              'product_names': summary.productNames,
              'product_count': summary.productCount,
            },
      'merchant_order_id': merchantOrderId,
      'amount': amount,
      'currency': currency,
      'payment_method': paymentMethod,
      'provider': provider,
      'provider_transaction_id': providerTransactionId,
      'payment_url': paymentUrl,
      'status': status.apiValue,
      'expired_at': expiredAt?.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Parses the additive `order_summary` object.
  ///
  /// Absent or null (legacy payloads, non-order transactions) yields null so
  /// naming falls back to the merchant order reference. A present value must
  /// match the contract (`product_names` list, `product_count` int).
  static OrderSummary? _parseOrderSummary(Object? value) {
    if (value == null) return null;
    final map = value as Map<String, dynamic>;
    final names = map['product_names'] as List;
    return OrderSummary(
      productNames: [for (final name in names) name as String],
      productCount: (map['product_count'] as num).toInt(),
    );
  }
}

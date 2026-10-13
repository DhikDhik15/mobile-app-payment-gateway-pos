import 'package:payment_simulator/features/payments/domain/entities/payment.dart';

/// Data model for [Payment] that handles JSON serialization.
///
/// Maps the GO-SAAS `PaymentResponse` / `CreatePaymentResponse` JSON
/// contract. All field names and types match the backend exactly.
class PaymentModel extends Payment {
  const PaymentModel({
    required super.transactionId,
    required super.merchantOrderId,
    required super.amount,
    required super.currency,
    required super.paymentMethod,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.orderId,
    super.provider,
    super.providerTransactionId,
    super.paymentUrl,
    super.expiredAt,
    super.paidAt,
  });

  /// Parses a backend JSON object into a [PaymentModel].
  ///
  /// Throws [TypeError] / [FormatException] on malformed input — the data
  /// source converts these into [InvalidResponseException] before they reach
  /// the domain layer.
  ///
  /// `updated_at` falls back to `created_at` when absent or null: the
  /// order-scoped creation endpoint (`POST
  /// /api/v1/dashboard/orders/{order_id}/payments`, HTTP 201) returns the
  /// `CreatePaymentResponse` DTO, which carries no `updated_at` field — a
  /// just-created payment has not been updated yet. All other required
  /// fields remain strictly validated.
  factory PaymentModel.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.parse(json['created_at'] as String);
    return PaymentModel(
      transactionId: json['transaction_id'] as String,
      orderId: json['order_id'] as String?,
      merchantOrderId: json['merchant_order_id'] as String,
      amount: (json['amount'] as num).toInt(),
      currency: json['currency'] as String,
      paymentMethod: json['payment_method'] as String,
      provider: json['provider'] as String?,
      providerTransactionId: json['provider_transaction_id'] as String?,
      paymentUrl: json['payment_url'] as String?,
      status: PaymentStatus.fromApi(json['status'] as String),
      expiredAt: json['expired_at'] != null
          ? DateTime.parse(json['expired_at'] as String)
          : null,
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      createdAt: createdAt,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : createdAt,
    );
  }

  /// Serializes this model to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return {
      'transaction_id': transactionId,
      'order_id': orderId,
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
}

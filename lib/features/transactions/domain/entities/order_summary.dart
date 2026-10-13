/// Display value object for a transaction's linked-order product makeup.
///
/// Mirrors the backend `order_summary` object embedded in `PaymentResponse`
/// (built from immutable order-item snapshots, at most two names plus the
/// product-line count). Null when the backend omitted the summary (legacy
/// payloads, non-order transactions).
class OrderSummary {
  const OrderSummary({
    required this.productNames,
    required this.productCount,
  });

  /// First product names in stable order-item order (at most two).
  final List<String> productNames;

  /// Number of distinct product lines with a usable name.
  final int productCount;

  /// Usable display names with blanks removed.
  List<String> get usableNames => [
    for (final name in productNames)
      if (name.trim().isNotEmpty) name.trim(),
  ];

  /// Whether a product title can be formed (never fabricated).
  bool get isUsable => usableNames.isNotEmpty;
}

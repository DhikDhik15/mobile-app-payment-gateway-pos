import 'package:payment_simulator/features/transactions/domain/entities/order_summary.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';

/// Human-readable display name for a [Transaction].
///
/// Priority:
/// 1. Product summary from the backend `order_summary` (immutable order-item
///    snapshots): one product shows its name, two show both, more show a
///    concise `first + N others` form.
/// 2. The merchant-provided order reference ([Transaction.merchantOrderId]).
/// 3. Fallback to a clearly-labelled abbreviated Order ID or Transaction ID
///    so a raw UUID is never presented as though it were a human-readable
///    name.
///
/// Product names are only ever taken from the backend snapshot — never
/// invented, and never resolved per-row (the summary arrives embedded in the
/// list payload, so no N+1 fetching is involved).
String transactionDisplayName(Transaction transaction) {
  final productTitle = productSummaryTitle(transaction.orderSummary);
  if (productTitle != null) return productTitle;
  final merchant = transaction.merchantOrderId.trim();
  if (merchant.isNotEmpty) return merchant;
  final orderId = transaction.orderId?.trim();
  if (orderId != null && orderId.isNotEmpty) {
    return 'Order ${_abbreviated(orderId)}';
  }
  return 'Transaction ${_abbreviated(transaction.transactionId)}';
}

/// Product-based title, or null when no usable product name exists.
///
/// * One product: `Mechanical Keyboard`
/// * Two products: `Mechanical Keyboard + Mouse`
/// * More: `Mechanical Keyboard + 2 others`
String? productSummaryTitle(OrderSummary? summary) {
  final names = summary?.usableNames ?? const <String>[];
  if (names.isEmpty) return null;
  if (names.length == 1) return names.first;
  final summaryCount = summary?.productCount ?? 0;
  final count = summaryCount > 0 ? summaryCount : names.length;
  if (names.length >= 2 && count <= 2) return '${names[0]} + ${names[1]}';
  return '${names[0]} + ${count - 1} others';
}

/// Secondary reference line shown under the display name, if any.
///
/// Product-titled rows keep the merchant order ID as secondary information;
/// other rows keep the existing abbreviated Order ID reference.
String? transactionReferenceLine(Transaction transaction) {
  if (productSummaryTitle(transaction.orderSummary) != null) {
    final merchant = transaction.merchantOrderId.trim();
    if (merchant.isNotEmpty) return merchant;
  }
  final orderId = transaction.orderId?.trim();
  if (orderId != null && orderId.isNotEmpty) {
    return 'Order ${abbreviatedTransactionId(orderId)}';
  }
  return null;
}

/// Short identifier form used only as a clearly-labelled fallback/reference.
///
/// Shows the first 8 characters plus an ellipsis when truncated so the UI
/// signals that the value is abbreviated.
String abbreviatedTransactionId(String id) => _abbreviated(id);

String _abbreviated(String id) =>
    id.length <= 8 ? id : '${id.substring(0, 8)}…';

/// One-line summary shown under the display name: amount plus creation date.
String transactionSummaryLine(Transaction transaction) =>
    '${transaction.amount} ${transaction.currency} • '
    '${_formatDate(transaction.createdAt.toLocal())}';

String _formatDate(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

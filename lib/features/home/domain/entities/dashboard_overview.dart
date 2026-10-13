import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';

/// Domain entity for the merchant dashboard overview.
///
/// Maps `GET /api/v1/dashboard/overview` exactly. The backend derives all
/// aggregates for the authenticated merchant — no merchant ID is passed by
/// the client.
class DashboardOverview {
  const DashboardOverview({
    required this.revenueAmount,
    required this.currency,
    required this.paidCount,
    required this.pendingCount,
    required this.failedCount,
    required this.recentTransactions,
  });

  /// Total revenue in the smallest currency unit (IDR: rupiah) for the
  /// requested period, where status = PAID.
  final int revenueAmount;

  /// Currency code (ISO 4217) reported by the backend.
  final String currency;

  /// Number of payments with status PAID created in the period.
  final int paidCount;

  /// Number of payments with status PENDING created in the period.
  final int pendingCount;

  /// Number of payments with status FAILED created in the period.
  final int failedCount;

  /// Most recent payments for the merchant (not limited to the period).
  final List<Transaction> recentTransactions;
}

import 'package:payment_simulator/features/home/domain/entities/dashboard_overview.dart';
import 'package:payment_simulator/features/transactions/data/models/transaction_model.dart';

/// Data model for [DashboardOverview] that handles JSON serialization.
///
/// Maps the GO-SAAS `DashboardOverviewResponse` JSON contract exactly.
class DashboardOverviewModel extends DashboardOverview {
  const DashboardOverviewModel({
    required super.revenueAmount,
    required super.currency,
    required super.paidCount,
    required super.pendingCount,
    required super.failedCount,
    required super.recentTransactions,
  });

  /// Parses the backend JSON object into a [DashboardOverviewModel].
  factory DashboardOverviewModel.fromJson(Map<String, dynamic> json) {
    final revenue = json['revenue'];
    final payments = json['payments'];
    final recent = json['recent_payments'];

    return DashboardOverviewModel(
      revenueAmount: revenue is Map
          ? ((revenue['amount'] as num?)?.toInt() ?? 0)
          : 0,
      currency: revenue is Map
          ? (revenue['currency'] as String? ?? 'IDR')
          : 'IDR',
      paidCount: payments is Map
          ? ((payments['paid'] as num?)?.toInt() ?? 0)
          : 0,
      pendingCount: payments is Map
          ? ((payments['pending'] as num?)?.toInt() ?? 0)
          : 0,
      failedCount: payments is Map
          ? ((payments['failed'] as num?)?.toInt() ?? 0)
          : 0,
      recentTransactions: recent is List
          ? recent
              .whereType<Map<String, dynamic>>()
              .map(TransactionModel.fromJson)
              .toList()
          : const [],
    );
  }
}

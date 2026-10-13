import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/home/data/models/dashboard_overview_model.dart';

void main() {
  test('parses DashboardOverviewResponse JSON', () {
    final model = DashboardOverviewModel.fromJson({
      'revenue': {'amount': 125000, 'currency': 'IDR'},
      'payments': {'paid': 2, 'pending': 1, 'failed': 0, 'created': 3, 'expired': 0, 'cancelled': 0},
      'refunds': {'amount': 0, 'count': 0, 'currency': 'IDR'},
      'period': {'from': '2026-10-06T00:00:00Z', 'to': '2026-10-07T00:00:00Z'},
      'recent_payments': [
        {
          'transaction_id': 'tx-1',
          'merchant_order_id': 'order-1',
          'amount': 50000,
          'currency': 'IDR',
          'payment_method': 'QRIS',
          'status': 'PAID',
          'created_at': '2026-10-06T08:00:00Z',
          'updated_at': '2026-10-06T08:05:00Z',
        },
      ],
    });

    expect(model.revenueAmount, 125000);
    expect(model.currency, 'IDR');
    expect(model.paidCount, 2);
    expect(model.pendingCount, 1);
    expect(model.failedCount, 0);
    expect(model.recentTransactions, hasLength(1));
    expect(model.recentTransactions.first.transactionId, 'tx-1');
  });

  test('tolerates missing nested objects', () {
    final model = DashboardOverviewModel.fromJson({});
    expect(model.revenueAmount, 0);
    expect(model.currency, 'IDR');
    expect(model.recentTransactions, isEmpty);
  });
}

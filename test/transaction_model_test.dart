import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/transactions/data/models/transaction_model.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';

Map<String, dynamic> _json({Map<String, dynamic>? overrides}) => {
  'transaction_id': 'tx-1',
  'merchant_order_id': 'order-order-1-a',
  'amount': 20000,
  'currency': 'IDR',
  'payment_method': 'QRIS',
  'status': 'PENDING',
  'created_at': '2026-01-01T10:00:00Z',
  'updated_at': '2026-01-01T10:00:00Z',
  ...?overrides,
};

void main() {
  group('TransactionModel order linkage', () {
    test('parses a present order_id', () {
      final model = TransactionModel.fromJson(
        _json(overrides: {'order_id': 'order-123'}),
      );

      expect(model.orderId, 'order-123');
      expect(model.toJson()['order_id'], 'order-123');
    });

    test('parses an explicit null order_id', () {
      final model = TransactionModel.fromJson(
        _json(overrides: {'order_id': null}),
      );

      expect(model.orderId, isNull);
    });

    test('stays backward-compatible when order_id is absent', () {
      final model = TransactionModel.fromJson(_json());

      expect(model.orderId, isNull);
      expect(model.transactionId, 'tx-1');
      expect(model.merchantOrderId, 'order-order-1-a');
      expect(model.status, TransactionStatus.pending);
    });

    test('existing fields remain unchanged', () {
      final model = TransactionModel.fromJson(
        _json(
          overrides: {
            'order_id': 'order-123',
            'provider': 'mock',
            'provider_transaction_id': 'prov-1',
            'payment_url': 'https://pay.example.com/x',
            'status': 'PAID',
            'expired_at': '2026-01-01T12:00:00Z',
            'paid_at': '2026-01-01T11:00:00Z',
          },
        ),
      );

      expect(model.provider, 'mock');
      expect(model.providerTransactionId, 'prov-1');
      expect(model.paymentUrl, 'https://pay.example.com/x');
      expect(model.status, TransactionStatus.paid);
      expect(
        model.expiredAt,
        DateTime.parse('2026-01-01T12:00:00Z'),
      );
      expect(model.paidAt, DateTime.parse('2026-01-01T11:00:00Z'));
    });
  });
}

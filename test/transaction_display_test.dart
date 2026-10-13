import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_display.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_list_item.dart';

Transaction _transaction({
  required String id,
  required String merchantOrderId,
  String? orderId,
}) => Transaction(
  transactionId: id,
  orderId: orderId,
  merchantOrderId: merchantOrderId,
  amount: 20000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: TransactionStatus.pending,
  createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
  updatedAt: DateTime.parse('2026-01-01T10:00:00Z'),
);

void main() {
  group('transactionDisplayName', () {
    test('uses the merchant-provided order reference when present', () {
      final tx = _transaction(
        id: 'tx-uuid-1',
        merchantOrderId: 'ORDER-2026-0001',
        orderId: 'order-uuid-9',
      );
      expect(transactionDisplayName(tx), 'ORDER-2026-0001');
    });

    test('falls back to the linked order reference when name is blank', () {
      final tx = _transaction(
        id: 'tx-uuid-1',
        merchantOrderId: '   ',
        orderId: '1234567890abcdef',
      );
      final name = transactionDisplayName(tx);
      expect(name, contains('Order'));
      expect(name, contains('12345678'));
      // The raw UUID is labelled and abbreviated, never bare.
      expect(name == '1234567890abcdef', isFalse);
    });

    test('falls back to the transaction identifier without order linkage', () {
      final tx = _transaction(
        id: 'abcdef1234567890',
        merchantOrderId: '',
      );
      final name = transactionDisplayName(tx);
      expect(name, contains('Transaction'));
      expect(name, contains('abcdef12'));
      expect(name == 'abcdef1234567890', isFalse);
    });

    test('never invents product names', () {
      // A transaction carrying several products has no product-level field;
      // the display name must be the order-level reference, not one product
      // presented as the whole transaction.
      final tx = _transaction(
        id: 'tx-multi',
        merchantOrderId: 'ORDER-MULTI-1',
        orderId: 'order-multi',
      );
      expect(transactionDisplayName(tx), 'ORDER-MULTI-1');
      expect(transactionDisplayName(tx), isNot(contains('Coffee')));
    });
  });

  group('TransactionListItem layout', () {
    testWidgets('long names ellipsize instead of overflowing', (tester) async {
      final longName = 'ORDER-${'X' * 120}';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionListItem(
              transaction: _transaction(
                id: 'tx-long',
                merchantOrderId: longName,
                orderId: 'order-1',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(
        find.text(longName),
      );
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      // No overflow errors are raised during layout.
      expect(tester.takeException(), isNull);
    });

    testWidgets('history title matches the display-name source', (tester) async {
      const merchantRef = 'merchant-tx-9';
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransactionListItem(
              transaction: _transaction(
                id: 'tx-9',
                merchantOrderId: merchantRef,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(merchantRef), findsOneWidget);
    });
  });
}

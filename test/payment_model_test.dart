import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/payments/data/models/payment_model.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';

void main() {
  group('PaymentModel', () {
    test('fromJson parses a complete payment response correctly', () {
      final json = {
        'transaction_id': '550e8400-e29b-41d4-a716-446655440000',
        'merchant_order_id': 'ORDER-2026-0001',
        'amount': 150000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'provider': 'mock',
        'provider_transaction_id': 'prov-tx-001',
        'payment_url': 'https://pay.example.com/checkout/abc',
        'status': 'CREATED',
        'expired_at': '2026-01-01T12:00:00Z',
        'paid_at': null,
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-01T10:00:00Z',
      };

      final model = PaymentModel.fromJson(json);

      expect(model.transactionId, '550e8400-e29b-41d4-a716-446655440000');
      expect(model.merchantOrderId, 'ORDER-2026-0001');
      expect(model.amount, 150000);
      expect(model.currency, 'IDR');
      expect(model.paymentMethod, 'QRIS');
      expect(model.provider, 'mock');
      expect(model.providerTransactionId, 'prov-tx-001');
      expect(model.paymentUrl, 'https://pay.example.com/checkout/abc');
      expect(model.status, PaymentStatus.created);
      expect(model.expiredAt, DateTime.parse('2026-01-01T12:00:00Z'));
      expect(model.paidAt, isNull);
      expect(model.createdAt, DateTime.parse('2026-01-01T10:00:00Z'));
      expect(model.updatedAt, DateTime.parse('2026-01-01T10:00:00Z'));
    });

    test('fromJson keeps order_id when the backend provides it', () {
      final model = PaymentModel.fromJson({
        'transaction_id': 'tx-1',
        'order_id': 'order-123',
        'merchant_order_id': 'order-order-123-a',
        'amount': 20000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'status': 'PENDING',
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-01T10:00:00Z',
      });

      expect(model.orderId, 'order-123');
      expect(model.toJson()['order_id'], 'order-123');
    });

    test('fromJson stays backward-compatible without order_id', () {
      final model = PaymentModel.fromJson({
        'transaction_id': 'tx-1',
        'merchant_order_id': 'LEGACY-1',
        'amount': 20000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'status': 'PAID',
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-01T10:00:00Z',
      });

      expect(model.orderId, isNull);
    });

    test('fromJson handles nullable fields correctly', () {
      final json = {
        'transaction_id': '550e8400-e29b-41d4-a716-446655440000',
        'merchant_order_id': 'ORDER-2026-0002',
        'amount': 50000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'provider': null,
        'provider_transaction_id': null,
        'payment_url': null,
        'status': 'PENDING',
        'expired_at': null,
        'paid_at': null,
        'created_at': '2026-01-02T08:00:00Z',
        'updated_at': '2026-01-02T08:00:00Z',
      };

      final model = PaymentModel.fromJson(json);

      expect(model.provider, isNull);
      expect(model.providerTransactionId, isNull);
      expect(model.paymentUrl, isNull);
      expect(model.expiredAt, isNull);
      expect(model.paidAt, isNull);
      expect(model.status, PaymentStatus.pending);
    });

    test('fromJson parses all status values correctly', () {
      final statuses = ['CREATED', 'PENDING', 'PAID', 'FAILED', 'EXPIRED', 'CANCELLED'];
      final expected = [
        PaymentStatus.created,
        PaymentStatus.pending,
        PaymentStatus.paid,
        PaymentStatus.failed,
        PaymentStatus.expired,
        PaymentStatus.cancelled,
      ];

      for (var i = 0; i < statuses.length; i++) {
        final json = {
          'transaction_id': '550e8400-e29b-41d4-a716-446655440000',
          'merchant_order_id': 'ORDER-001',
          'amount': 1000,
          'currency': 'IDR',
          'payment_method': 'QRIS',
          'status': statuses[i],
          'created_at': '2026-01-01T10:00:00Z',
          'updated_at': '2026-01-01T10:00:00Z',
        };
        expect(PaymentModel.fromJson(json).status, expected[i]);
      }
    });

    test('fromJson throws on unknown status', () {
      final json = {
        'transaction_id': '550e8400-e29b-41d4-a716-446655440000',
        'merchant_order_id': 'ORDER-001',
        'amount': 1000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'status': 'UNKNOWN',
        'created_at': '2026-01-01T10:00:00Z',
        'updated_at': '2026-01-01T10:00:00Z',
      };

      expect(() => PaymentModel.fromJson(json), throwsArgumentError);
    });

    test('toJson round-trips correctly', () {
      final original = PaymentModel(
        transactionId: '550e8400-e29b-41d4-a716-446655440000',
        merchantOrderId: 'ORDER-2026-0001',
        amount: 150000,
        currency: 'IDR',
        paymentMethod: 'QRIS',
        provider: 'mock',
        providerTransactionId: 'prov-tx-001',
        paymentUrl: 'https://pay.example.com/checkout/abc',
        status: PaymentStatus.created,
        expiredAt: DateTime.parse('2026-01-01T12:00:00Z'),
        createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T10:00:00Z'),
      );

      final json = original.toJson();
      final restored = PaymentModel.fromJson(json);

      expect(restored.transactionId, original.transactionId);
      expect(restored.merchantOrderId, original.merchantOrderId);
      expect(restored.amount, original.amount);
      expect(restored.currency, original.currency);
      expect(restored.paymentMethod, original.paymentMethod);
      expect(restored.provider, original.provider);
      expect(restored.providerTransactionId, original.providerTransactionId);
      expect(restored.paymentUrl, original.paymentUrl);
      expect(restored.status, original.status);
      expect(restored.expiredAt, original.expiredAt);
      expect(restored.createdAt, original.createdAt);
      expect(restored.updatedAt, original.updatedAt);
    });
  });
}

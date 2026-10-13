import 'package:flutter/material.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';

/// A color-coded status chip for transaction status.
class TransactionStatusChip extends StatelessWidget {
  const TransactionStatusChip({super.key, required this.status});

  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, label) = _styleFor(status);
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      backgroundColor: color.withValues(alpha: 0.12),
      side: BorderSide(color: color.withValues(alpha: 0.3)),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }

  (Color, String) _styleFor(TransactionStatus status) {
    return switch (status) {
      TransactionStatus.created => (Colors.blue, 'CREATED'),
      TransactionStatus.pending => (Colors.orange, 'PENDING'),
      TransactionStatus.paid => (Colors.green, 'PAID'),
      TransactionStatus.failed => (Colors.red, 'FAILED'),
      TransactionStatus.expired => (Colors.grey, 'EXPIRED'),
      TransactionStatus.cancelled => (Colors.grey, 'CANCELLED'),
    };
  }
}

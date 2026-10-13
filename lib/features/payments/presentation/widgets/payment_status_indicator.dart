import 'package:flutter/material.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';

/// A visual indicator for payment status.
///
/// Displays the backend-defined status value with a color-coded chip.
/// Uses only the exact [PaymentStatus] values from the GO-SAAS contract.
class PaymentStatusIndicator extends StatelessWidget {
  const PaymentStatusIndicator({super.key, required this.status});

  final PaymentStatus status;

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

  (Color, String) _styleFor(PaymentStatus status) {
    return switch (status) {
      PaymentStatus.created => (Colors.blue, 'CREATED'),
      PaymentStatus.pending => (Colors.orange, 'PENDING'),
      PaymentStatus.paid => (Colors.green, 'PAID'),
      PaymentStatus.failed => (Colors.red, 'FAILED'),
      PaymentStatus.expired => (Colors.grey, 'EXPIRED'),
      PaymentStatus.cancelled => (Colors.grey, 'CANCELLED'),
    };
  }
}

import 'package:flutter/material.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_display.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_status_chip.dart';

/// A list item widget for displaying a transaction.
///
/// The title uses [transactionDisplayName]: the product name (or concise
/// multi-product summary) for order-backed transactions, otherwise the
/// merchant-provided order reference, otherwise a clearly-labelled
/// identifier fallback. A raw internal UUID is never presented as a
/// human-readable name. Long names are ellipsized so they cannot break the
/// layout.
class TransactionListItem extends StatelessWidget {
  const TransactionListItem({
    super.key,
    required this.transaction,
    this.onTap,
  });

  final Transaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final reference = transactionReferenceLine(transaction);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.receipt_long_outlined),
        title: Text(
          transactionDisplayName(transaction),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          reference != null
              ? '${transactionSummaryLine(transaction)}\n$reference'
              : transactionSummaryLine(transaction),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: reference != null,
        trailing: TransactionStatusChip(status: transaction.status),
        onTap: onTap,
      ),
    );
  }
}

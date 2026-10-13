import 'package:payment_simulator/core/error/failure.dart';

import '../entities/transaction.dart';
import '../entities/transaction_filter.dart';
import '../entities/transaction_page.dart';

/// Result of a transaction use case.
///
/// A sealed type so the presentation layer can exhaustively handle success
/// and failure without catching exceptions.
sealed class TransactionResult<T> {
  const TransactionResult();
}

/// The use case succeeded.
final class TransactionSuccess<T> extends TransactionResult<T> {
  const TransactionSuccess(this.value);

  final T value;
}

/// The use case failed with a user-safe, domain-level failure.
final class TransactionError<T> extends TransactionResult<T> {
  const TransactionError(this.failure);

  final Failure failure;
}

// ── Failure types (reused from core/error/failure.dart) ────────────────────
// These are imported here for convenience but defined in the core layer.

/// Contract for transaction data operations.
///
/// All methods return a [TransactionResult] — raw HTTP responses, status
/// codes, and exceptions never escape this boundary.
abstract class TransactionRepository {
  /// Returns one page of the paginated list of transactions for the
  /// authenticated merchant, honoring [filter]. Defaults to the first
  /// page with the backend page size, preserving existing call behavior.
  Future<TransactionResult<TransactionPage>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]);

  /// Returns a single transaction by its transaction UUID.
  Future<TransactionResult<Transaction>> getTransactionById(String transactionId);
}

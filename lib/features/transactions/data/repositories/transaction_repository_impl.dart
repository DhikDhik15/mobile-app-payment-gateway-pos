import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';

/// Data-layer implementation of [TransactionRepository].
///
/// Delegates HTTP access to [TransactionRemoteDataSource] (which uses the
/// shared core `ApiClient`) and translates any [AppException] into a
/// domain [Failure] — raw exceptions never escape this boundary.
class TransactionRepositoryImpl implements TransactionRepository {
  const TransactionRepositoryImpl(this._remote);

  final TransactionRemoteDataSource _remote;

  @override
  Future<TransactionResult<TransactionPage>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    try {
      final page = await _remote.getTransactions(filter);
      return TransactionSuccess(page);
    } on AppException catch (error) {
      return TransactionError(_mapError(error));
    }
  }

  @override
  Future<TransactionResult<Transaction>> getTransactionById(
    String transactionId,
  ) async {
    try {
      final transaction = await _remote.getTransactionById(transactionId);
      return TransactionSuccess(transaction);
    } on AppException catch (error) {
      return TransactionError(_mapError(error));
    }
  }

  /// Maps a network-layer [AppException] to a domain [Failure] with a
  /// user-safe message.
  Failure _mapError(AppException error) {
    return switch (error) {
      NetworkTimeoutException() => const TimeoutFailure(),
      ConnectionNetworkException() => const ConnectionFailure(),
      ApiException() => ApiFailure(error.statusCode, error.message, error.code),
      InvalidResponseException() => const InvalidResponseFailure(),
      _ => const ServerFailure(),
    };
  }
}

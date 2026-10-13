import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';

/// Use case that retrieves one page of the paginated transaction list for
/// the authenticated merchant, honoring the given filter.
class GetTransactionsUseCase
    implements UseCase<TransactionResult<TransactionPage>, TransactionFilter> {
  const GetTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Future<TransactionResult<TransactionPage>> call([
    TransactionFilter filter = const TransactionFilter(),
  ]) =>
      _repository.getTransactions(filter);
}

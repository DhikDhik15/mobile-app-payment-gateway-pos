import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';

/// Use case that retrieves a single transaction by its transaction UUID.
class GetTransactionByIdUseCase
    implements UseCase<TransactionResult<Transaction>, GetTransactionByIdParams> {
  const GetTransactionByIdUseCase(this._repository);

  final TransactionRepository _repository;

  @override
  Future<TransactionResult<Transaction>> call(
    GetTransactionByIdParams params,
  ) =>
      _repository.getTransactionById(params.transactionId);
}

/// Parameters for [GetTransactionByIdUseCase].
class GetTransactionByIdParams {
  const GetTransactionByIdParams({required this.transactionId});

  /// Transaction UUID of the transaction to retrieve.
  final String transactionId;
}

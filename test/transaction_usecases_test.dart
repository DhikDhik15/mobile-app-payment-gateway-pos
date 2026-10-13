import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';

class _FakeTransactionRepository implements TransactionRepository {
  TransactionResult<TransactionPage>? pageResult;
  TransactionResult<Transaction>? getResult;
  TransactionFilter? lastFilter;

  @override
  Future<TransactionResult<TransactionPage>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    lastFilter = filter;
    return pageResult!;
  }

  @override
  Future<TransactionResult<Transaction>> getTransactionById(
    String transactionId,
  ) async =>
      getResult!;
}

Transaction _transaction(String id) => Transaction(
  transactionId: id,
  merchantOrderId: 'merchant-$id',
  amount: 20000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: TransactionStatus.pending,
  createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
  updatedAt: DateTime.parse('2026-01-01T10:00:00Z'),
);

void main() {
  group('GetTransactionsUseCase', () {
    test('delegates the filter and returns the page', () async {
      final repo = _FakeTransactionRepository()
        ..pageResult = TransactionSuccess(
          TransactionPage(
            transactions: [_transaction('tx-1')],
            page: 1,
            limit: 20,
            total: 1,
            totalPages: 1,
          ),
        );
      final useCase = GetTransactionsUseCase(repo);
      const filter = TransactionFilter(status: 'PAID', search: 'ORDER-1');

      final result = await useCase(filter);

      expect(result, isA<TransactionSuccess<TransactionPage>>());
      expect(repo.lastFilter?.status, 'PAID');
      expect(repo.lastFilter?.search, 'ORDER-1');
      expect(
        (result as TransactionSuccess<TransactionPage>).value.transactions
            .length,
        1,
      );
    });

    test('uses the default filter when called without arguments', () async {
      final repo = _FakeTransactionRepository()
        ..pageResult = TransactionSuccess(
          TransactionPage(
            transactions: [_transaction('tx-1')],
            page: 1,
            limit: 20,
            total: 1,
            totalPages: 1,
          ),
        );
      final useCase = GetTransactionsUseCase(repo);

      await useCase();

      expect(repo.lastFilter?.page, 1);
      expect(repo.lastFilter?.isEmpty, isTrue);
    });

    test('propagates repository failures', () async {
      final repo = _FakeTransactionRepository()
        ..pageResult = const TransactionError<TransactionPage>(
          ServerFailure(),
        );
      final useCase = GetTransactionsUseCase(repo);

      final result = await useCase();

      expect(result, isA<TransactionError<TransactionPage>>());
    });
  });

  group('TransactionFilter', () {
    test('isEmpty only when no criteria are set', () {
      expect(const TransactionFilter().isEmpty, isTrue);
      expect(
        const TransactionFilter(search: '   ').isEmpty,
        isTrue,
      );
      expect(
        const TransactionFilter(status: 'PAID').isEmpty,
        isFalse,
      );
      expect(
        TransactionFilter(from: DateTime.utc(2026)).isEmpty,
        isFalse,
      );
    });

    test('copyWith clears individual fields with null callbacks', () {
      const filter = TransactionFilter(
        status: 'PAID',
        paymentMethod: 'QRIS',
        search: 'x',
      );

      expect(filter.copyWith(status: () => null).status, isNull);
      expect(
        filter.copyWith(paymentMethod: () => null).paymentMethod,
        isNull,
      );
      expect(filter.copyWith(search: () => null).search, isNull);
      // Untouched fields survive.
      expect(filter.copyWith(status: () => null).paymentMethod, 'QRIS');
      expect(filter.copyWith().status, 'PAID');
    });
  });
}

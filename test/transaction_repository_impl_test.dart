import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:payment_simulator/features/transactions/data/models/transaction_model.dart';
import 'package:payment_simulator/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';

class _FakeTransactionRemoteDataSource extends TransactionRemoteDataSource {
  TransactionPage? pageResult;
  TransactionModel? getResult;
  AppException? error;
  TransactionFilter? lastFilter;

  @override
  Future<TransactionPage> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    lastFilter = filter;
    if (error != null) throw error!;
    return pageResult!;
  }

  @override
  Future<TransactionModel> getTransactionById(String transactionId) async {
    if (error != null) throw error!;
    return getResult!;
  }
}

TransactionModel _model(String id) => TransactionModel(
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
  group('TransactionRepositoryImpl.getTransactions', () {
    late _FakeTransactionRemoteDataSource fakeRemote;
    late TransactionRepositoryImpl repository;

    setUp(() {
      fakeRemote = _FakeTransactionRemoteDataSource();
      repository = TransactionRepositoryImpl(fakeRemote);
    });

    test('forwards the filter and maps the page', () async {
      fakeRemote.pageResult = TransactionPage(
        transactions: [_model('tx-1')],
        page: 2,
        limit: 20,
        total: 21,
        totalPages: 2,
      );

      final result = await repository.getTransactions(
        const TransactionFilter(page: 2, status: 'PAID'),
      );

      expect(result, isA<TransactionSuccess<TransactionPage>>());
      expect(fakeRemote.lastFilter?.page, 2);
      expect(fakeRemote.lastFilter?.status, 'PAID');
      final page = (result as TransactionSuccess<TransactionPage>).value;
      expect(page.transactions.length, 1);
      expect(page.hasMore, isFalse);
    });

    test('keeps the default call compatible', () async {
      fakeRemote.pageResult = TransactionPage(
        transactions: [_model('tx-1')],
        page: 1,
        limit: 20,
        total: 1,
        totalPages: 1,
      );

      final result = await repository.getTransactions();

      expect(result, isA<TransactionSuccess<TransactionPage>>());
      expect(fakeRemote.lastFilter?.page, 1);
    });

    test('forwards backend failures with status and code', () async {
      fakeRemote.error = const ApiException(
        500,
        'The server returned an error',
        'INTERNAL_ERROR',
      );

      final result = await repository.getTransactions();

      expect(result, isA<TransactionError<TransactionPage>>());
      final failure = (result as TransactionError<TransactionPage>).failure;
      expect(failure, isA<ApiFailure>());
      expect((failure as ApiFailure).statusCode, 500);
      expect(failure.code, 'INTERNAL_ERROR');
    });
  });
}

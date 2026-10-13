import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transaction_by_id.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';

class _FakeTransactionRepository implements TransactionRepository {
  Future<TransactionResult<TransactionPage>> Function(TransactionFilter)?
  onList;
  Future<TransactionResult<Transaction>> Function(String)? onGet;
  int listCalls = 0;
  TransactionFilter? lastFilter;

  @override
  Future<TransactionResult<TransactionPage>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    listCalls++;
    lastFilter = filter;
    return onList!(filter);
  }

  @override
  Future<TransactionResult<Transaction>> getTransactionById(
    String transactionId,
  ) async =>
      onGet!(transactionId);
}

Transaction _transaction(String id) => Transaction(
  transactionId: id,
  orderId: id == 'tx-ordered' ? 'order-1' : null,
  merchantOrderId: 'merchant-$id',
  amount: 20000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: TransactionStatus.pending,
  createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
  updatedAt: DateTime.parse('2026-01-01T10:00:00Z'),
);

TransactionPage _page(
  List<Transaction> transactions, {
  int page = 1,
  bool hasMore = false,
}) => TransactionPage(
  transactions: transactions,
  page: page,
  limit: 20,
  total: transactions.length,
  totalPages: hasMore ? page + 1 : page,
);

TransactionCubit _cubit(_FakeTransactionRepository repo) => TransactionCubit(
  getTransactions: GetTransactionsUseCase(repo),
  getTransactionById: GetTransactionByIdUseCase(repo),
);

void main() {
  group('TransactionCubit listing', () {
    test('starts in TransactionInitial', () {
      expect(_cubit(_FakeTransactionRepository()).state, isA<TransactionInitial>());
    });

    test('loads the first page with the default filter', () async {
      final repo = _FakeTransactionRepository()
        ..onList = (_) async =>
            TransactionSuccess(_page([_transaction('tx-1')]));
      final cubit = _cubit(repo);

      await cubit.loadTransactions();

      final state = cubit.state;
      expect(state, isA<TransactionListLoaded>());
      final loaded = state as TransactionListLoaded;
      expect(loaded.transactions.length, 1);
      expect(loaded.hasMore, isFalse);
      expect(repo.lastFilter?.page, 1);
      expect(repo.lastFilter?.isEmpty, isTrue);
    });

    test('empty result loads successfully', () async {
      final repo = _FakeTransactionRepository()
        ..onList = (_) async => TransactionSuccess(_page(const []));
      final cubit = _cubit(repo);

      await cubit.loadTransactions();

      final state = cubit.state as TransactionListLoaded;
      expect(state.transactions, isEmpty);
    });

    test('initial failure emits failure and retry recovers', () async {
      var calls = 0;
      final repo = _FakeTransactionRepository()
        ..onList = (_) async {
          calls++;
          return calls == 1
              ? const TransactionError<TransactionPage>(ServerFailure())
              : TransactionSuccess(_page([_transaction('tx-1')]));
        };
      final cubit = _cubit(repo);

      await cubit.loadTransactions();
      expect(cubit.state, isA<TransactionFailure>());

      await cubit.loadTransactions();
      expect(cubit.state, isA<TransactionListLoaded>());
    });

    test('appends pages deduplicated by transaction id', () async {
      final repo = _FakeTransactionRepository()
        ..onList = (filter) async {
          if (filter.page == 1) {
            return TransactionSuccess(
              _page([_transaction('tx-1'), _transaction('tx-2')],
                  hasMore: true),
            );
          }
          return TransactionSuccess(
            _page([_transaction('tx-2'), _transaction('tx-3')], page: 2),
          );
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();

      await cubit.loadMore();

      final state = cubit.state as TransactionListLoaded;
      expect(
        state.transactions.map((t) => t.transactionId),
        ['tx-1', 'tx-2', 'tx-3'],
      );
      expect(state.hasMore, isFalse);
    });

    test('concurrent loadMore calls collapse into one request', () async {
      final gate = Completer<TransactionResult<TransactionPage>>();
      final repo = _FakeTransactionRepository()
        ..onList = (filter) {
          if (filter.page == 1) {
            return Future.value(
              TransactionSuccess(_page([_transaction('tx-1')], hasMore: true)),
            );
          }
          return gate.future;
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();

      final first = cubit.loadMore();
      final second = cubit.loadMore();
      await Future<void>.delayed(Duration.zero);
      expect(repo.listCalls, 2);
      gate.complete(TransactionSuccess(_page([_transaction('tx-2')], page: 2)));
      await Future.wait([first, second]);

      final state = cubit.state as TransactionListLoaded;
      expect(state.transactions.length, 2);
    });

    test('scroll loadMore is suppressed while an error shows', () async {
      var calls = 0;
      final repo = _FakeTransactionRepository()
        ..onList = (filter) async {
          calls++;
          if (filter.page == 1) {
            return TransactionSuccess(
              _page([_transaction('tx-1')], hasMore: true),
            );
          }
          return const TransactionError<TransactionPage>(ServerFailure());
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();
      await cubit.loadMore(fromScroll: true);
      expect(calls, 2);

      // Footer layout shifts must not retrigger without user intent.
      await cubit.loadMore(fromScroll: true);
      expect(calls, 2);
      final state = cubit.state as TransactionListLoaded;
      expect(state.loadMoreError, isNotNull);

      // Explicit retry still proceeds.
      await cubit.loadMore();
      expect(calls, 3);
    });

    test('loadMore stops when no more pages exist', () async {      final repo = _FakeTransactionRepository()
        ..onList = (_) async =>
            TransactionSuccess(_page([_transaction('tx-1')]));
      final cubit = _cubit(repo);
      await cubit.loadTransactions();

      await cubit.loadMore();

      expect(repo.listCalls, 1);
    });

    test('loadMore failure preserves entries with a retry path', () async {
      var calls = 0;
      final repo = _FakeTransactionRepository()
        ..onList = (filter) async {
          calls++;
          if (filter.page == 1) {
            return TransactionSuccess(
              _page([_transaction('tx-1')], hasMore: true),
            );
          }
          if (calls == 2) {
            return const TransactionError<TransactionPage>(ServerFailure());
          }
          return TransactionSuccess(
            _page([_transaction('tx-2')], page: 2),
          );
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();

      await cubit.loadMore();
      var state = cubit.state as TransactionListLoaded;
      expect(state.transactions.length, 1);
      expect(state.loadMoreError, isNotNull);

      await cubit.loadMore();
      state = cubit.state as TransactionListLoaded;
      expect(state.transactions.length, 2);
      expect(state.loadMoreError, isNull);
    });

    test('refresh replaces stale results', () async {
      var calls = 0;
      final repo = _FakeTransactionRepository()
        ..onList = (_) async {
          calls++;
          return calls == 1
              ? TransactionSuccess(_page([_transaction('old')]))
              : TransactionSuccess(_page([_transaction('new')]));
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();
      await cubit.refresh();

      final state = cubit.state as TransactionListLoaded;
      expect(
        state.transactions.map((t) => t.transactionId),
        ['new'],
      );
    });

    test('failed refresh keeps previously loaded entries', () async {
      var calls = 0;
      final repo = _FakeTransactionRepository()
        ..onList = (_) async {
          calls++;
          return calls == 1
              ? TransactionSuccess(_page([_transaction('tx-1')]))
              : const TransactionError<TransactionPage>(ConnectionFailure());
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();
      await cubit.refresh();

      final state = cubit.state as TransactionListLoaded;
      expect(state.transactions.length, 1);
      expect(state.loadMoreError, isNotNull);
    });

    test('filter changes reset pagination', () async {
      final pages = <int>[];
      String? seenStatus;
      final repo = _FakeTransactionRepository()
        ..onList = (filter) async {
          pages.add(filter.page);
          seenStatus = filter.status;
          return TransactionSuccess(_page([_transaction('tx-1')]));
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();

      await cubit.setStatusFilter('PAID');

      expect(pages, [1, 1]);
      expect(seenStatus, 'PAID');
      expect(cubit.filter.status, 'PAID');
    });

    test('search submission trims and reloads', () async {
      String? seenSearch;
      final repo = _FakeTransactionRepository()
        ..onList = (filter) async {
          seenSearch = filter.search;
          return TransactionSuccess(_page([_transaction('tx-1')]));
        };
      final cubit = _cubit(repo);

      await cubit.submitSearch('  ORDER-1  ');
      expect(seenSearch, 'ORDER-1');

      await cubit.submitSearch('   ');
      expect(cubit.filter.search, isNull);
    });

    test('clearing filters resets to the unfiltered first page', () async {
      final seen = <TransactionFilter>[];
      final repo = _FakeTransactionRepository()
        ..onList = (filter) async {
          seen.add(filter);
          return TransactionSuccess(_page([_transaction('tx-1')]));
        };
      final cubit = _cubit(repo);
      await cubit.setStatusFilter('PAID');
      await cubit.clearFilters();

      expect(seen.last.isEmpty, isTrue);
      expect(seen.last.page, 1);
      expect(cubit.filter.isEmpty, isTrue);
    });

    test('date range maps to a half-open UTC interval', () async {
      TransactionFilter? seen;
      final repo = _FakeTransactionRepository()
        ..onList = (filter) async {
          seen = filter;
          return TransactionSuccess(_page([_transaction('tx-1')]));
        };
      final cubit = _cubit(repo);

      await cubit.setDateRange(
        DateTime(2026, 1, 10, 15, 30),
        DateTime(2026, 1, 12, 8, 0),
      );

      expect(seen?.from, DateTime(2026, 1, 10));
      // Inclusive end day maps to the exclusive start of the next day.
      expect(seen?.to, DateTime(2026, 1, 13));
    });

    test('stale filter responses are ignored', () async {
      final gate = Completer<TransactionResult<TransactionPage>>();
      final repo = _FakeTransactionRepository()
        ..onList = (filter) {
          if (filter.status == 'PAID') return gate.future;
          return Future.value(
            TransactionSuccess(_page([_transaction('fresh')])),
          );
        };
      final cubit = _cubit(repo);
      await cubit.loadTransactions();

      final stale = cubit.setStatusFilter('PAID');
      await cubit.setStatusFilter(null);
      gate.complete(
        TransactionSuccess(_page([_transaction('stale')])),
      );
      await stale;

      final state = cubit.state as TransactionListLoaded;
      expect(
        state.transactions.map((t) => t.transactionId),
        ['fresh'],
      );
      expect(state.filter.status, isNull);
    });

    test('detail load still works', () async {
      final repo = _FakeTransactionRepository();
      repo.onList = (_) async =>
          TransactionSuccess(_page([_transaction('tx-1')]));
      repo.onGet = (id) async => TransactionSuccess(_transaction(id));
      final cubit = _cubit(repo);

      await cubit.loadTransactionById('tx-1');

      final state = cubit.state;
      expect(state, isA<TransactionDetailLoaded>());
      expect(
        (state as TransactionDetailLoaded).transaction.transactionId,
        'tx-1',
      );
    });
  });
}

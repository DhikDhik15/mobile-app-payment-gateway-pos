import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transaction_by_id.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';

/// Cubit that manages transaction state for the Transactions feature.
///
/// Handles filtered, paginated listing plus single-transaction detail:
///  * [loadTransactions]     — loads the first page of the current filter;
///  * [refresh]              — reloads the first page, keeping old results
///                             visible when the refresh fails;
///  * [loadMore]             — appends the next page, deduplicated;
///  * [setStatusFilter] / [setPaymentMethodFilter] / [submitSearch] /
///    [setDateRange] / [clearFilters] — change criteria, reset to page 1;
///  * [loadTransactionById]  — fetches a single transaction by ID.
///
/// Filter changes reset pagination and bump a fetch epoch, so a response
/// from an outdated query can never overwrite newer results. Concurrent
/// page requests collapse into one. Listing never creates payments.
///
/// States follow the same sealed-hierarchy convention as [PaymentCubit].
class TransactionCubit extends Cubit<TransactionState> {
  TransactionCubit({
    required this.getTransactions,
    required this.getTransactionById,
  }) : super(const TransactionInitial());

  final GetTransactionsUseCase getTransactions;
  final GetTransactionByIdUseCase getTransactionById;

  /// Criteria of the currently displayed list.
  TransactionFilter _filter = const TransactionFilter();

  /// Monotonic fetch epoch. Every new list fetch bumps it; completions from
  /// an older epoch (e.g. a page load overtaken by a filter change) are
  /// ignored so stale responses never corrupt the visible list.
  int _epoch = 0;

  /// Currently applied filter, for UI state.
  TransactionFilter get filter => _filter;

  /// Loads the first page of the current filter, replacing any content.
  Future<void> loadTransactions() async {
    final epoch = ++_epoch;
    emit(const TransactionLoading());
    final result = await getTransactions(_filter.copyWith(page: 1));
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case TransactionSuccess(value: final page):
        _filter = _filter.copyWith(page: page.page);
        emit(
          TransactionListLoaded(
            _deduplicated(const [], page.transactions),
            page: page.page,
            hasMore: page.hasMore,
            filter: _filter,
          ),
        );
      case TransactionError(failure: final failure):
        emit(TransactionFailure(failure.message));
    }
  }

  /// Reloads the first page of the current filter. A failed refresh keeps
  /// the previously loaded transactions visible with a recoverable error.
  Future<void> refresh() async {
    final current = state;
    if (current is! TransactionListLoaded) {
      return loadTransactions();
    }
    final epoch = ++_epoch;
    final result = await getTransactions(_filter.copyWith(page: 1));
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case TransactionSuccess(value: final page):
        _filter = _filter.copyWith(page: page.page);
        emit(
          TransactionListLoaded(
            _deduplicated(const [], page.transactions),
            page: page.page,
            hasMore: page.hasMore,
            filter: _filter,
          ),
        );
      case TransactionError():
        emit(
          current.copyWith(
            loadMoreError:
                'Could not refresh transactions. Showing previously loaded entries.',
          ),
        );
    }
  }

  /// Appends the next page of the current filter, deduplicated by ID.
  /// Concurrent calls collapse into one request; a failed page load keeps
  /// already loaded entries with a recoverable inline error.
  ///
  /// When [fromScroll] is true (scroll-position listener), a visible
  /// load-more error suppresses the request: footer layout shifts would
  /// otherwise retrigger it without user intent. Explicit retries (footer
  /// button) always proceed.
  Future<void> loadMore({bool fromScroll = false}) async {
    final current = state;
    if (current is! TransactionListLoaded) return;
    if (current.loadingMore || !current.hasMore) return;
    if (fromScroll && current.loadMoreError != null) return;
    final epoch = ++_epoch;
    emit(current.copyWith(loadingMore: true, loadMoreError: null));
    final result = await getTransactions(
      _filter.copyWith(page: current.page + 1),
    );
    if (isClosed || epoch != _epoch) return;
    switch (result) {
      case TransactionSuccess(value: final page):
        _filter = _filter.copyWith(page: page.page);
        emit(
          TransactionListLoaded(
            _deduplicated(current.transactions, page.transactions),
            page: page.page,
            hasMore: page.hasMore,
            filter: _filter,
          ),
        );
      case TransactionError():
        emit(
          current.copyWith(
            loadingMore: false,
            loadMoreError:
                'Could not load more transactions. Check your connection and retry.',
          ),
        );
    }
  }

  /// Sets the status filter (`CREATED`, `PENDING`, `PAID`, `FAILED`,
  /// `EXPIRED`, `CANCELLED`, or null for all) and reloads from page 1.
  Future<void> setStatusFilter(String? status) async {
    _filter = _filter.copyWith(status: () => status);
    await loadTransactions();
  }

  /// Sets the payment-method filter (`QRIS`, or null for all methods) and
  /// reloads from page 1.
  Future<void> setPaymentMethodFilter(String? paymentMethod) async {
    _filter = _filter.copyWith(paymentMethod: () => paymentMethod);
    await loadTransactions();
  }

  /// Submits a search query using backend search semantics (exact
  /// transaction UUID, or partial merchant-order / provider-transaction ID)
  /// and reloads from page 1. Blank queries clear the search. Call only on
  /// explicit submit, never per keystroke.
  Future<void> submitSearch(String? search) async {
    final trimmed = search?.trim();
    _filter = _filter.copyWith(
      search: () => (trimmed == null || trimmed.isEmpty) ? null : trimmed,
    );
    await loadTransactions();
  }

  /// Sets the creation-date range. [from] is the inclusive lower bound day
  /// and [to] the inclusive upper-bound day in the device timezone; they are
  /// sent as the half-open UTC interval [fromDay, toDay+1) exactly matching
  /// the backend `[created_from, created_to)` semantics. Either bound may be
  /// null to leave that side open. Reloads from page 1.
  Future<void> setDateRange(DateTime? fromDay, DateTime? toDay) async {
    DateTime startOfDay(DateTime day) =>
        DateTime(day.year, day.month, day.day);
    _filter = _filter.copyWith(
      from: () => fromDay == null ? null : startOfDay(fromDay),
      to: () =>
          toDay == null ? null : startOfDay(toDay).add(const Duration(days: 1)),
    );
    await loadTransactions();
  }

  /// Clears every filter criterion and reloads the unfiltered first page.
  Future<void> clearFilters() async {
    _filter = const TransactionFilter();
    await loadTransactions();
  }

  /// Loads a single transaction by its transaction UUID.
  Future<void> loadTransactionById(String transactionId) async {
    emit(const TransactionLoading());
    final result = await getTransactionById(
      GetTransactionByIdParams(transactionId: transactionId),
    );
    if (isClosed) return;
    switch (result) {
      case TransactionSuccess(value: final transaction):
        emit(TransactionDetailLoaded(transaction));
      case TransactionError(failure: final failure):
        emit(TransactionFailure(failure.message));
    }
  }

  static List<Transaction> _deduplicated(
    List<Transaction> existing,
    List<Transaction> incoming,
  ) {
    final ids = {for (final tx in existing) tx.transactionId};
    return [
      ...existing,
      for (final tx in incoming)
        if (ids.add(tx.transactionId)) tx,
    ];
  }
}

/// Sealed transaction state hierarchy.
sealed class TransactionState {
  const TransactionState();
}

/// Initial state — no operation has been attempted yet.
final class TransactionInitial extends TransactionState {
  const TransactionInitial();
}

/// A list or detail request is in flight.
final class TransactionLoading extends TransactionState {
  const TransactionLoading();
}

/// The transaction list for [filter]. [loadingMore] marks an in-flight next
/// page; [loadMoreError] carries a recoverable page/refresh failure while
/// the retained [transactions] stay visible.
final class TransactionListLoaded extends TransactionState {
  const TransactionListLoaded(
    this.transactions, {
    this.page = 1,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
    this.filter = const TransactionFilter(),
  });

  final List<Transaction> transactions;
  final int page;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
  final TransactionFilter filter;

  TransactionListLoaded copyWith({
    List<Transaction>? transactions,
    int? page,
    bool? hasMore,
    bool? loadingMore,
    String? loadMoreError,
    TransactionFilter? filter,
  }) {
    return TransactionListLoaded(
      transactions ?? this.transactions,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: loadMoreError,
      filter: filter ?? this.filter,
    );
  }
}

/// A single transaction has been loaded successfully.
final class TransactionDetailLoaded extends TransactionState {
  const TransactionDetailLoaded(this.transaction);

  final Transaction transaction;
}

/// The last operation failed with a user-safe message.
final class TransactionFailure extends TransactionState {
  const TransactionFailure(this.message);

  final String message;
}

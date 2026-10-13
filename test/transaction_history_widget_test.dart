import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';
import 'package:payment_simulator/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:payment_simulator/features/orders/domain/usecases/list_orders.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transaction_by_id.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';
import 'package:payment_simulator/features/transactions/presentation/pages/transaction_page.dart';

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

class _FakeOrderRepository implements OrderRepository {
  Future<OrderResult<Order>> Function(String)? onGetOrder;
  int createCalls = 0;

  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async {
    createCalls++;
    return OrderError(const ServerFailure());
  }

  @override
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  }) async =>
      OrderError(const ServerFailure());

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async =>
      onGetOrder!(orderId);
}

class _FakePaymentRepository implements PaymentRepository {
  int createOrderPaymentCalls = 0;

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async =>
      PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    createOrderPaymentCalls++;
    return PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async => const PaymentSuccess(<Payment>[]);
}

Transaction _transaction(String id, {String? orderId}) => Transaction(
  transactionId: id,
  orderId: orderId,
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

Order _order(String id) => Order(
  id: id,
  status: 'CREATED',
  currency: 'IDR',
  subtotal: 20000,
  totalAmount: 20000,
  createdAt: DateTime.parse('2026-10-07T08:00:00Z'),
  updatedAt: DateTime.parse('2026-10-07T08:00:00Z'),
  items: const [
    OrderItem(
      id: 'item-1',
      productId: 'p1',
      productName: 'Coffee',
      quantity: 2,
      unitPrice: 10000,
      subtotal: 20000,
    ),
  ],
);

TransactionCubit _transactionCubit(_FakeTransactionRepository repo) =>
    TransactionCubit(
      getTransactions: GetTransactionsUseCase(repo),
      getTransactionById: GetTransactionByIdUseCase(repo),
    );

Widget _transactionsApp({
  required TransactionCubit transactionCubit,
  required OrderHistoryCubit orderHistoryCubit,
  required PaymentCubit paymentCubit,
}) {
  // Providers sit above MaterialApp, mirroring production (main.dart), so
  // pushed routes such as TransactionDetailPage resolve shared cubits.
  return MultiBlocProvider(
    providers: [
      BlocProvider.value(value: paymentCubit),
      BlocProvider.value(value: transactionCubit),
      BlocProvider.value(value: orderHistoryCubit),
    ],
    child: const MaterialApp(home: TransactionsPage()),
  );
}

OrderHistoryCubit _orderHistoryCubit(_FakeOrderRepository repo) =>
    OrderHistoryCubit(
      listOrdersUseCase: ListOrdersUseCase(repo),
      getOrderByIdUseCase: GetOrderByIdUseCase(repo),
    );

PaymentCubit _paymentCubit(_FakePaymentRepository repo) => PaymentCubit(
  listPayments: ListPaymentsUseCase(repo),
  getPayment: GetPaymentUseCase(repo),
  createPayment: CreatePaymentUseCase(repo),
  simulateSuccess: SimulatePaymentSuccessUseCase(repo),
  simulateFail: SimulatePaymentFailUseCase(repo),
);

Future<void> _selectDropdownOption(
  WidgetTester tester,
  Key wrapKey,
  String option,
) async {
  final field = find.descendant(
    of: find.byKey(wrapKey),
    matching: find.byType(DropdownButtonFormField<String?>),
  );
  await tester.tap(field);
  await tester.pumpAndSettle();
  // The menu renders above the page; pick the option inside the menu.
  final menuOption = find
      .descendant(
        of: find.byType(ListView),
        matching: find.text(option).last,
      );
  await tester.tap(menuOption);
  await tester.pumpAndSettle();
}

void main() {

/// Drags a scrollable until [finder] matches or attempts run out.
/// Lazy list items far outside the viewport are never built, so single-shot
/// scroll helpers cannot target them. A negative [dy] reveals the bottom of
/// the list; a positive [dy] scrolls back toward the top.
Future<void> dragUntilVisible(
  WidgetTester tester,
  Finder scrollable,
  Finder finder, {
  double dy = -600,
}) async {
  for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, Offset(0, dy));
    await tester.pumpAndSettle();
  }
}

Future<void> dragUpUntilVisible(
  WidgetTester tester,
  Finder scrollable,
  Finder finder,
) =>
    dragUntilVisible(tester, scrollable, finder, dy: -600);

  group('TransactionsPage', () {
    testWidgets('loads the unfiltered first page', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async => TransactionSuccess(
        _page([_transaction('tx-1'), _transaction('tx-2')]),
      );
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transactions'), findsOneWidget);
      expect(find.text('merchant-tx-1'), findsOneWidget);
      expect(find.text('merchant-tx-2'), findsOneWidget);
      expect(txRepo.lastFilter?.isEmpty, isTrue);
    });

    testWidgets('empty result shows the empty state', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async => TransactionSuccess(_page(const []));
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No transactions yet'), findsOneWidget);
    });

    testWidgets('filtered empty result explains filters', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async => TransactionSuccess(_page(const []));
      final cubit = _transactionCubit(txRepo);
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: cubit,
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await _selectDropdownOption(
        tester,
        const Key('transaction-status-filter'),
        'PAID',
      );

      expect(find.text('No matching transactions'), findsOneWidget);
      expect(txRepo.lastFilter?.status, 'PAID');
    });

    testWidgets('initial failure shows retry and recovers', (tester) async {
      var calls = 0;
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async {
        calls++;
        return calls == 1
            ? const TransactionError<TransactionPage>(ServerFailure())
            : TransactionSuccess(_page([_transaction('tx-1')]));
      };
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('merchant-tx-1'), findsOneWidget);
      expect(calls, 2);
    });

    testWidgets('status and method filters reload from page one', (
      tester,
    ) async {
      final seen = <TransactionFilter>[];
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (filter) async {
        seen.add(filter);
        return TransactionSuccess(_page([_transaction('tx-1')]));
      };
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await _selectDropdownOption(
        tester,
        const Key('transaction-status-filter'),
        'FAILED',
      );
      expect(seen.last.status, 'FAILED');
      expect(seen.last.page, 1);

      await _selectDropdownOption(
        tester,
        const Key('transaction-method-filter'),
        'QRIS',
      );
      expect(seen.last.paymentMethod, 'QRIS');
      expect(seen.last.page, 1);
    });

    testWidgets('search keyboard action submits explicitly', (tester) async {
      final seen = <TransactionFilter>[];
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (filter) async {
        seen.add(filter);
        return TransactionSuccess(_page([_transaction('tx-1')]));
      };
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();
      final callsAfterLoad = txRepo.listCalls;

      await tester.enterText(
        find.byKey(const Key('transaction-search-field')),
        'PROV-9',
      );
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(txRepo.listCalls, callsAfterLoad + 1);
      expect(seen.last.search, 'PROV-9');
      expect(seen.last.page, 1);
    });

    testWidgets('search submits explicitly and clears', (tester) async {
      final seen = <TransactionFilter>[];
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (filter) async {
        seen.add(filter);
        return TransactionSuccess(_page([_transaction('tx-1')]));
      };
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();
      final callsAfterLoad = txRepo.listCalls;

      // Typing alone issues no request.
      await tester.enterText(
        find.byKey(const Key('transaction-search-field')),
        'ORDER-1',
      );
      await tester.pump();
      expect(txRepo.listCalls, callsAfterLoad);

      // Explicit submit issues exactly one request with trimmed text.
      await tester.tap(find.byKey(const Key('transaction-search-submit')));
      await tester.pumpAndSettle();
      expect(txRepo.listCalls, callsAfterLoad + 1);
      expect(seen.last.search, 'ORDER-1');

      // Clearing filters resets to the unfiltered first page.
      await tester.tap(find.byKey(const Key('transaction-clear-filters')));
      await tester.pumpAndSettle();
      expect(seen.last.isEmpty, isTrue);
      expect(seen.last.page, 1);
    });

    testWidgets('scrolling appends the next page once', (tester) async {
      List<Transaction> seed(String tag) => [
        for (var i = 0; i < 10; i++) _transaction('$tag-tx-$i'),
      ];
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (filter) async => filter.page == 1
          ? TransactionSuccess(_page(seed('p1'), hasMore: true))
          : TransactionSuccess(_page(seed('p2'), page: filter.page));
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('merchant-p1-tx-0'), findsOneWidget);

      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await dragUpUntilVisible(
        tester,
        find.byType(ListView).first,
        find.text('merchant-p2-tx-9'),
      );

      // Appended page is visible with the end-of-list footer; the scrolled
      // away first page is verified at cubit level (dedupe test) since
      // lazy tiles outside the cache extent leave the tree.
      expect(find.text('merchant-p2-tx-9'), findsOneWidget);
      expect(find.text('No more transactions'), findsOneWidget);
      expect(txRepo.listCalls, 2);

      // Scrolling back restores the first page from retained state.
      await tester.drag(find.byType(ListView).first, const Offset(0, 3000));
      await tester.pumpAndSettle();
      expect(find.textContaining('merchant-p1-tx-0'), findsOneWidget);
    });

    testWidgets('load-more failure preserves entries with retry', (
      tester,
    ) async {
      var calls = 0;
      List<Transaction> seed(String tag) => [
        for (var i = 0; i < 10; i++) _transaction('$tag-tx-$i'),
      ];
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (filter) async {
        calls++;
        if (filter.page == 1) {
          return TransactionSuccess(_page(seed('p1'), hasMore: true));
        }
        if (calls == 2) {
          return const TransactionError<TransactionPage>(ServerFailure());
        }
        return TransactionSuccess(_page(seed('p2'), page: filter.page));
      };
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).first, const Offset(0, -3000));
      await tester.pumpAndSettle();

      // Recoverable inline error with entries retained (verified below by
      // scrolling back; destroyed lazy tiles leave the tree).
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await dragUpUntilVisible(
        tester,
        find.byType(ListView).first,
        find.text('merchant-p2-tx-9'),
      );
      expect(find.text('merchant-p2-tx-9'), findsOneWidget);

      await dragUntilVisible(
        tester,
        find.byType(ListView).first,
        find.text('merchant-p1-tx-0'),
        dy: 600,
      );
      expect(find.text('merchant-p1-tx-0'), findsOneWidget);
    });

    testWidgets('list rows show the associated order id', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async => TransactionSuccess(
        _page([
          _transaction('tx-1', orderId: '12345678-order-id'),
          _transaction('tx-2'),
        ]),
      );
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Order 12345678'), findsOneWidget);
    });

    testWidgets('detail navigates to the associated order', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async => TransactionSuccess(
        _page([_transaction('tx-1', orderId: 'order-1')]),
      );
      txRepo.onGet = (id) async =>
          TransactionSuccess(_transaction(id, orderId: 'order-1'));
      final orderRepo = _FakeOrderRepository();
      orderRepo.onGetOrder = (id) async => OrderSuccess(_order(id));
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(orderRepo),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('merchant-tx-1'));
      await tester.pumpAndSettle();
      expect(find.text('Transaction Detail'), findsOneWidget);
      expect(find.text('Order ID'), findsOneWidget);
      expect(find.text('order-1'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('transaction-view-order')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('transaction-view-order')));
      await tester.pumpAndSettle();

      // The existing order is reloaded and reviewed — never recreated.
      expect(find.text('Order Details'), findsOneWidget);
      expect(orderRepo.createCalls, 0);
    });

    testWidgets('detail without order hides order navigation', (
      tester,
    ) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async => TransactionSuccess(_page([_transaction('tx-1')]));
      txRepo.onGet = (id) async => TransactionSuccess(_transaction(id));
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('merchant-tx-1'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction Detail'), findsOneWidget);
      expect(find.byKey(const Key('transaction-view-order')), findsNothing);
    });

    testWidgets('browsing never creates a payment', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async => TransactionSuccess(
        _page([_transaction('tx-1', orderId: 'order-1')]),
      );
      txRepo.onGet = (id) async =>
          TransactionSuccess(_transaction(id, orderId: 'order-1'));
      final paymentRepo = _FakePaymentRepository();
      final orderRepo = _FakeOrderRepository();
      orderRepo.onGetOrder = (id) async => OrderSuccess(_order(id));
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(orderRepo),
          paymentCubit: _paymentCubit(paymentRepo),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('merchant-tx-1'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('transaction-view-order')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('transaction-view-order')));
      await tester.pumpAndSettle();

      expect(find.text('Order Details'), findsOneWidget);
      expect(paymentRepo.createOrderPaymentCalls, 0);
      expect(orderRepo.createCalls, 0);
    });

    testWidgets('date button opens the range picker', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async =>
          TransactionSuccess(_page([_transaction('tx-1')]));
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('transaction-date-filter')));
      await tester.pumpAndSettle();

      // The platform date-range dialog opens; dismissing it issues nothing.
      expect(find.byType(DateRangePickerDialog), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(find.byType(DateRangePickerDialog), findsNothing);
      expect(txRepo.listCalls, 1);
    });

    testWidgets('clearing filters resets dropdown display', (tester) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async =>
          TransactionSuccess(_page([_transaction('tx-1')]));
      await tester.pumpWidget(
        _transactionsApp(
          transactionCubit: _transactionCubit(txRepo),
          orderHistoryCubit: _orderHistoryCubit(_FakeOrderRepository()),
          paymentCubit: _paymentCubit(_FakePaymentRepository()),
        ),
      );
      await tester.pumpAndSettle();

      await _selectDropdownOption(
        tester,
        const Key('transaction-status-filter'),
        'PAID',
      );
      // The selected value is displayed.
      expect(find.text('PAID'), findsWidgets);

      await tester.tap(find.byKey(const Key('transaction-clear-filters')));
      await tester.pumpAndSettle();

      // The dropdown resets to All instead of showing a stale selection.
      expect(find.text('PAID'), findsNothing);
    });
  });
}

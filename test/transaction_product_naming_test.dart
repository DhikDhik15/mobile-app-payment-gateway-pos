import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
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
import 'package:payment_simulator/features/transactions/data/models/transaction_model.dart';
import 'package:payment_simulator/features/transactions/domain/entities/order_summary.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transaction_by_id.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';
import 'package:payment_simulator/features/transactions/presentation/pages/transaction_page.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_display.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

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
  ) async => onGet!(transactionId);
}

class _FakeOrderRepository implements OrderRepository {
  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async => OrderError(const ServerFailure());

  @override
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  }) async => OrderError(const ServerFailure());

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async =>
      OrderError(const ServerFailure());
}

class _FakePaymentRepository implements PaymentRepository {
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
  }) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async => const PaymentSuccess(<Payment>[]);
}

Transaction _transaction(
  String id, {
  String merchantOrderId = 'ORD-20261012-001',
  String? orderId,
  OrderSummary? summary,
}) => Transaction(
  transactionId: id,
  orderId: orderId,
  orderSummary: summary,
  merchantOrderId: merchantOrderId,
  amount: 300000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: TransactionStatus.pending,
  createdAt: DateTime.parse('2026-10-12T10:00:00Z'),
  updatedAt: DateTime.parse('2026-10-12T10:00:00Z'),
);

const _oneProduct = OrderSummary(
  productNames: ['Mechanical Keyboard'],
  productCount: 1,
);
const _twoProducts = OrderSummary(
  productNames: ['Mechanical Keyboard', 'Mouse'],
  productCount: 2,
);
const _threeProducts = OrderSummary(
  productNames: ['Mechanical Keyboard', 'Mouse'],
  productCount: 3,
);

TransactionPage _page(List<Transaction> txs) => TransactionPage(
  transactions: txs,
  page: 1,
  limit: 20,
  total: txs.length,
  totalPages: 1,
);

Widget _app(TransactionCubit txCubit) => MultiBlocProvider(
  providers: [
    BlocProvider.value(
      value: PaymentCubit(
        listPayments: ListPaymentsUseCase(_FakePaymentRepository()),
        getPayment: GetPaymentUseCase(_FakePaymentRepository()),
        createPayment: CreatePaymentUseCase(_FakePaymentRepository()),
        simulateSuccess: SimulatePaymentSuccessUseCase(_FakePaymentRepository()),
        simulateFail: SimulatePaymentFailUseCase(_FakePaymentRepository()),
      ),
    ),
    BlocProvider.value(value: txCubit),
    BlocProvider.value(
      value: OrderHistoryCubit(
        listOrdersUseCase: ListOrdersUseCase(_FakeOrderRepository()),
        getOrderByIdUseCase: GetOrderByIdUseCase(_FakeOrderRepository()),
      ),
    ),
  ],
  child: const MaterialApp(home: TransactionsPage()),
);

TransactionCubit _cubit(_FakeTransactionRepository repo) => TransactionCubit(
  getTransactions: GetTransactionsUseCase(repo),
  getTransactionById: GetTransactionByIdUseCase(repo),
);

void main() {
  group('productSummaryTitle', () {
    test('one product shows its name', () {
      expect(productSummaryTitle(_oneProduct), 'Mechanical Keyboard');
    });

    test('two products show both names', () {
      expect(
        productSummaryTitle(_twoProducts),
        'Mechanical Keyboard + Mouse',
      );
    });

    test('more than two products show a concise summary', () {
      expect(
        productSummaryTitle(_threeProducts),
        'Mechanical Keyboard + 2 others',
      );
    });

    test('null summary yields no title (fallback applies)', () {
      expect(productSummaryTitle(null), isNull);
    });

    test('blank names are skipped without fabrication', () {
      expect(
        productSummaryTitle(
          const OrderSummary(productNames: ['  ', 'Mouse'], productCount: 2),
        ),
        'Mouse',
      );
      expect(
        productSummaryTitle(
          const OrderSummary(productNames: ['  ', ''], productCount: 2),
        ),
        isNull,
      );
      expect(
        productSummaryTitle(
          const OrderSummary(productNames: [], productCount: 0),
        ),
        isNull,
      );
    });
  });

  group('transactionDisplayName with summaries', () {
    test('product title wins over the merchant order ID', () {
      expect(
        transactionDisplayName(
          _transaction('tx-1', orderId: 'order-1', summary: _oneProduct),
        ),
        'Mechanical Keyboard',
      );
    });

    test('missing summary preserves the merchant fallback', () {
      expect(
        transactionDisplayName(_transaction('tx-1', orderId: 'order-1')),
        'ORD-20261012-001',
      );
    });

    test('non-product transaction keeps existing naming', () {
      final tx = _transaction('tx-1');
      expect(transactionDisplayName(tx), 'ORD-20261012-001');
      expect(
        transactionReferenceLine(tx),
        isNull,
      );
      final linked = _transaction('tx-2', orderId: '1234567890abcdef');
      expect(transactionDisplayName(linked), 'ORD-20261012-001');
      expect(
        transactionReferenceLine(linked),
        contains('12345678'),
      );
    });

    test('product rows keep the merchant ID as secondary reference', () {
      expect(
        transactionReferenceLine(
          _transaction('tx-1', orderId: 'order-1', summary: _oneProduct),
        ),
        'ORD-20261012-001',
      );
    });
  });

  group('TransactionModel order_summary parsing', () {
    test('parses product names verbatim (snapshot, no catalog lookup)', () {
      final model = TransactionModel.fromJson({
        'transaction_id': 'tx-1',
        'order_id': 'order-1',
        'order_summary': {
          'product_names': ['Mechanical Keyboard', 'Mouse'],
          'product_count': 2,
        },
        'merchant_order_id': 'ORD-20261012-001',
        'amount': 300000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'status': 'PENDING',
        'created_at': '2026-10-12T10:00:00Z',
        'updated_at': '2026-10-12T10:00:00Z',
      });

      expect(model.orderSummary?.productNames, [
        'Mechanical Keyboard',
        'Mouse',
      ]);
      expect(model.orderSummary?.productCount, 2);
      expect(transactionDisplayName(model), 'Mechanical Keyboard + Mouse');
      expect(
        (model.toJson()['order_summary'] as Map)['product_count'],
        2,
      );
    });

    test('absent summary stays backward compatible', () {
      final model = TransactionModel.fromJson({
        'transaction_id': 'tx-1',
        'merchant_order_id': 'ORD-20261012-001',
        'amount': 300000,
        'currency': 'IDR',
        'payment_method': 'QRIS',
        'status': 'PENDING',
        'created_at': '2026-10-12T10:00:00Z',
        'updated_at': '2026-10-12T10:00:00Z',
      });

      expect(model.orderSummary, isNull);
      expect(transactionDisplayName(model), 'ORD-20261012-001');
    });
  });

  group('Transaction history product naming (widget)', () {
    testWidgets('list shows product names with merchant reference', (
      tester,
    ) async {
      final repo = _FakeTransactionRepository();
      repo.onList = (_) async => TransactionSuccess(
        _page([
          _transaction('tx-1', orderId: 'order-1', summary: _oneProduct),
          _transaction(
            'tx-2',
            merchantOrderId: 'ORD-20261012-002',
            orderId: 'order-2',
            summary: _threeProducts,
          ),
          _transaction('tx-3', merchantOrderId: 'ORD-20261012-003'),
        ]),
      );
      await tester.pumpWidget(_app(_cubit(repo)));
      await tester.pumpAndSettle();

      // Product titles are primary…
      expect(find.text('Mechanical Keyboard'), findsOneWidget);
      expect(
        find.text('Mechanical Keyboard + 2 others'),
        findsOneWidget,
      );
      // …merchant IDs retained as secondary info, legacy rows unchanged.
      expect(find.textContaining('ORD-20261012-001'), findsOneWidget);
      expect(find.textContaining('ORD-20261012-002'), findsOneWidget);
      expect(find.text('ORD-20261012-003'), findsOneWidget);
    });

    testWidgets('long product names ellipsize without overflow', (
      tester,
    ) async {
      final longName = 'Mechanical Keyboard RGB Hot-Swap ${'X' * 100}';
      final repo = _FakeTransactionRepository();
      repo.onList = (_) async => TransactionSuccess(
        _page([
          _transaction(
            'tx-1',
            orderId: 'order-1',
            summary: OrderSummary(
              productNames: [longName],
              productCount: 1,
            ),
          ),
        ]),
      );
      await tester.pumpWidget(_app(_cubit(repo)));
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(find.text(longName));
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    });

    testWidgets('detail header shows the product name with merchant row', (
      tester,
    ) async {
      final repo = _FakeTransactionRepository();
      final tx = _transaction('tx-1', orderId: 'order-1', summary: _oneProduct);
      repo.onList = (_) async => TransactionSuccess(_page([tx]));
      repo.onGet = (_) async => TransactionSuccess(tx);
      await tester.pumpWidget(_app(_cubit(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mechanical Keyboard'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction Detail'), findsOneWidget);
      // Header consistent with the list title…
      expect(find.text('Mechanical Keyboard'), findsOneWidget);
      // …merchant reference retained as secondary information…
      expect(find.text('Merchant Order ID'), findsOneWidget);
      expect(find.text('ORD-20261012-001'), findsOneWidget);
      // …and order navigation is intact.
      expect(find.byKey(const Key('transaction-view-order')), findsOneWidget);
    });

    testWidgets('legacy detail shows no duplicate merchant row', (
      tester,
    ) async {
      final repo = _FakeTransactionRepository();
      final tx = _transaction('tx-9');
      repo.onList = (_) async => TransactionSuccess(_page([tx]));
      repo.onGet = (_) async => TransactionSuccess(tx);
      await tester.pumpWidget(_app(_cubit(repo)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('ORD-20261012-001'));
      await tester.pumpAndSettle();

      expect(find.text('Transaction Detail'), findsOneWidget);
      expect(find.text('ORD-20261012-001'), findsOneWidget);
      expect(find.text('Merchant Order ID'), findsNothing);
    });

    testWidgets('filters, refresh, and pagination behavior unaffected', (
      tester,
    ) async {
      final seen = <TransactionFilter>[];
      final repo = _FakeTransactionRepository();
      repo.onList = (filter) async {
        seen.add(filter);
        return TransactionSuccess(
          _page([
            _transaction('tx-1', orderId: 'order-1', summary: _oneProduct),
          ]),
        );
      };
      final cubit = _cubit(repo);
      await tester.pumpWidget(_app(cubit));
      await tester.pumpAndSettle();
      expect(find.text('Mechanical Keyboard'), findsOneWidget);
      final callsAfterLoad = repo.listCalls;

      // Pull-to-refresh reloads page one with the active filter intact.
      await tester.fling(
        find.byType(RefreshIndicator).first,
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();
      expect(repo.listCalls, callsAfterLoad + 1);
      expect(repo.lastFilter?.page, 1);
      expect(find.text('Mechanical Keyboard'), findsOneWidget);

      // Status filter still resets to page one and keeps naming.
      await cubit.setStatusFilter('PAID');
      await tester.pumpAndSettle();
      expect(seen.last.status, 'PAID');
      expect(seen.last.page, 1);
      expect(find.text('Mechanical Keyboard'), findsOneWidget);
    });
  });
}

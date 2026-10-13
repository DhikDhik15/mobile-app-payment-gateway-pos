import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/home/domain/entities/dashboard_overview.dart';
import 'package:payment_simulator/features/home/domain/repositories/dashboard_overview_repository.dart';
import 'package:payment_simulator/features/home/domain/usecases/get_dashboard_overview.dart';
import 'package:payment_simulator/features/home/presentation/bloc/pos_home_cubit.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_item.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';
import 'package:payment_simulator/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:payment_simulator/features/orders/domain/usecases/list_orders.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/pages/order_confirmation_page.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payment_detail_page.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payments_page.dart';
import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/products/presentation/pages/product_detail_page.dart';
import 'package:payment_simulator/features/products/presentation/pages/products_page.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transaction_by_id.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';
import 'package:payment_simulator/features/transactions/presentation/pages/transaction_page.dart';

// ─── Fakes ───────────────────────────────────────────────────────────────────

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({required this.categories, required this.products});

  final List<Category> categories;
  final List<Product> products;
  final List<Map<String, dynamic>> productCalls = [];
  int categoryCalls = 0;
  int getProductCalls = 0;
  bool failProducts = false;

  @override
  Future<List<Category>> listCategories() async {
    categoryCalls++;
    return categories;
  }

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    productCalls.add({'categoryId': categoryId, 'page': page});
    if (failProducts) throw const ConnectionFailure();
    final filtered = categoryId == null
        ? products
        : products.where((p) => p.categoryId == categoryId).toList();
    return ProductPage(
      products: filtered,
      page: 1,
      limit: limit,
      total: filtered.length,
      totalPages: 1,
    );
  }

  @override
  Future<Product> getProduct(String productId) async {
    getProductCalls++;
    return products.firstWhere((p) => p.id == productId);
  }
}

Product _product(String id, {String categoryId = 'c1'}) => Product(
  id: id,
  categoryId: categoryId,
  name: 'Product $id',
  sku: 'SKU-$id',
  description: 'Description $id',
  price: 12000,
  currency: 'IDR',
  active: true,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

Category _category(String id, String name) => Category(
  id: id,
  name: name,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

class _FakePaymentRepository implements PaymentRepository {
  Future<PaymentResult<List<Payment>>> Function()? onList;
  Future<PaymentResult<Payment>> Function(String)? onGet;
  int listCalls = 0;
  int getCalls = 0;
  int createOrderPaymentCalls = 0;
  int simulateCalls = 0;

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async => PaymentError(const ServerFailure());

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async {
    getCalls++;
    return onGet!(paymentId);
  }

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async {
    listCalls++;
    return onList!();
  }

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async {
    simulateCalls++;
    return PaymentError(const ServerFailure());
  }

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async {
    simulateCalls++;
    return PaymentError(const ServerFailure());
  }

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

PaymentCubit _paymentCubit(_FakePaymentRepository repo) => PaymentCubit(
  listPayments: ListPaymentsUseCase(repo),
  getPayment: GetPaymentUseCase(repo),
  createPayment: CreatePaymentUseCase(repo),
  simulateSuccess: SimulatePaymentSuccessUseCase(repo),
  simulateFail: SimulatePaymentFailUseCase(repo),
);

class _FakeTransactionRepository implements TransactionRepository {
  Future<TransactionResult<TransactionPage>> Function(TransactionFilter)?
  onList;
  Future<TransactionResult<Transaction>> Function(String)? onGet;
  int listCalls = 0;
  int getCalls = 0;
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
  ) async {
    getCalls++;
    return onGet!(transactionId);
  }
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

TransactionPage _txPage(List<Transaction> txs) => TransactionPage(
  transactions: txs,
  page: 1,
  limit: 20,
  total: txs.length,
  totalPages: 1,
);

class _FakeOrderRepository implements OrderRepository {
  Future<OrderResult<OrderPage>> Function(int page, int limit)? onList;
  Future<OrderResult<Order>> Function(String orderId)? onGet;
  int createCalls = 0;
  int getCalls = 0;

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
  }) async => onList!(page, limit);

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async {
    getCalls++;
    return onGet!(orderId);
  }
}

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

/// Pulls down on the first [RefreshIndicator] found, mirroring the existing
/// order-history refresh test convention.
Future<void> _pullToRefresh(WidgetTester tester) async {
  await tester.fling(
    find.byType(RefreshIndicator).first,
    const Offset(0, 300),
    1000,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('PosHomeCubit refresh guard', () {
    test('concurrent loadToday calls collapse into one request', () async {
      final gate = Completer<DashboardOverviewResult<DashboardOverview>>();
      final repo = _GatedOverviewRepository(gate.future);
      final cubit = PosHomeCubit(
        getOverview: GetDashboardOverviewUseCase(repo),
      );
      addTearDown(cubit.close);

      final first = cubit.loadToday();
      final second = cubit.loadToday();
      await Future<void>.delayed(Duration.zero);
      expect(repo.calls, 1);
      gate.complete(
        const DashboardOverviewSuccess(
          DashboardOverview(
            revenueAmount: 1,
            currency: 'IDR',
            paidCount: 0,
            pendingCount: 0,
            failedCount: 0,
            recentTransactions: [],
          ),
        ),
      );
      await Future.wait([first, second]);
      expect(cubit.state, isA<PosHomeLoaded>());
    });
  });

  group('ProductsPage pull-to-refresh', () {
    testWidgets('refresh preserves the selected category filter', (
      tester,
    ) async {
      final repo = _FakeProductRepository(
        categories: [_category('c1', 'Drinks'), _category('c2', 'Food')],
        products: [
          _product('p1', categoryId: 'c1'),
          _product('p2', categoryId: 'c2'),
        ],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: CartCubit(),
            child: Builder(
              builder: (context) => ProductsPage(
                listCategories: ListCategoriesUseCase(repo),
                listProducts: ListProductsUseCase(repo),
                getProduct: GetProductUseCase(repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Default selection is the first category.
      expect(find.text('Product p1'), findsOneWidget);

      // Switch to the second category, then pull to refresh.
      await tester.tap(find.text('Food'));
      await tester.pumpAndSettle();
      expect(find.text('Product p2'), findsOneWidget);
      final callsBefore = repo.productCalls.length;

      await _pullToRefresh(tester);

      expect(find.text('Product p2'), findsOneWidget);
      expect(find.text('Product p1'), findsNothing);
      expect(repo.productCalls.length, callsBefore + 1);
      expect(repo.productCalls.last['categoryId'], 'c2');
      expect(repo.productCalls.last['page'], 1);
    });

    testWidgets('empty list can still be refreshed', (tester) async {
      final repo = _FakeProductRepository(
        categories: [_category('c1', 'Drinks')],
        products: const [],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: CartCubit(),
            child: Builder(
              builder: (context) => ProductsPage(
                listCategories: ListCategoriesUseCase(repo),
                listProducts: ListProductsUseCase(repo),
                getProduct: GetProductUseCase(repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No products match this category yet.'), findsOneWidget);

      final callsBefore = repo.productCalls.length;
      await _pullToRefresh(tester);

      expect(repo.productCalls.length, callsBefore + 1);
      expect(find.text('No products match this category yet.'), findsOneWidget);
    });

    testWidgets('failed refresh surfaces the error state without crashing', (
      tester,
    ) async {
      final repo = _FakeProductRepository(
        categories: [_category('c1', 'Drinks')],
        products: [_product('p1')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: CartCubit(),
            child: Builder(
              builder: (context) => ProductsPage(
                listCategories: ListCategoriesUseCase(repo),
                listProducts: ListProductsUseCase(repo),
                getProduct: GetProductUseCase(repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Product p1'), findsOneWidget);

      repo.failProducts = true;
      await _pullToRefresh(tester);

      // Consistent error feedback via the existing retry affordance.
      expect(find.text('Retry'), findsOneWidget);
    });
  });

  group('ProductDetailPage pull-to-refresh', () {
    testWidgets('refresh re-reads the same product and keeps quantity', (
      tester,
    ) async {
      final repo = _FakeProductRepository(
        categories: const [],
        products: [_product('p1')],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: CartCubit(),
            child: Builder(
              builder: (context) => ProductDetailPage(
                productId: 'p1',
                getProduct: GetProductUseCase(repo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Product p1'), findsOneWidget);

      // Bump the quantity stepper, then pull to refresh.
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add).last);
      await tester.pump();
      expect(find.text('3'), findsOneWidget);

      await _pullToRefresh(tester);

      expect(repo.getProductCalls, 2);
      expect(find.text('Product p1'), findsOneWidget);
      // Unsaved stepper input is preserved across the refresh.
      expect(find.text('3'), findsOneWidget);
    });
  });

  group('PaymentsPage pull-to-refresh', () {
    testWidgets('empty list can still be refreshed', (tester) async {
      final repo = _FakePaymentRepository();
      repo.onList = () async => const PaymentSuccess(<Payment>[]);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: _paymentCubit(repo),
            child: const PaymentsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('No payments yet'), findsOneWidget);

      await _pullToRefresh(tester);

      expect(repo.listCalls, 2);
      expect(find.text('No payments yet'), findsOneWidget);
      expect(repo.createOrderPaymentCalls, 0);
    });
  });

  group('PaymentDetailPage pull-to-refresh', () {
    testWidgets('pull gesture reloads by id without simulating', (
      tester,
    ) async {
      Payment payment() => Payment(
        transactionId: 'tx-001',
        merchantOrderId: 'ORDER-001',
        amount: 150000,
        currency: 'IDR',
        paymentMethod: 'QRIS',
        status: PaymentStatus.pending,
        createdAt: DateTime.parse('2026-01-01T10:00:00Z'),
        updatedAt: DateTime.parse('2026-01-01T10:00:00Z'),
      );
      final repo = _FakePaymentRepository();
      repo.onGet = (_) async => PaymentSuccess(payment());
      final cubit = _paymentCubit(repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: cubit,
            child: const PaymentDetailPage(
              paymentId: 'tx-001',
              showSimulator: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('tx-001'), findsOneWidget);
      final callsBefore = repo.getCalls;

      await _pullToRefresh(tester);

      expect(repo.getCalls, callsBefore + 1);
      expect(find.text('tx-001'), findsOneWidget);
      expect(repo.simulateCalls, 0);
      expect(repo.createOrderPaymentCalls, 0);
    });
  });

  group('Transaction detail pull-to-refresh', () {
    testWidgets('refresh reloads by id and keeps order navigation', (
      tester,
    ) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async =>
          TransactionSuccess(_txPage([_transaction('tx-1', orderId: 'o-1')]));
      txRepo.onGet = (id) async =>
          TransactionSuccess(_transaction(id, orderId: 'o-1'));
      final orderRepo = _FakeOrderRepository();
      orderRepo.onGet = (id) async => OrderSuccess(_order(id));
      final cubit = TransactionCubit(
        getTransactions: GetTransactionsUseCase(txRepo),
        getTransactionById: GetTransactionByIdUseCase(txRepo),
      );
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(
              value: _paymentCubit(_FakePaymentRepository()),
            ),
            BlocProvider.value(
              value: OrderHistoryCubit(
                listOrdersUseCase: ListOrdersUseCase(orderRepo),
                getOrderByIdUseCase: GetOrderByIdUseCase(orderRepo),
              ),
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => const TransactionsPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('merchant-tx-1'));
      await tester.pumpAndSettle();
      expect(find.text('Transaction Detail'), findsOneWidget);
      final getsBefore = txRepo.getCalls;

      await _pullToRefresh(tester);

      expect(txRepo.getCalls, getsBefore + 1);
      // Detail header stays consistent with the history title source.
      expect(find.text('merchant-tx-1'), findsOneWidget);
      // Existing order navigation remains intact after the refresh.
      expect(find.byKey(const Key('transaction-view-order')), findsOneWidget);
    });

    testWidgets('refresh preserves active filters and pagination', (
      tester,
    ) async {
      final txRepo = _FakeTransactionRepository();
      txRepo.onList = (_) async =>
          TransactionSuccess(_txPage([_transaction('tx-1')]));
      final cubit = TransactionCubit(
        getTransactions: GetTransactionsUseCase(txRepo),
        getTransactionById: GetTransactionByIdUseCase(txRepo),
      );
      addTearDown(cubit.close);
      await cubit.setStatusFilter('PAID');
      final filterBefore = cubit.filter;
      final callsBefore = txRepo.listCalls;

      await cubit.refresh();

      expect(txRepo.listCalls, callsBefore + 1);
      expect(txRepo.lastFilter?.status, 'PAID');
      expect(txRepo.lastFilter?.page, 1);
      expect(cubit.filter.status, filterBefore.status);
      final state = cubit.state as TransactionListLoaded;
      expect(state.filter.status, 'PAID');
    });
  });

  group('Order detail pull-to-refresh', () {
    testWidgets('refresh re-reads by id and never creates orders', (
      tester,
    ) async {
      final orderRepo = _FakeOrderRepository();
      orderRepo.onGet = (id) async => OrderSuccess(_order(id));
      final paymentRepo = _FakePaymentRepository();
      paymentRepo.onList = () async => const PaymentSuccess(<Payment>[]);
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: _paymentCubit(paymentRepo),
            child: Builder(
              builder: (context) => OrderConfirmationPage(
                order: _order('order-1'),
                isReviewMode: true,
                getOrderById: GetOrderByIdUseCase(orderRepo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Order Details'), findsOneWidget);

      await _pullToRefresh(tester);

      expect(orderRepo.getCalls, 1);
      expect(orderRepo.createCalls, 0);
      expect(paymentRepo.createOrderPaymentCalls, 0);
      expect(find.text('Order Details'), findsOneWidget);
    });

    testWidgets('failed refresh retains details with feedback', (
      tester,
    ) async {
      final orderRepo = _FakeOrderRepository();
      orderRepo.onGet = (_) async =>
          const OrderError<Order>(ServerFailure());
      final paymentRepo = _FakePaymentRepository();
      await tester.pumpWidget(
        MaterialApp(
          home: BlocProvider.value(
            value: _paymentCubit(paymentRepo),
            child: Builder(
              builder: (context) => OrderConfirmationPage(
                order: _order('order-1'),
                isReviewMode: true,
                getOrderById: GetOrderByIdUseCase(orderRepo),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await _pullToRefresh(tester);

      // Retained details plus transient feedback, no blank page.
      expect(find.text('Order Details'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(orderRepo.createCalls, 0);
    });
  });
}

class _GatedOverviewRepository implements DashboardOverviewRepository {
  _GatedOverviewRepository(this.pending);

  final Future<DashboardOverviewResult<DashboardOverview>> pending;
  int calls = 0;

  @override
  Future<DashboardOverviewResult<DashboardOverview>> getOverview({
    required DateTime from,
    required DateTime to,
  }) {
    calls++;
    return pending;
  }
}

// Minimal OrderHistoryCubit stand-in so TransactionDetailPage's
// OrderHistoryCubit listener resolves without a full order-history setup.

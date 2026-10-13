import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_result.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_session.dart';
import 'package:payment_simulator/features/auth/domain/entities/auth_user.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';
import 'package:payment_simulator/features/auth/domain/usecases/login_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/logout_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:payment_simulator/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/home/domain/entities/backend_connection_status.dart';
import 'package:payment_simulator/features/home/domain/entities/dashboard_overview.dart';
import 'package:payment_simulator/features/home/domain/repositories/backend_connectivity_repository.dart';
import 'package:payment_simulator/features/home/domain/repositories/dashboard_overview_repository.dart';
import 'package:payment_simulator/features/home/domain/usecases/check_backend_connection.dart';
import 'package:payment_simulator/features/home/domain/usecases/get_dashboard_overview.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment.dart';
import 'package:payment_simulator/features/payments/domain/entities/payment_result.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payments_page.dart';
import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/products/presentation/pages/product_detail_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_page.dart';
import 'package:payment_simulator/features/orders/domain/entities/order_result.dart';
import 'package:payment_simulator/features/orders/domain/repositories/order_repository.dart';
import 'package:payment_simulator/features/orders/domain/usecases/create_order.dart';
import 'package:payment_simulator/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:payment_simulator/features/orders/domain/usecases/list_orders.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_filter.dart';
import 'package:payment_simulator/features/transactions/domain/entities/transaction_page.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transaction_by_id.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';
import 'package:payment_simulator/features/transactions/presentation/pages/transaction_page.dart';
import 'package:payment_simulator/main.dart';

class _FakeConnectivityRepository implements BackendConnectivityRepository {
  _FakeConnectivityRepository(this.status, {this.delay});

  final BackendConnectionStatus status;
  final Duration? delay;

  @override
  Future<BackendConnectionStatus> check() async {
    if (delay != null) await Future<void>.delayed(delay!);
    return status;
  }
}

/// A fake [PaymentRepository] for widget tests.
class _FakePaymentRepository implements PaymentRepository {
  final payments = [_payment('pay-1', 'PAY-001'), _payment('pay-2', 'PAY-002')];
  int listCalls = 0;

  @override
  Future<PaymentResult<Payment>> createPayment(
    CreatePaymentParams params,
  ) async {
    return PaymentSuccess(payments.first);
  }

  @override
  Future<PaymentResult<Payment>> getPayment(String paymentId) async {
    return PaymentSuccess(
      payments.firstWhere((item) => item.transactionId == paymentId),
    );
  }

  @override
  Future<PaymentResult<List<Payment>>> listPayments() async {
    listCalls++;
    return PaymentSuccess(payments);
  }

  @override
  Future<PaymentResult<Payment>> simulateSuccess(String paymentId) async {
    return getPayment(paymentId);
  }

  @override
  Future<PaymentResult<Payment>> simulateFail(String paymentId) async {
    return getPayment(paymentId);
  }

  @override
  Future<PaymentResult<Payment>> createOrderPayment({
    required String orderId,
    required String paymentMethod,
    required String idempotencyKey,
  }) async {
    return PaymentSuccess(payments.first);
  }

  @override
  Future<PaymentResult<List<Payment>>> listOrderPayments(
    String orderId,
  ) async {
    return PaymentError(const ServerFailure());
  }
}

/// A fake [TransactionRepository] for widget tests.
class _FakeTransactionRepository implements TransactionRepository {
  final transactions = [
    _transaction('tx-1', 'TX-001'),
    _transaction('tx-2', 'TX-002'),
  ];
  int listCalls = 0;

  @override
  Future<TransactionResult<TransactionPage>> getTransactions([
    TransactionFilter filter = const TransactionFilter(),
  ]) async {
    listCalls++;
    return TransactionSuccess(
      TransactionPage(
        transactions: transactions,
        page: 1,
        limit: 20,
        total: transactions.length,
        totalPages: 1,
      ),
    );
  }

  @override
  Future<TransactionResult<Transaction>> getTransactionById(
    String transactionId,
  ) async {
    return TransactionSuccess(
      transactions.firstWhere((item) => item.transactionId == transactionId),
    );
  }
}

Payment _payment(String id, String orderId) => Payment(
  transactionId: id,
  merchantOrderId: orderId,
  amount: 12000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: PaymentStatus.pending,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

Transaction _transaction(String id, String orderId) => Transaction(
  transactionId: id,
  merchantOrderId: orderId,
  amount: 12000,
  currency: 'IDR',
  paymentMethod: 'QRIS',
  status: TransactionStatus.pending,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

/// A fake [DashboardOverviewRepository] that returns an empty overview.
class _FakeOverviewRepository implements DashboardOverviewRepository {
  @override
  Future<DashboardOverviewResult<DashboardOverview>> getOverview({
    required DateTime from,
    required DateTime to,
  }) async {
    return const DashboardOverviewSuccess(
      DashboardOverview(
        revenueAmount: 0,
        currency: 'IDR',
        paidCount: 0,
        pendingCount: 0,
        failedCount: 0,
        recentTransactions: [],
      ),
    );
  }
}

class _FakeProductRepository implements ProductRepository {
  @override
  Future<List<Category>> listCategories() async {
    return [
      Category(
        id: 'cat-1',
        name: 'Beverages',
        description: 'Cold drinks',
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
      ),
    ];
  }

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    return ProductPage(
      products: [
        Product(
          id: 'prod-1',
          categoryId: 'cat-1',
          name: 'Es Teh',
          sku: 'BVR-001',
          description: 'Fresh iced tea',
          price: 12000,
          currency: 'IDR',
          active: true,
          createdAt: DateTime.fromMillisecondsSinceEpoch(0),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        ),
      ],
      page: page,
      limit: limit,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<Product> getProduct(String productId) async {
    return Product(
      id: productId,
      categoryId: 'cat-1',
      name: 'Es Teh',
      sku: 'BVR-001',
      description: 'Fresh iced tea',
      price: 12000,
      currency: 'IDR',
      active: true,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _InactiveProductRepository implements ProductRepository {
  @override
  Future<List<Category>> listCategories() async => const [];

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async => ProductPage(
    products: const [],
    page: page,
    limit: limit,
    total: 0,
    totalPages: 0,
  );

  @override
  Future<Product> getProduct(String productId) async {
    return Product(
      id: productId,
      categoryId: 'cat-1',
      name: 'Inactive Tea',
      sku: 'BVR-002',
      description: 'Unavailable item placeholder',
      price: 9000,
      currency: 'IDR',
      active: false,
      createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class _FakeOrderRepository implements OrderRepository {
  @override
  Future<OrderResult<Order>> createOrder({
    required List<OrderItemInput> items,
    required String idempotencyKey,
  }) async => const OrderError(ServerFailure());

  @override
  Future<OrderResult<OrderPage>> listOrders({
    required int page,
    required int limit,
  }) async =>
      const OrderError(ServerFailure());

  @override
  Future<OrderResult<Order>> getOrderById(String orderId) async =>
      const OrderError(ServerFailure());
}

/// A fake [AuthRepository] that is always authenticated, so the widget
/// tests exercise the HomePage without a live backend.
class _FakeAuthRepository implements AuthRepository {
  const _FakeAuthRepository();

  @override
  Future<AuthResult<AuthSession>> login(String email, String password) async {
    return AuthSuccess(_session);
  }

  @override
  Future<AuthResult<void>> logout() async => const AuthSuccess(null);

  @override
  Future<AuthResult<AuthSession?>> restoreSession() async {
    return AuthSuccess(_session);
  }

  @override
  Future<AuthResult<AuthSession>> refreshSession() async {
    return AuthSuccess(_session);
  }

  static const _session = AuthSession(
    accessToken: 'test-access',
    expiresIn: 900,
    user: AuthUser(
      id: 'u1',
      email: 'test@example.com',
      role: 'OWNER',
      status: 'ACTIVE',
      merchantId: 'm1',
    ),
  );
}

Widget _appWith(BackendConnectionStatus status, {Duration? delay}) {
  const authRepository = _FakeAuthRepository();
  final productRepository = _FakeProductRepository();
  final cartCubit = CartCubit();
  final orderCubit = OrderCubit(
    createOrderUseCase: CreateOrderUseCase(_FakeOrderRepository()),
    cartCubit: cartCubit,
  );
  final orderHistoryCubit = OrderHistoryCubit(
    listOrdersUseCase: ListOrdersUseCase(_FakeOrderRepository()),
    getOrderByIdUseCase: GetOrderByIdUseCase(_FakeOrderRepository()),
  );
  return GoSaasApp(
    authCubit: AuthCubit(
      restoreSession: RestoreSessionUseCase(authRepository),
      login: LoginUseCase(authRepository),
      logout: LogoutUseCase(authRepository),
      cartCubit: cartCubit,
    )..checkSession(),
    cartCubit: cartCubit,
    orderCubit: orderCubit,
    orderHistoryCubit: orderHistoryCubit,
    checkConnection: CheckBackendConnectionUseCase(
      _FakeConnectivityRepository(status, delay: delay),
    ),
    getOverview: GetDashboardOverviewUseCase(_FakeOverviewRepository()),
    paymentCubit: PaymentCubit(
      listPayments: ListPaymentsUseCase(_FakePaymentRepository()),
      getPayment: GetPaymentUseCase(_FakePaymentRepository()),
      createPayment: CreatePaymentUseCase(_FakePaymentRepository()),
      simulateSuccess: SimulatePaymentSuccessUseCase(_FakePaymentRepository()),
      simulateFail: SimulatePaymentFailUseCase(_FakePaymentRepository()),
    ),
    transactionCubit: TransactionCubit(
      getTransactions: GetTransactionsUseCase(_FakeTransactionRepository()),
      getTransactionById: GetTransactionByIdUseCase(
        _FakeTransactionRepository(),
      ),
    ),
    listCategories: ListCategoriesUseCase(productRepository),
    listProducts: ListProductsUseCase(productRepository),
    getProduct: GetProductUseCase(productRepository),
  );
}

Future<void> _openHomeFeature(WidgetTester tester, String feature) async {
  await tester.scrollUntilVisible(
    find.text(feature),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.text(feature));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('App launches and displays home page with features', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        const BackendConnected(
          statusCode: 200,
          latency: Duration(milliseconds: 12),
        ),
      ),
    );

    // Verify the app bar title is displayed.
    expect(find.text('Merchant POS'), findsOneWidget);

    // Verify the POS feature navigation items are displayed. Later items
    // may sit below the fold on small viewports, so match offstage too.
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Orders'), findsOneWidget);
    expect(find.text('Payments', skipOffstage: false), findsOneWidget);
    expect(find.text('Transactions', skipOffstage: false), findsOneWidget);

    // 'Settings' sits below the fold — scroll to reveal it.
    await tester.scrollUntilVisible(
      find.text('Settings'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('Products page opens the detail view for a selected product', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        const BackendConnected(
          statusCode: 200,
          latency: Duration(milliseconds: 12),
        ),
      ),
    );

    await tester.tap(find.text('Products'));
    await tester.pumpAndSettle();

    expect(find.text('Es Teh'), findsOneWidget);
    await tester.tap(find.text('Es Teh'));
    await tester.pumpAndSettle();

    expect(find.text('Product Detail'), findsOneWidget);
    expect(find.text('Es Teh'), findsWidgets);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('Es Teh'), findsOneWidget);

    await tester.tap(find.text('Es Teh'));
    await tester.pumpAndSettle();
    expect(find.text('Product Detail'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Es Teh'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Merchant POS'), findsOneWidget);
  });

  testWidgets('Inactive product detail disables add to cart', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider(
          create: (_) => CartCubit(),
          child: ProductDetailPage(
            productId: 'prod-2',
            getProduct: GetProductUseCase(_InactiveProductRepository()),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(
      find.text('This product is unavailable and cannot be added to the cart.'),
      findsOneWidget,
    );

    final addButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Add to Cart'),
    );
    expect(addButton.onPressed, isNull);
  });

  testWidgets('Home payment route restores list and Home on Back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_appWith(const BackendNotChecked()));
    await _openHomeFeature(tester, 'Payments');

    expect(find.text('PAY-001'), findsOneWidget);
    await tester.tap(find.text('PAY-001'));
    await tester.pumpAndSettle();
    expect(find.text('Payment Detail'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('PAY-001'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Merchant POS'), findsOneWidget);
  });

  testWidgets('Home transaction route restores list and Home on Back', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_appWith(const BackendNotChecked()));
    await _openHomeFeature(tester, 'Transactions');

    expect(find.text('TX-001'), findsOneWidget);
    await tester.tap(find.text('TX-001'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Detail'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('TX-001'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Merchant POS'), findsOneWidget);
  });

  testWidgets('Payment detail return keeps the shared cubit usable', (
    WidgetTester tester,
  ) async {
    final repository = _FakePaymentRepository();
    final cubit = PaymentCubit(
      listPayments: ListPaymentsUseCase(repository),
      getPayment: GetPaymentUseCase(repository),
      createPayment: CreatePaymentUseCase(repository),
      simulateSuccess: SimulatePaymentSuccessUseCase(repository),
      simulateFail: SimulatePaymentFailUseCase(repository),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(value: cubit, child: const PaymentsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('PAY-001'));
    await tester.pumpAndSettle();
    expect(find.text('Payment Detail'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('PAY-002'), findsOneWidget);
    expect(cubit.isClosed, isFalse);
    expect(repository.listCalls, 2);

    await tester.tap(find.text('PAY-002'));
    await tester.pumpAndSettle();
    expect(find.text('Payment Detail'), findsOneWidget);
    expect(find.text('PAY-002'), findsOneWidget);
  });

  testWidgets('Transaction detail return keeps the shared cubit usable', (
    WidgetTester tester,
  ) async {
    final repository = _FakeTransactionRepository();
    final cubit = TransactionCubit(
      getTransactions: GetTransactionsUseCase(repository),
      getTransactionById: GetTransactionByIdUseCase(repository),
    );
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cubit),
          BlocProvider.value(
            value: OrderHistoryCubit(
              listOrdersUseCase: ListOrdersUseCase(_FakeOrderRepository()),
              getOrderByIdUseCase: GetOrderByIdUseCase(_FakeOrderRepository()),
            ),
          ),
        ],
        child: const MaterialApp(home: TransactionsPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('TX-001'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Detail'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('TX-002'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('TX-002'), findsOneWidget);
    expect(cubit.isClosed, isFalse);
    expect(repository.listCalls, 2);

    await tester.tap(find.text('TX-002'));
    await tester.pumpAndSettle();
    expect(find.text('Transaction Detail'), findsOneWidget);
    expect(find.text('TX-002'), findsOneWidget);
  });

  testWidgets('Backend connection card offers a first check when not checked', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_appWith(const BackendNotChecked()));

    await tester.scrollUntilVisible(
      find.text('Backend Connection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Backend Connection'), findsOneWidget);
    expect(find.text('Not checked yet'), findsOneWidget);
    expect(find.text('Test Connection'), findsOneWidget);
  });

  testWidgets('Backend connection card runs check and shows connected status', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        const BackendConnected(
          statusCode: 200,
          latency: Duration(milliseconds: 12),
        ),
        delay: const Duration(milliseconds: 50),
      ),
    );

    // Trigger the check.
    await tester.scrollUntilVisible(
      find.text('Test Connection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Test Connection'));
    await tester.pump();
    expect(find.text('Checking...'), findsOneWidget);

    // Let the delayed response complete.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.textContaining('Connected · HTTP 200'), findsOneWidget);
    expect(find.textContaining('12 ms'), findsOneWidget);
  });

  testWidgets('Backend connection card shows failure category and message', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        const BackendConnectionFailed(
          category: BackendFailureCategory.connection,
          message: 'Could not reach the backend.',
        ),
        delay: const Duration(milliseconds: 50),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Test Connection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Test Connection'));
    await tester.pump();
    expect(find.text('Checking...'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.text('Connection Failed · Connection Failure'), findsOneWidget);
    expect(find.textContaining('Could not reach the backend.'), findsOneWidget);
  });

  testWidgets('Backend connection card can re-check after success', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _appWith(
        const BackendConnected(
          statusCode: 200,
          latency: Duration(milliseconds: 12),
        ),
        delay: const Duration(milliseconds: 50),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Test Connection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Test Connection'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.textContaining('Connected · HTTP 200'), findsOneWidget);

    // Re-check via the refresh action.
    await tester.scrollUntilVisible(
      find.byTooltip('Re-check connection'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byTooltip('Re-check connection'));
    await tester.pump();
    expect(find.text('Checking...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump();
    expect(find.textContaining('Connected · HTTP 200'), findsOneWidget);
  });
}

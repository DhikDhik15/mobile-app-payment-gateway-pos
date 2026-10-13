import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:payment_simulator/core/config/app_environment.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/dio_api_client.dart';
import 'package:payment_simulator/core/network/token_storage.dart';
import 'package:payment_simulator/core/theme/app_theme.dart';
import 'package:payment_simulator/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:payment_simulator/features/auth/data/datasources/secure_token_storage.dart';
import 'package:payment_simulator/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:payment_simulator/features/auth/domain/repositories/auth_repository.dart';
import 'package:payment_simulator/features/auth/domain/usecases/login_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/logout_usecase.dart';
import 'package:payment_simulator/features/auth/domain/usecases/restore_session_usecase.dart';
import 'package:payment_simulator/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:payment_simulator/features/auth/presentation/pages/auth_page.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/home/data/datasources/dashboard_overview_remote_datasource.dart';
import 'package:payment_simulator/features/home/data/repositories/backend_connectivity_repository_impl.dart';
import 'package:payment_simulator/features/home/data/repositories/dashboard_overview_repository_impl.dart';
import 'package:payment_simulator/features/home/domain/repositories/backend_connectivity_repository.dart';
import 'package:payment_simulator/features/home/domain/repositories/dashboard_overview_repository.dart';
import 'package:payment_simulator/features/home/domain/usecases/check_backend_connection.dart';
import 'package:payment_simulator/features/home/domain/usecases/get_dashboard_overview.dart';
import 'package:payment_simulator/features/orders/data/datasources/order_remote_data_source.dart';
import 'package:payment_simulator/features/orders/data/repositories/order_repository_impl.dart';
import 'package:payment_simulator/features/orders/domain/usecases/create_order.dart';
import 'package:payment_simulator/features/orders/domain/usecases/get_order_by_id.dart';
import 'package:payment_simulator/features/orders/domain/usecases/list_orders.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_cubit.dart';
import 'package:payment_simulator/features/payments/data/datasources/payment_remote_datasource.dart';
import 'package:payment_simulator/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:payment_simulator/features/payments/domain/repositories/payment_repository.dart';
import 'package:payment_simulator/features/payments/domain/usecases/create_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/get_payment.dart';
import 'package:payment_simulator/features/payments/domain/usecases/list_payments.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_fail.dart';
import 'package:payment_simulator/features/payments/domain/usecases/simulate_payment_success.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/products/data/datasources/product_remote_datasource.dart';
import 'package:payment_simulator/features/products/data/repositories/product_repository_impl.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/transactions/data/datasources/transaction_remote_datasource.dart';
import 'package:payment_simulator/features/transactions/data/repositories/transaction_repository_impl.dart';
import 'package:payment_simulator/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transaction_by_id.dart';
import 'package:payment_simulator/features/transactions/domain/usecases/get_transactions.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the runtime environment (.env) before anything that depends on it
  // is initialized.
  await dotenv.load(fileName: '.env');

  // Fail clearly when the backend URL is not configured — do not silently
  // fall back to a default.
  AppEnvironment.validate();

  // ── Composition root ──────────────────────────────────────────────────────
  // One shared network client is created here and reused by every feature.
  // Features never instantiate HTTP clients directly.
  final AuthTokenStorage tokenStorage = SecureTokenStorage();
  final ApiClient apiClient = DioApiClient(tokenStorage: tokenStorage);

  // Shared local cart state stays device-scoped and in-memory.
  final cartCubit = CartCubit();
  final orderRemote = OrderRemoteDataSourceImpl(apiClient);
  final orderRepository = OrderRepositoryImpl(orderRemote);
  final createOrder = CreateOrderUseCase(orderRepository);
  final orderCubit = OrderCubit(
    createOrderUseCase: createOrder,
    cartCubit: cartCubit,
  );
  final listOrders = ListOrdersUseCase(orderRepository);
  final getOrderById = GetOrderByIdUseCase(orderRepository);
  final orderHistoryCubit = OrderHistoryCubit(
    listOrdersUseCase: listOrders,
    getOrderByIdUseCase: getOrderById,
  );

  // Auth feature wiring.
  final AuthRemoteDataSource authRemote = AuthRemoteDataSourceImpl(apiClient);
  final AuthRepository authRepository = AuthRepositoryImpl(
    authRemote,
    tokenStorage,
  );
  final restoreSession = RestoreSessionUseCase(authRepository);
  final login = LoginUseCase(authRepository);
  final logout = LogoutUseCase(authRepository);
  final authCubit = AuthCubit(
    restoreSession: restoreSession,
    login: login,
    logout: logout,
    cartCubit: cartCubit,
  );

  // Home connectivity feature wiring.
  final BackendConnectivityRepository connectivityRepository =
      BackendConnectivityRepositoryImpl(apiClient);
  final checkConnection = CheckBackendConnectionUseCase(connectivityRepository);

  // Dashboard overview wiring (POS home dashboard).
  final DashboardOverviewRemoteDataSource overviewRemote =
      DashboardOverviewRemoteDataSourceImpl(apiClient);
  final DashboardOverviewRepository overviewRepository =
      DashboardOverviewRepositoryImpl(overviewRemote);
  final getOverview = GetDashboardOverviewUseCase(overviewRepository);

  // Payment feature wiring.
  final PaymentRemoteDataSource paymentRemote = PaymentRemoteDataSourceImpl(
    apiClient,
  );
  final PaymentRepository paymentRepository = PaymentRepositoryImpl(
    paymentRemote,
  );
  final listPayments = ListPaymentsUseCase(paymentRepository);
  final getPayment = GetPaymentUseCase(paymentRepository);
  final createPayment = CreatePaymentUseCase(paymentRepository);
  final simulateSuccess = SimulatePaymentSuccessUseCase(paymentRepository);
  final simulateFail = SimulatePaymentFailUseCase(paymentRepository);
  final paymentCubit = PaymentCubit(
    listPayments: listPayments,
    getPayment: getPayment,
    createPayment: createPayment,
    simulateSuccess: simulateSuccess,
    simulateFail: simulateFail,
  );

  // Transaction feature wiring.
  final TransactionRemoteDataSource transactionRemote =
      TransactionRemoteDataSourceImpl(apiClient);
  final TransactionRepository transactionRepository = TransactionRepositoryImpl(
    transactionRemote,
  );
  final getTransactions = GetTransactionsUseCase(transactionRepository);
  final getTransactionById = GetTransactionByIdUseCase(transactionRepository);
  final transactionCubit = TransactionCubit(
    getTransactions: getTransactions,
    getTransactionById: getTransactionById,
  );

  final ProductRemoteDataSource productRemote = ProductRemoteDataSourceImpl(
    apiClient,
  );
  final ProductRepository productRepository = ProductRepositoryImpl(
    productRemote,
  );
  final listCategories = ListCategoriesUseCase(productRepository);
  final listProducts = ListProductsUseCase(productRepository);
  final getProduct = GetProductUseCase(productRepository);

  // Development diagnostic: report the effective backend base URL (never logs
  // credentials — the base URL contains none).
  if (kDebugMode) {
    debugPrint('[Environment] API_BASE_URL=${AppEnvironment.apiBaseUrl}');
  }
  developer.log(
    'Effective API base URL: ${AppEnvironment.apiBaseUrl}',
    name: 'PaymentSimulator',
  );

  // Kick off the startup session check before the first frame so the router
  // can send the user to the right screen immediately.
  await authCubit.checkSession();

  runApp(
    GoSaasApp(
      authCubit: authCubit,
      cartCubit: cartCubit,
      orderCubit: orderCubit,
      orderHistoryCubit: orderHistoryCubit,
      checkConnection: checkConnection,
      getOverview: getOverview,
      paymentCubit: paymentCubit,
      transactionCubit: transactionCubit,
      listCategories: listCategories,
      listProducts: listProducts,
      getProduct: getProduct,
    ),
  );
}

/// Root application widget for the GO-SAAS Payment Simulator.
///
/// Configures the MaterialApp with the shared theme and sets the auth router
/// as the initial route.
class GoSaasApp extends StatelessWidget {
  const GoSaasApp({
    super.key,
    required this.authCubit,
    this.cartCubit,
    required this.orderCubit,
    required this.orderHistoryCubit,
    required this.checkConnection,
    required this.getOverview,
    required this.paymentCubit,
    required this.transactionCubit,
    required this.listCategories,
    required this.listProducts,
    required this.getProduct,
  });

  final AuthCubit authCubit;
  final CartCubit? cartCubit;
  final OrderCubit orderCubit;
  final OrderHistoryCubit orderHistoryCubit;
  final CheckBackendConnectionUseCase checkConnection;
  final GetDashboardOverviewUseCase getOverview;
  final PaymentCubit paymentCubit;
  final TransactionCubit transactionCubit;
  final ListCategoriesUseCase listCategories;
  final ListProductsUseCase listProducts;
  final GetProductUseCase getProduct;

  @override
  Widget build(BuildContext context) {
    final effectiveCartCubit = cartCubit ?? CartCubit();
    // Providers sit above MaterialApp so every pushed route (Cart, Order
    // Confirmation, Checkout, Payment Detail, …) can read the shared cubits.
    // Per-push BlocProvider.value wrappers are kept as explicit documentation
    // of each route's dependencies.
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: authCubit),
        BlocProvider.value(value: effectiveCartCubit),
        BlocProvider.value(value: orderCubit),
        BlocProvider.value(value: orderHistoryCubit),
        BlocProvider.value(value: paymentCubit),
        BlocProvider.value(value: transactionCubit),
      ],
      child: MaterialApp(
        title: 'GO-SAAS Merchant POS',
        theme: AppTheme.lightTheme,
        home: BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthUnauthenticated) orderCubit.reset();
          },
          child: AuthPage(
            checkConnection: checkConnection,
            getOverview: getOverview,
            paymentCubit: paymentCubit,
            transactionCubit: transactionCubit,
            orderHistoryCubit: orderHistoryCubit,
            listCategories: listCategories,
            listProducts: listProducts,
            getProduct: getProduct,
            cartCubit: effectiveCartCubit,
          ),
        ),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

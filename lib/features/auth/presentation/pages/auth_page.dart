import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:payment_simulator/features/auth/presentation/pages/login_page.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/home/domain/usecases/check_backend_connection.dart';
import 'package:payment_simulator/features/home/domain/usecases/get_dashboard_overview.dart';
import 'package:payment_simulator/features/home/presentation/pages/home_page.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';

/// Authentication router.
///
/// Listens to [AuthCubit] and shows:
///  * a splash while the stored session is being verified;
///  * [LoginPage] when unauthenticated;
///  * [HomePage] when authenticated.
class AuthPage extends StatelessWidget {
  const AuthPage({
    super.key,
    required this.checkConnection,
    required this.getOverview,
    required this.paymentCubit,
    required this.transactionCubit,
    required this.orderHistoryCubit,
    required this.listCategories,
    required this.listProducts,
    required this.getProduct,
    this.cartCubit,
  });

  final CheckBackendConnectionUseCase checkConnection;
  final GetDashboardOverviewUseCase getOverview;
  final PaymentCubit paymentCubit;
  final TransactionCubit transactionCubit;
  final OrderHistoryCubit orderHistoryCubit;
  final ListCategoriesUseCase listCategories;
  final ListProductsUseCase listProducts;
  final GetProductUseCase getProduct;
  final CartCubit? cartCubit;

  @override
  Widget build(BuildContext context) {
    final effectiveCartCubit = cartCubit ?? CartCubit();
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, state) {
        return switch (state) {
          AuthCheckingSession() => const _SplashScreen(),
          AuthAuthenticated() => HomePage(
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
          _ => const LoginPage(),
        };
      },
    );
  }
}

/// Minimal splash shown while the stored session is verified at startup.
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined, size: 64),
            SizedBox(height: 24),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

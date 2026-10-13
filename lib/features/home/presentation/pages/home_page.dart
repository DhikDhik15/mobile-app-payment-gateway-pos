import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/cart/presentation/pages/cart_page.dart';
import 'package:payment_simulator/features/home/domain/usecases/check_backend_connection.dart';
import 'package:payment_simulator/features/home/domain/usecases/get_dashboard_overview.dart';
import 'package:payment_simulator/features/home/presentation/bloc/home_cubit.dart';
import 'package:payment_simulator/features/home/presentation/bloc/pos_home_cubit.dart';
import 'package:payment_simulator/features/home/presentation/widgets/backend_connection_card.dart';
import 'package:payment_simulator/features/home/presentation/widgets/home_feature_card.dart';
import 'package:payment_simulator/features/orders/presentation/bloc/order_history_cubit.dart';
import 'package:payment_simulator/features/orders/presentation/pages/orders_page.dart';
import 'package:payment_simulator/features/payments/presentation/bloc/payment_cubit.dart';
import 'package:payment_simulator/features/payments/presentation/pages/payments_page.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/products/presentation/pages/products_page.dart';
import 'package:payment_simulator/features/settings/presentation/pages/settings_page.dart';
import 'package:payment_simulator/features/transactions/presentation/bloc/transaction_cubit.dart';
import 'package:payment_simulator/features/transactions/presentation/pages/transaction_page.dart';
import 'package:payment_simulator/features/transactions/presentation/widgets/transaction_list_item.dart';

/// Merchant POS home dashboard.
///
/// Shows today's sales (from the real dashboard overview endpoint), a
/// [New Sale] entry point, recent transactions, and POS feature navigation.
class HomePage extends StatelessWidget {
  const HomePage({
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
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => HomeCubit(checkConnection: checkConnection),
        ),
        BlocProvider(
          create: (_) => PosHomeCubit(getOverview: getOverview)..loadToday(),
        ),
        BlocProvider.value(value: effectiveCartCubit),
      ],
      child: _HomeBody(
        paymentCubit: paymentCubit,
        transactionCubit: transactionCubit,
        orderHistoryCubit: orderHistoryCubit,
        listCategories: listCategories,
        listProducts: listProducts,
        getProduct: getProduct,
        cartCubit: effectiveCartCubit,
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.paymentCubit,
    required this.transactionCubit,
    required this.orderHistoryCubit,
    required this.listCategories,
    required this.listProducts,
    required this.getProduct,
    required this.cartCubit,
  });

  final PaymentCubit paymentCubit;
  final TransactionCubit transactionCubit;
  final OrderHistoryCubit orderHistoryCubit;
  final ListCategoriesUseCase listCategories;
  final ListProductsUseCase listProducts;
  final GetProductUseCase getProduct;
  final CartCubit cartCubit;

  static const _features = [
    FeatureItem(
      title: 'Products',
      subtitle: 'Live catalog and POS filtering',
      icon: Icons.inventory_2_outlined,
    ),
    FeatureItem(
      title: 'Orders',
      subtitle: 'Order history and payment recovery',
      icon: Icons.shopping_bag_outlined,
    ),
    FeatureItem(
      title: 'Transactions',
      subtitle: 'Orders and payment history',
      icon: Icons.receipt_long_outlined,
    ),
    FeatureItem(
      title: 'Payments',
      subtitle: 'Create and manage payments',
      icon: Icons.payment_outlined,
    ),
    FeatureItem(
      title: 'Settings',
      subtitle: 'Account and sign out',
      icon: Icons.settings_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Merchant POS'),
        actions: [
          _CartAction(cartCubit: cartCubit),
          const _LogoutAction(),
        ],
      ),
      body: BlocBuilder<PosHomeCubit, PosHomeState>(
        builder: (context, state) {
          return RefreshIndicator(
            // Dashboard refresh re-reads today's overview only. It never
            // touches the cart, orders, or payments.
            onRefresh: () => context.read<PosHomeCubit>().loadToday(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
            children: [
              _SalesCard(state: state),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BlocProvider.value(
                      value: paymentCubit,
                      child: const PaymentsPage(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('New Sale'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Recent Transactions',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _RecentTransactions(
                state: state,
                transactionCubit: transactionCubit,
              ),
              const SizedBox(height: 24),
              const Text(
                'Features',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              for (final feature in _features)
                HomeFeatureCard(
                  feature: feature,
                  onTap: () => _navigate(context, feature.title),
                ),
              const SizedBox(height: 16),
              const Text(
                'Developer',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              BlocBuilder<HomeCubit, HomeState>(
                builder: (context, homeState) =>
                    BackendConnectionCard(status: homeState.connection),
              ),
            ],
            ),
          );
        },
      ),
    );
  }

  void _navigate(BuildContext context, String title) {
    switch (title) {
      case 'Products':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductsPage(
              listCategories: listCategories,
              listProducts: listProducts,
              getProduct: getProduct,
            ),
          ),
        );
      case 'Transactions':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: transactionCubit,
              child: const TransactionsPage(),
            ),
          ),
        );
      case 'Orders':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: orderHistoryCubit,
              child: const OrdersPage(),
            ),
          ),
        );
      case 'Payments':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => BlocProvider.value(
              value: paymentCubit,
              child: const PaymentsPage(),
            ),
          ),
        );
      case 'Settings':
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsPage()));
    }
  }
}

/// Today's sales summary derived from the dashboard overview endpoint.
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.state});

  final PosHomeState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: switch (state) {
          PosHomeLoading() || PosHomeInitial() => const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator()),
          ),
          PosHomeFailure(message: final message) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Sales",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => context.read<PosHomeCubit>().loadToday(),
                child: const Text('Retry'),
              ),
            ],
          ),
          PosHomeLoaded(overview: final overview) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Today's Sales",
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                _formatRupiah(overview.revenueAmount),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${overview.paidCount} paid · ${overview.pendingCount} pending · '
                '${overview.failedCount} failed today (${overview.currency})',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        },
      ),
    );
  }
}

/// Recent transactions from the dashboard overview.
class _RecentTransactions extends StatelessWidget {
  const _RecentTransactions({
    required this.state,
    required this.transactionCubit,
  });

  final PosHomeState state;
  final TransactionCubit transactionCubit;

  @override
  Widget build(BuildContext context) {
    return switch (state) {
      PosHomeLoaded(overview: final overview) =>
        overview.recentTransactions.isEmpty
            ? const Text(
                'No transactions yet',
                style: TextStyle(color: Colors.grey),
              )
            : Column(
                children: [
                  for (final t in overview.recentTransactions.take(5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TransactionListItem(
                        transaction: t,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => BlocProvider.value(
                              value: transactionCubit,
                              child: TransactionDetailPage(
                                transactionId: t.transactionId,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      PosHomeFailure() => const SizedBox.shrink(),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Formats a smallest-unit IDR amount as `Rp x.xxx`.
String _formatRupiah(int amount) {
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final remainingAfter = digits.length - i - 1;
    buffer.write(digits[i]);
    if (remainingAfter > 0 && remainingAfter % 3 == 0) buffer.write('.');
  }
  return '${amount < 0 ? '-' : ''}Rp $buffer';
}

class _CartAction extends StatelessWidget {
  const _CartAction({required this.cartCubit});

  final CartCubit cartCubit;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CartCubit, Cart>(
      bloc: cartCubit,
      builder: (context, cart) {
        final count = cart.items.fold<int>(
          0,
          (sum, item) => sum + item.quantity,
        );
        return IconButton(
          tooltip: 'Open cart',
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const CartPage())),
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shopping_cart_outlined),
              if (count > 0)
                Positioned(
                  right: -6,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.orange,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      count.toString(),
                      style: const TextStyle(fontSize: 10, color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Logout action shown in the authenticated app bar.
class _LogoutAction extends StatelessWidget {
  const _LogoutAction();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthFailure) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final isLoading = state is AuthLoading;
        return IconButton(
          tooltip: 'Keluar',
          icon: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.logout),
          onPressed: isLoading
              ? null
              : () => context.read<AuthCubit>().signOut(),
        );
      },
    );
  }
}

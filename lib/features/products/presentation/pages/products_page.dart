import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart_item.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/cart/presentation/pages/cart_page.dart';
import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/products/presentation/pages/product_detail_page.dart';
import 'package:payment_simulator/features/products/presentation/widgets/product_image.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({
    super.key,
    required this.listCategories,
    required this.listProducts,
    required this.getProduct,
  });

  final ListCategoriesUseCase listCategories;
  final ListProductsUseCase listProducts;
  final GetProductUseCase getProduct;

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  static const _pageSize = 20;

  bool _loading = true;
  String? _error;
  List<Category> _categories = const [];
  List<Product> _products = const [];
  String? _selectedCategoryId;
  bool _categoryInitialized = false;
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  String? _loadMoreError;
  int _requestEpoch = 0;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
    _loadCatalog();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = await widget.listCategories(const NoParams());
      if (!mounted) return;
      setState(() {
        _categories = categories;
        // Preserve the active filter (including an explicit "All" with a
        // null id) across refreshes; only default to the first category on
        // the very first load.
        if (!_categoryInitialized && categories.isNotEmpty) {
          _selectedCategoryId ??= categories.first.id;
          _categoryInitialized = true;
        }
      });
      await _loadProductsPage(append: false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// Loads one page of the server-filtered catalog. Concurrent calls
  /// collapse into one request; stale responses from an older epoch
  /// (e.g. a page load overtaken by a filter change) are ignored.
  Future<void> _loadProductsPage({required bool append}) async {
    if (append) {
      if (_loadingMore || !_hasMore) return;
      setState(() {
        _loadingMore = true;
        _loadMoreError = null;
      });
    }
    final epoch = ++_requestEpoch;
    final page = append ? _page + 1 : 1;
    try {
      final result = await widget.listProducts(
        ProductListParams(
          categoryId: _selectedCategoryId,
          page: page,
          limit: _pageSize,
        ),
      );
      if (!mounted || epoch != _requestEpoch) return;
      setState(() {
        _products = append ? _deduplicated(_products, result.products) : result.products;
        _page = result.page;
        _hasMore = result.hasMore;
        _loadingMore = false;
        _loadMoreError = null;
      });
    } catch (error) {
      if (!mounted || epoch != _requestEpoch) return;
      setState(() {
        _loadingMore = false;
        if (append) {
          _loadMoreError =
              'Could not load more products. Check your connection and retry.';
        } else {
          _error = error.toString();
        }
      });
    }
  }

  Future<void> _loadMore() => _loadProductsPage(append: true);

  /// Pull-to-refresh / AppBar refresh. Reloads from page 1 while preserving
  /// the selected category filter. Concurrent refreshes collapse: a refresh
  /// issued while the first page is loading is ignored.
  Future<void> _refresh() async {
    if (_loading) return;
    await _loadCatalog();
  }

  void _onCategorySelected(String? categoryId) {
    if (_selectedCategoryId == categoryId) return;
    // Keep the current list visible while the filtered page loads; the
    // epoch guard discards this request if another filter wins the race.
    setState(() {
      _selectedCategoryId = categoryId;
      _categoryInitialized = true;
      _page = 1;
      _hasMore = false;
      _loadMoreError = null;
      _error = null;
    });
    _loadProductsPage(append: false);
  }

  static List<Product> _deduplicated(
    List<Product> existing,
    List<Product> incoming,
  ) {
    final ids = {for (final product in existing) product.id};
    return [
      ...existing,
      for (final product in incoming)
        if (ids.add(product.id)) product,
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(onPressed: _refresh, icon: const Icon(Icons.refresh)),
          IconButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CartPage())),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _loadCatalog)
          : _CatalogBody(
              categories: _categories,
              products: _products,
              selectedCategoryId: _selectedCategoryId,
              hasMore: _hasMore,
              loadingMore: _loadingMore,
              loadMoreError: _loadMoreError,
              scrollController: _scrollController,
              getProduct: widget.getProduct,
              onCategorySelected: _onCategorySelected,
              onRetryMore: _loadMore,
              onRefresh: _refresh,
            ),
    );
  }
}

class _CatalogBody extends StatelessWidget {
  const _CatalogBody({
    required this.categories,
    required this.products,
    required this.selectedCategoryId,
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreError,
    required this.scrollController,
    required this.getProduct,
    required this.onCategorySelected,
    required this.onRetryMore,
    required this.onRefresh,
  });

  final List<Category> categories;
  final List<Product> products;
  final String? selectedCategoryId;
  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
  final ScrollController scrollController;
  final GetProductUseCase getProduct;
  final ValueChanged<String?> onCategorySelected;
  final VoidCallback onRetryMore;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: selectedCategoryId == null,
                  onSelected: (_) => onCategorySelected(null),
                ),
                for (final category in categories)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: ChoiceChip(
                      label: Text(category.name),
                      selected: selectedCategoryId == category.id,
                      onSelected: (_) => onCategorySelected(category.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: products.isEmpty
                ? RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 64),
                        Center(
                          child: Text(
                            'No products match this category yet.',
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: onRefresh,
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: products.length + 1,
                    itemBuilder: (context, index) {
                      if (index == products.length) {
                        return _ListFooter(
                          hasMore: hasMore,
                          loadingMore: loadingMore,
                          loadMoreError: loadMoreError,
                          onRetryMore: onRetryMore,
                        );
                      }
                      final product = products[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => ProductDetailPage(
                                  productId: product.id,
                                  getProduct: getProduct,
                                ),
                              ),
                            );
                          },
                          leading: ProductImage(
                            imageUrl: product.imageUrl,
                            productName: product.name,
                          ),
                          title: Text(product.name),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (product.sku.isNotEmpty)
                                Text('SKU: ${product.sku}'),
                              const SizedBox(height: 4),
                              Text(
                                product.description.isEmpty
                                    ? 'No description'
                                    : product.description,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_formatPrice(product.price, product.currency)} · ${product.active ? 'Active' : 'Inactive'}',
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            onPressed: product.active
                                ? () {
                                    context.read<CartCubit>().add(
                                      CartItem(
                                        productId: product.id,
                                        name: product.name,
                                        quantity: 1,
                                        unitPrice: product.price,
                                        active: product.active,
                                      ),
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          '${product.name} added to cart',
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            tooltip: product.active
                                ? 'Add to cart'
                                : 'Product unavailable',
                            icon: const Icon(Icons.add_shopping_cart),
                          ),
                        ),
                      );
                    },
                    ),
                    ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(int price, String currency) {
    final value = price.toString();
    return '$currency ${value.replaceAllMapped(RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'), (match) => '.')}';
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({
    required this.hasMore,
    required this.loadingMore,
    required this.loadMoreError,
    required this.onRetryMore,
  });

  final bool hasMore;
  final bool loadingMore;
  final String? loadMoreError;
  final VoidCallback onRetryMore;

  @override
  Widget build(BuildContext context) {
    final error = loadMoreError;
    if (error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: onRetryMore,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    if (loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Text(
            'No more products',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 52, color: Colors.red),
            const SizedBox(height: 12),
            Text(
              'Unable to load catalog',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

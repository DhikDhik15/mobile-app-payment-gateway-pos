import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:payment_simulator/features/cart/domain/entities/cart_item.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/cart/presentation/pages/cart_page.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/presentation/widgets/product_image.dart';

/// Product detail page.
///
/// Loads a single product by [productId] through [getProduct] and supports
/// pull-to-refresh (plus an AppBar retry action on errors) that re-reads the
/// same product. Refreshing never touches the cart; the quantity stepper
/// state is preserved across refreshes.
class ProductDetailPage extends StatefulWidget {
  const ProductDetailPage({
    super.key,
    required this.productId,
    required this.getProduct,
  });

  final String productId;
  final GetProductUseCase getProduct;

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  Product? _product;
  Object? _error;
  bool _loadingFirst = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Single initial load; rebuilds (e.g. cart badge updates) never refetch.
    _loadFirst();
  }

  Future<void> _loadFirst() async {
    try {
      final product = await widget.getProduct(
        GetProductParams(productId: widget.productId),
      );
      if (!mounted) return;
      setState(() {
        _product = product;
        _error = null;
        _loadingFirst = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loadingFirst = false;
      });
    }
  }

  /// Re-reads the same product. Concurrent refreshes collapse into one.
  /// The last loaded product stays visible while the refresh is in flight,
  /// so the quantity stepper state below is never discarded.
  Future<void> _refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      final product = await widget.getProduct(
        GetProductParams(productId: widget.productId),
      );
      if (!mounted) return;
      setState(() {
        _product = product;
        _error = null;
      });
    } catch (_) {
      // Failures never clear the cart and never discard the retained
      // product; surface transient feedback instead.
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Could not refresh product. Showing last state.'),
            ),
          );
      }
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFirst) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final product = _product;
    if (product == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Product Detail'),
          actions: [
            IconButton(
              tooltip: 'Retry',
              onPressed: () {
                setState(() {
                  _loadingFirst = true;
                  _error = null;
                });
                _loadFirst();
              },
              icon: const Icon(Icons.refresh_outlined),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _loadingFirst = true;
              _error = null;
            });
            await _loadFirst();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 48),
              const Icon(
                Icons.error_outline,
                size: 52,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text('$_error', textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _loadingFirst = true;
                    _error = null;
                  });
                  _loadFirst();
                },
                child: const Text('Retry'),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Back'),
              ),
            ],
          ),
        ),
      );
    }

    // The content widget stays mounted across refreshes (only its product
    // prop updates), so the quantity stepper state is preserved.
    return _ProductDetailContent(
      product: product,
      productId: widget.productId,
      onRefresh: _refresh,
    );
  }
}

class _ProductDetailContent extends StatefulWidget {
  const _ProductDetailContent({
    required this.product,
    required this.productId,
    required this.onRefresh,
  });

  final Product product;
  final String productId;
  final Future<void> Function() onRefresh;

  @override
  State<_ProductDetailContent> createState() => _ProductDetailContentState();
}

class _ProductDetailContentState extends State<_ProductDetailContent> {
  int _quantity = 1;

  static String _formatPrice(int price) {
    final value = price.toString();
    return value.replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  static String _formatDateTime(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // The quantity stepper lives in this State object, so updating
    // widget.product via a refresh preserves the user's selection.
    final product = widget.product;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Detail'),
        actions: [
          IconButton(
            onPressed: () =>
                Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const CartPage())),
            icon: const Icon(Icons.shopping_cart_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: widget.onRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ProductImage(
                          imageUrl: product.imageUrl,
                          productName: product.name,
                          size: 160.0,
                          borderRadius: 12.0,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DetailRow(
                        label: 'SKU',
                        value: product.sku.isEmpty ? 'N/A' : product.sku,
                      ),
                      _DetailRow(
                        label: 'Category',
                        value: product.categoryId ?? 'Uncategorized',
                      ),
                      _DetailRow(
                        label: 'Price',
                        value:
                            '${product.currency} ${_formatPrice(product.price)}',
                      ),
                      _DetailRow(
                        label: 'Status',
                        value: product.active ? 'Active' : 'Inactive',
                      ),
                      _DetailRow(
                        label: 'Description',
                        value: product.description.isEmpty
                            ? 'No description'
                            : product.description,
                      ),
                      _DetailRow(
                        label: 'Created At',
                        value: _formatDateTime(product.createdAt),
                      ),
                      _DetailRow(
                        label: 'Updated At',
                        value: _formatDateTime(product.updatedAt),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!product.active)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'This product is unavailable and cannot be added to the cart.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Quantity'),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(
                              () => _quantity = (_quantity - 1).clamp(1, 99),
                            ),
                            icon: const Icon(Icons.remove),
                          ),
                          Text(
                            '$_quantity',
                            style: const TextStyle(fontSize: 18),
                          ),
                          IconButton(
                            onPressed: () => setState(
                              () => _quantity = (_quantity + 1).clamp(1, 99),
                            ),
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: product.active
                        ? () {
                            context.read<CartCubit>().add(
                              CartItem(
                                productId: widget.productId,
                                name: product.name,
                                quantity: _quantity,
                                unitPrice: product.price,
                                active: product.active,
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${product.name} added to cart'),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 15)),
          const Divider(),
        ],
      ),
    );
  }
}

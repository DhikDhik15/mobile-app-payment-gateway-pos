import 'product.dart';

/// A single page of the merchant's product catalog.
///
/// Mirrors the backend list envelope: `data` is the product array and `meta`
/// carries `page`, `limit`, `total`, and `total_pages`. When the backend
/// omits metadata, [totalPages] falls back to a length-based heuristic so
/// pagination still terminates.
class ProductPage {
  const ProductPage({
    required this.products,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  final List<Product> products;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  /// Whether another page may exist after this one.
  bool get hasMore => page < totalPages;
}

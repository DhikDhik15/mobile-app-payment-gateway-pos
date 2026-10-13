/// Merchant POS product domain entity.
class Product {
  const Product({
    required this.id,
    this.categoryId,
    required this.name,
    required this.sku,
    required this.description,
    required this.price,
    required this.currency,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  final String id;
  final String? categoryId;
  final String name;
  final String sku;
  final String description;
  final int price;
  final String currency;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Optional HTTPS image reference. Null when the backend omits it
  /// (legacy responses predate the field). Display-only; never uploaded.
  final String? imageUrl;
}

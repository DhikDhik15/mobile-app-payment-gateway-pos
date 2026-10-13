import 'package:payment_simulator/features/products/domain/entities/product.dart';

class ProductModel extends Product {
  const ProductModel({
    required super.id,
    super.categoryId,
    required super.name,
    required super.sku,
    required super.description,
    required super.price,
    required super.currency,
    required super.active,
    required super.createdAt,
    required super.updatedAt,
    super.imageUrl,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      categoryId: json['category_id']?.toString(),
      name: (json['name'] ?? '').toString(),
      sku: (json['sku'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: (json['price'] is int)
          ? json['price'] as int
          : int.tryParse('${json['price']}') ?? 0,
      currency: (json['currency'] ?? 'IDR').toString(),
      active: json['active'] == true,
      createdAt:
          DateTime.tryParse(json['created_at'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt:
          DateTime.tryParse(json['updated_at'] ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      imageUrl: json['image_url']?.toString(),
    );
  }
}

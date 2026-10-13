import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';

abstract class ProductRepository {
  const ProductRepository();

  Future<List<Category>> listCategories();

  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  });

  Future<Product> getProduct(String productId);
}

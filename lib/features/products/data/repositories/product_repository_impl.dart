import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/products/data/datasources/product_remote_datasource.dart';
import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';

class ProductRepositoryImpl extends ProductRepository {
  const ProductRepositoryImpl(this._remote);

  final ProductRemoteDataSource _remote;

  @override
  Future<List<Category>> listCategories() async {
    try {
      return await _remote.listCategories();
    } on AppException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      return await _remote.listProducts(
        categoryId: categoryId,
        active: active,
        search: search,
        page: page,
        limit: limit,
      );
    } on AppException catch (error) {
      throw _mapError(error);
    }
  }

  @override
  Future<Product> getProduct(String productId) async {
    try {
      return await _remote.getProduct(productId);
    } on AppException catch (error) {
      throw _mapError(error);
    }
  }

  Failure _mapError(AppException error) {
    return switch (error) {
      NetworkTimeoutException() => const TimeoutFailure(),
      ConnectionNetworkException() => const ConnectionFailure(),
      ApiException() => ApiFailure(error.statusCode, error.message),
      InvalidResponseException() => const InvalidResponseFailure(),
      _ => const ServerFailure(),
    };
  }
}

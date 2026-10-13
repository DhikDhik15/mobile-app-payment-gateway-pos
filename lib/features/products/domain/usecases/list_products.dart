import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';

class ProductListParams {
  const ProductListParams({
    this.categoryId,
    this.active,
    this.search,
    this.page = 1,
    this.limit = 20,
  });

  final String? categoryId;
  final bool? active;
  final String? search;
  final int page;
  final int limit;
}

class ListProductsUseCase implements UseCase<ProductPage, ProductListParams> {
  const ListProductsUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<ProductPage> call(ProductListParams params) =>
      _repository.listProducts(
        categoryId: params.categoryId,
        active: params.active,
        search: params.search,
        page: params.page,
        limit: params.limit,
      );
}

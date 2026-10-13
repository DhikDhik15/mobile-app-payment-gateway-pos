import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/products/data/datasources/product_remote_datasource.dart';
import 'package:payment_simulator/features/products/data/models/category_model.dart';
import 'package:payment_simulator/features/products/data/models/product_model.dart';
import 'package:payment_simulator/features/products/data/repositories/product_repository_impl.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';

class _FakeProductRemoteDataSource extends ProductRemoteDataSource {
  ProductPage? pageResult;
  AppException? error;
  int? lastPage;
  int? lastLimit;
  String? lastCategoryId;

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    lastPage = page;
    lastLimit = limit;
    lastCategoryId = categoryId;
    if (error != null) throw error!;
    return pageResult!;
  }

  @override
  Future<List<CategoryModel>> listCategories() async => const [];

  @override
  Future<ProductModel> getProduct(String productId) async =>
      throw UnimplementedError();
}

ProductPage _page() => const ProductPage(
  products: [],
  page: 2,
  limit: 5,
  total: 12,
  totalPages: 3,
);

void main() {
  group('ProductRepositoryImpl.listProducts', () {
    test('forwards pagination and filters to the datasource', () async {
      final remote = _FakeProductRemoteDataSource()..pageResult = _page();
      final repository = ProductRepositoryImpl(remote);

      final page = await repository.listProducts(
        categoryId: 'cat-1',
        page: 2,
        limit: 5,
      );

      expect(remote.lastPage, 2);
      expect(remote.lastLimit, 5);
      expect(remote.lastCategoryId, 'cat-1');
      expect(page.page, 2);
      expect(page.hasMore, isTrue);
    });

    test('maps failures through the existing mapping', () async {
      final remote = _FakeProductRemoteDataSource()
        ..error = const ApiException(500, 'boom');
      final repository = ProductRepositoryImpl(remote);

      expect(
        () => repository.listProducts(),
        throwsA(isA<Failure>()),
      );
    });
  });

  group('ListProductsUseCase', () {
    test('forwards params including pagination', () async {
      final remote = _FakeProductRemoteDataSource()..pageResult = _page();
      final repository = ProductRepositoryImpl(remote);

      final page = await ListProductsUseCase(repository)(
        const ProductListParams(page: 2, limit: 5),
      );

      expect(remote.lastPage, 2);
      expect(remote.lastLimit, 5);
      expect(page.total, 12);
    });
  });
}

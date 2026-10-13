import 'package:payment_simulator/core/error/app_exception.dart';
import 'package:payment_simulator/core/network/api_client.dart';
import 'package:payment_simulator/core/network/api_endpoints.dart';
import 'package:payment_simulator/features/products/data/models/category_model.dart';
import 'package:payment_simulator/features/products/data/models/product_model.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';

abstract class ProductRemoteDataSource {
  const ProductRemoteDataSource();

  Future<List<CategoryModel>> listCategories();

  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  });

  Future<ProductModel> getProduct(String productId);
}

class ProductRemoteDataSourceImpl extends ProductRemoteDataSource {
  const ProductRemoteDataSourceImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<List<CategoryModel>> listCategories() async {
    final response = await _apiClient.get(ApiEndpoints.dashboardCategories);
    final data = response.data;
    if (data is! List) {
      throw const InvalidResponseException(
        'Expected a category list but received an unexpected payload',
      );
    }
    return data
        .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (categoryId != null && categoryId.isNotEmpty) {
      query['category_id'] = categoryId;
    }
    if (active != null) {
      query['active'] = active.toString();
    }
    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    final path = Uri(
      path: ApiEndpoints.dashboardProducts,
      queryParameters: query,
    ).toString();

    final response = await _apiClient.get(path);
    final data = response.data;
    if (data is! List) {
      throw const InvalidResponseException(
        'Expected a product list but received an unexpected payload',
      );
    }
    try {
      final products = [
        for (final item in data)
          ProductModel.fromJson(item as Map<String, dynamic>),
      ];
      return ProductPage(
        products: products,
        page: _metaInt(response.meta, 'page', page),
        limit: _metaInt(response.meta, 'limit', limit),
        total: _metaInt(response.meta, 'total', products.length),
        totalPages: _metaInt(
          response.meta,
          'total_pages',
          products.length < limit ? page : page + 1,
        ),
      );
    } on FormatException {
      throw const InvalidResponseException(
        'The server returned an invalid product response',
      );
    } on TypeError {
      throw const InvalidResponseException(
        'The server returned an invalid product response',
      );
    }
  }

  int _metaInt(dynamic meta, String key, int fallback) {
    if (meta is Map<String, dynamic>) {
      final value = meta[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
    }
    return fallback;
  }

  @override
  Future<ProductModel> getProduct(String productId) async {
    final path = ApiEndpoints.dashboardProductById.replaceAll(
      '{product_id}',
      productId,
    );
    final response = await _apiClient.get(path);
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw const InvalidResponseException(
        'Expected a product object but received an unexpected payload',
      );
    }
    return ProductModel.fromJson(data);
  }
}

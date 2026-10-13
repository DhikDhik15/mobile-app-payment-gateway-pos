import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';

class GetProductParams {
  const GetProductParams({required this.productId});

  final String productId;
}

class GetProductUseCase implements UseCase<Product, GetProductParams> {
  const GetProductUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<Product> call(GetProductParams params) =>
      _repository.getProduct(params.productId);
}

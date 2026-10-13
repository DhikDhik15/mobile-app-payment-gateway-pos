import 'package:payment_simulator/core/usecases/usecase.dart';
import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';

class ListCategoriesUseCase implements UseCase<List<Category>, NoParams> {
  const ListCategoriesUseCase(this._repository);

  final ProductRepository _repository;

  @override
  Future<List<Category>> call(NoParams params) => _repository.listCategories();
}

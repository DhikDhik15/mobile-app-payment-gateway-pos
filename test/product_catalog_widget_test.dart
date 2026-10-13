import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/core/error/failure.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/products/presentation/pages/products_page.dart';
import 'package:payment_simulator/features/products/presentation/widgets/product_image.dart';

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository({
    required this.pages,
    this.failOnPages = const {},
  });

  final List<List<Product>> pages;
  final Set<int> failOnPages;
  final List<Map<String, dynamic>> calls = [];

  @override
  Future<List<Category>> listCategories() async => const [];

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    calls.add({
      'categoryId': categoryId,
      'page': page,
      'limit': limit,
    });
    if (failOnPages.contains(page)) {
      throw const ConnectionFailure();
    }
    final items = page <= pages.length ? pages[page - 1] : const <Product>[];
    return ProductPage(
      products: items,
      page: page,
      limit: limit,
      total: pages.fold<int>(0, (sum, list) => sum + list.length),
      totalPages: pages.length,
    );
  }

  @override
  Future<Product> getProduct(String productId) async =>
      pages.expand((list) => list).firstWhere((p) => p.id == productId);
}

Product _product(
  String id, {
  String? imageUrl,
  bool active = true,
}) => Product(
  id: id,
  categoryId: 'cat-1',
  name: 'Product $id',
  sku: 'SKU-$id',
  description: 'Description $id',
  price: 12000,
  currency: 'IDR',
  active: active,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  imageUrl: imageUrl,
);

Widget _catalogApp(_FakeProductRepository repo, CartCubit cartCubit) {
  return MaterialApp(
    home: BlocProvider.value(
      value: cartCubit,
      child: Builder(
        builder: (context) => ProductsPage(
          listCategories: ListCategoriesUseCase(repo),
          listProducts: ListProductsUseCase(repo),
          getProduct: GetProductUseCase(repo),
        ),
      ),
    ),
  );
}

Future<void> _dragUpUntilVisible(
  WidgetTester tester,
  Finder scrollable,
  Finder finder, {
  double dy = -600,
}) async {
  for (var i = 0; i < 15 && finder.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, Offset(0, dy));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('ProductsPage catalog', () {
    testWidgets('loads the first page and appends the next on scroll', (
      tester,
    ) async {
      final repo = _FakeProductRepository(
        pages: [
          [for (var i = 0; i < 10; i++) _product('p1-$i')],
          [for (var i = 0; i < 10; i++) _product('p2-$i')],
        ],
      );
      await tester.pumpWidget(_catalogApp(repo, CartCubit()));
      await tester.pumpAndSettle();

      expect(find.text('Product p1-0'), findsOneWidget);

      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      await _dragUpUntilVisible(
        tester,
        find.byType(ListView).last,
        find.text('Product p2-9'),
      );

      expect(find.text('Product p2-9'), findsOneWidget);
      expect(find.text('No more products'), findsOneWidget);
      expect(
        repo.calls.map((c) => c['page']).toList(),
        [1, 2],
      );
    });

    testWidgets('failed page load keeps entries with retry', (tester) async {
      final repo = _FakeProductRepository(
        pages: [
          [for (var i = 0; i < 10; i++) _product('p1-$i')],
          [for (var i = 0; i < 10; i++) _product('p2-$i')],
        ],
        failOnPages: {2},
      );
      await tester.pumpWidget(_catalogApp(repo, CartCubit()));
      await tester.pumpAndSettle();

      await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();

      // Inline recoverable error; first page retained.
      expect(find.text('Retry'), findsOneWidget);
      repo.failOnPages.clear();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await _dragUpUntilVisible(
        tester,
        find.byType(ListView).last,
        find.text('Product p2-9'),
      );
      expect(find.text('Product p2-9'), findsOneWidget);
    });

    testWidgets('add to cart sends id, name, quantity, and unit price', (
      tester,
    ) async {
      final cartCubit = CartCubit();
      final repo = _FakeProductRepository(
        pages: [
          [_product('p1')],
        ],
      );
      await tester.pumpWidget(_catalogApp(repo, cartCubit));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add_shopping_cart).first);
      await tester.pumpAndSettle();

      final items = cartCubit.state.items;
      expect(items.length, 1);
      expect(items.single.productId, 'p1');
      expect(items.single.quantity, 1);
      expect(items.single.unitPrice, 12000);
      expect(items.single.name, 'Product p1');
    });

    testWidgets('inactive products cannot be added to cart', (tester) async {
      final cartCubit = CartCubit();
      final repo = _FakeProductRepository(
        pages: [
          [_product('p1', active: false)],
        ],
      );
      await tester.pumpWidget(_catalogApp(repo, cartCubit));
      await tester.pumpAndSettle();

      final addButton = find.widgetWithIcon(IconButton, Icons.add_shopping_cart);
      expect(addButton, findsOneWidget);
      expect(tester.widget<IconButton>(addButton).onPressed, isNull);
      expect(cartCubit.state.items, isEmpty);
    });
  });

  group('ProductImage', () {
    testWidgets('renders placeholder for missing urls', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ProductImage(imageUrl: null, productName: 'Tea'),
                ProductImage(imageUrl: '   ', productName: 'Coffee'),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image_outlined), findsNWidgets(2));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('falls back when the url fails to load', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: 'https://invalid.invalid/missing.png',
              productName: 'Tea',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('keeps a fixed size to avoid layout jumps', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(imageUrl: null, productName: 'Tea', size: 56),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final box = tester.getSize(find.byType(ProductImage).first);
      expect(box, const Size(56, 56));
    });
  });
}

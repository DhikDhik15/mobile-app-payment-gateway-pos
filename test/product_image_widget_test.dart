import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:payment_simulator/features/products/domain/entities/category.dart';
import 'package:payment_simulator/features/products/domain/entities/product.dart';
import 'package:payment_simulator/features/products/domain/entities/product_page.dart';
import 'package:payment_simulator/features/products/domain/repositories/product_repository.dart';
import 'package:payment_simulator/features/products/domain/usecases/get_product.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_categories.dart';
import 'package:payment_simulator/features/products/domain/usecases/list_products.dart';
import 'package:payment_simulator/features/products/presentation/pages/product_detail_page.dart';
import 'package:payment_simulator/features/products/presentation/pages/products_page.dart';
import 'package:payment_simulator/features/products/presentation/widgets/product_image.dart';

const String _testBaseUrl = 'http://10.0.2.2:8081';
const String _relativeRef = '/api/v1/product-images/merchant-1/file-1.png';
const String _resolvedRef =
    'http://10.0.2.2:8081/api/v1/product-images/merchant-1/file-1.png';

// Minimal 1x1 transparent PNG served by the mock HTTP client so image loads
// succeed in widget tests without any live network dependency.
const List<int> _transparentPng = <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
];

/// Records every image URL requested so tests can assert the resolved,
/// credential-free URL actually used on the wire.
class _MockHttpClient implements HttpClient {
  static final List<Uri> requestedUrls = <Uri>[];

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    requestedUrls.add(url);
    return _MockHttpClientRequest();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MockHttpClientRequest implements HttpClientRequest {
  @override
  Future<HttpClientResponse> close() async => _MockHttpClientResponse();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_transparentPng).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  int get statusCode => HttpStatus.ok;

  @override
  int get contentLength => _transparentPng.length;

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Serves the mock image bytes for the duration of [body].
///
/// Flutter's network image loader caches a shared `HttpClient` and resolves
/// frame work outside any `runZoned` scope, so the documented
/// [debugNetworkImageHttpClientProvider] seam is used instead of zone or
/// global `HttpOverrides` (neither reliably intercepts image loads in tests).
Future<void> _withMockImages(Future<void> Function() body) async {
  final previous = debugNetworkImageHttpClientProvider;
  debugNetworkImageHttpClientProvider = () => _MockHttpClient();
  try {
    await body();
  } finally {
    debugNetworkImageHttpClientProvider = previous;
  }
}

Product _product(String id, {String? imageUrl}) => Product(
  id: id,
  categoryId: 'cat-1',
  name: 'Product $id',
  sku: 'SKU-$id',
  description: 'Description $id',
  price: 12000,
  currency: 'IDR',
  active: true,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
  imageUrl: imageUrl,
);

class _FakeProductRepository implements ProductRepository {
  _FakeProductRepository(this.products);

  final List<Product> products;

  @override
  Future<List<Category>> listCategories() async => const [];

  @override
  Future<ProductPage> listProducts({
    String? categoryId,
    bool? active,
    String? search,
    int page = 1,
    int limit = 20,
  }) async => ProductPage(
    products: products,
    page: 1,
    limit: limit,
    total: products.length,
    totalPages: 1,
  );

  @override
  Future<Product> getProduct(String productId) async =>
      products.firstWhere((p) => p.id == productId);
}

String _networkImageUrl(WidgetTester tester) {
  final image = tester.widget<Image>(find.byType(Image));
  return (image.image as NetworkImage).url;
}

/// Pumps until image loads settle, allowing real async engine work
/// (image decoding) to complete. Plain `pumpAndSettle` alone never finishes
/// pending image loads under FakeAsync in this setup.
Future<void> _pumpSettleImages(WidgetTester tester) async {
  // Render content first so image loads actually start; only then allow
  // real async engine work (decoding) to finish; then render the pixels.
  await tester.pumpAndSettle();
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  await tester.pumpAndSettle();
}

/// Pumps frames until the image placeholder appears (load still pending or
/// failed). Fails the test if it never appears.
Future<void> _pumpUntilPlaceholder(WidgetTester tester) async {
  for (var i = 0; i < 50; i++) {
    if (find.byIcon(Icons.image_outlined).evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('expected the image placeholder to appear');
}

void main() {
  setUpAll(() {
    dotenv.testLoad(fileInput: 'API_BASE_URL=$_testBaseUrl');
  });

  setUp(() {
    _MockHttpClient.requestedUrls.clear();
    // ImageCache survives across tests in a file; without a clear, later
    // tests would hit the cache and skip the loading state and HTTP request.
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
  });

  group('ProductImage widget', () {
    testWidgets('renders placeholder for null, blank, and invalid urls', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ProductImage(imageUrl: null, productName: 'Tea'),
                ProductImage(imageUrl: '   ', productName: 'Coffee'),
                ProductImage(
                  imageUrl: 'ftp://files.example.com/tea.png',
                  productName: 'Cocoa',
                ),
                ProductImage(
                  imageUrl: '/other/path/tea.png',
                  productName: 'Milk',
                ),
              ],
            ),
          ),
        ),
      );
      await _pumpSettleImages(tester);

      expect(find.byIcon(Icons.image_outlined), findsNWidgets(4));
    });

    testWidgets('resolves backend-local references before loading', (
      tester,
    ) async {
      await _withMockImages(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProductImage(
                imageUrl: _relativeRef,
                productName: 'Tea',
                apiBaseUrl: _testBaseUrl,
              ),
            ),
          ),
        );
        await _pumpSettleImages(tester);

        // The rendered output is the loaded image, not the placeholder, and
        // the request used the resolved absolute URL.
        expect(find.byIcon(Icons.image_outlined), findsNothing);
        expect(_networkImageUrl(tester), _resolvedRef);
      });
    });

    testWidgets('keeps absolute HTTPS URLs unchanged', (tester) async {
      const absolute = 'https://cdn.example.com/images/tea.png';
      await _withMockImages(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProductImage(
                imageUrl: absolute,
                productName: 'Tea',
                apiBaseUrl: _testBaseUrl,
              ),
            ),
          ),
        );
        await _pumpSettleImages(tester);

        expect(find.byIcon(Icons.image_outlined), findsNothing);
        expect(_networkImageUrl(tester), absolute);
      });
    });

    testWidgets('shows placeholder while loading, then the image', (
      tester,
    ) async {
      await _withMockImages(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProductImage(
                imageUrl: _relativeRef,
                productName: 'Tea',
                apiBaseUrl: _testBaseUrl,
              ),
            ),
          ),
        );
        await tester.pump();

        expect(find.byIcon(Icons.image_outlined), findsOneWidget);

        await _pumpSettleImages(tester);
        expect(find.byIcon(Icons.image_outlined), findsNothing);
      });
    });

    testWidgets('falls back when the url fails to load', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProductImage(
              imageUrl: 'https://invalid.invalid/missing.png',
              productName: 'Tea',
              apiBaseUrl: _testBaseUrl,
            ),
          ),
        ),
      );
      await _pumpUntilPlaceholder(tester);
      await _pumpSettleImages(tester);

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('requests the resolved URL without credentials', (
      tester,
    ) async {
      await _withMockImages(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProductImage(
                imageUrl: _relativeRef,
                productName: 'Tea',
                apiBaseUrl: _testBaseUrl,
              ),
            ),
          ),
        );
        await _pumpSettleImages(tester);

        expect(_MockHttpClient.requestedUrls, hasLength(1));
        final requested = _MockHttpClient.requestedUrls.single;
        expect(requested.toString(), _resolvedRef);
        expect(requested.userInfo, isEmpty);
        expect(requested.query, isEmpty);
      });
    });

    testWidgets('keeps a fixed size and honors fit', (tester) async {
      await _withMockImages(() async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: ProductImage(
                imageUrl: _relativeRef,
                productName: 'Tea',
                apiBaseUrl: _testBaseUrl,
                size: 96,
                fit: BoxFit.contain,
              ),
            ),
          ),
        );
        await _pumpSettleImages(tester);

        expect(
          tester.getSize(find.byType(ProductImage).first),
          const Size(96, 96),
        );
        expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.contain);
        expect(find.byIcon(Icons.image_outlined), findsNothing);
      });
    });
  });

  group('product screens with images', () {
    testWidgets('catalog shows info for products with and without images', (
      tester,
    ) async {
      final repo = _FakeProductRepository([
        _product('with-image', imageUrl: _relativeRef),
        _product('without-image'),
      ]);
      await _withMockImages(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (_) => CartCubit(),
              child: Builder(
                builder: (context) => ProductsPage(
                  listCategories: ListCategoriesUseCase(repo),
                  listProducts: ListProductsUseCase(repo),
                  getProduct: GetProductUseCase(repo),
                ),
              ),
            ),
          ),
        );
        await _pumpSettleImages(tester);

        // Existing info stays visible regardless of image presence.
        expect(find.text('Product with-image'), findsOneWidget);
        expect(find.text('Product without-image'), findsOneWidget);
        expect(find.textContaining('12.000'), findsNWidgets(2));
        expect(find.byType(ProductImage), findsNWidgets(2));
        // The imaged product loaded (no placeholder); the imageless one
        // kept its placeholder.
        expect(find.byIcon(Icons.image_outlined), findsOneWidget);
        expect(
          _MockHttpClient.requestedUrls.single.toString(),
          _resolvedRef,
        );
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('catalog row tolerates long names and odd aspect ratios', (
      tester,
    ) async {
      const longName =
          'Extraordinarily Long Product Name That Should Never Break The Catalog Row Layout';
      await _withMockImages(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: ListView(
                children: const [
                  ListTile(
                    leading: ProductImage(
                      imageUrl: _relativeRef,
                      productName: longName,
                      apiBaseUrl: _testBaseUrl,
                    ),
                    title: Text(longName),
                    subtitle: Text('IDR 12.000 · Active'),
                  ),
                ],
              ),
            ),
          ),
        );
        await _pumpSettleImages(tester);

        expect(find.text(longName), findsWidgets);
        expect(find.byIcon(Icons.image_outlined), findsNothing);
        expect(tester.takeException(), isNull);
      });
    });

    testWidgets('detail shows the resolved image with product info', (
      tester,
    ) async {
      final repo = _FakeProductRepository([
        _product('detail-1', imageUrl: _relativeRef),
      ]);
      await _withMockImages(() async {
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider(
              create: (_) => CartCubit(),
              child: ProductDetailPage(
                productId: 'detail-1',
                getProduct: GetProductUseCase(repo),
              ),
            ),
          ),
        );
        await _pumpSettleImages(tester);

        expect(find.text('Product detail-1'), findsOneWidget);
        expect(find.textContaining('12.000'), findsWidgets);
        expect(find.byIcon(Icons.image_outlined), findsNothing);
        expect(
          _MockHttpClient.requestedUrls.single.toString(),
          _resolvedRef,
        );
        expect(tester.takeException(), isNull);
      });
    });
  });
}

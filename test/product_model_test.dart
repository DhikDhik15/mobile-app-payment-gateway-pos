import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/products/data/models/product_model.dart';

Map<String, dynamic> _productJson({Map<String, dynamic>? overrides}) => {
  'id': 'prod-1',
  'merchant_id': 'merchant-1',
  'category_id': 'cat-1',
  'name': 'Es Teh',
  'sku': 'BVR-001',
  'description': 'Fresh iced tea',
  'price': 12000,
  'currency': 'IDR',
  'active': true,
  'created_at': '2026-10-07T08:00:00Z',
  'updated_at': '2026-10-07T08:00:00Z',
  ...?overrides,
};

void main() {
  group('ProductModel.fromJson', () {
    test('parses a complete product including image_url', () {
      final model = ProductModel.fromJson(
        _productJson(
          overrides: {'image_url': 'https://cdn.example.com/tea.png'},
        ),
      );

      expect(model.id, 'prod-1');
      expect(model.name, 'Es Teh');
      expect(model.price, 12000);
      expect(model.currency, 'IDR');
      expect(model.active, isTrue);
      expect(model.imageUrl, 'https://cdn.example.com/tea.png');
    });

    test('treats a missing image_url as null (legacy responses)', () {
      final model = ProductModel.fromJson(_productJson());

      expect(model.imageUrl, isNull);
    });

    test('treats an explicit null image_url as null', () {
      final model = ProductModel.fromJson(
        _productJson(overrides: {'image_url': null}),
      );

      expect(model.imageUrl, isNull);
    });

    test('keeps a backend-local image reference verbatim for the resolver', () {
      const relativeRef = '/api/v1/product-images/merchant-1/file-1.png';
      final model = ProductModel.fromJson(
        _productJson(overrides: {'image_url': relativeRef}),
      );

      // Resolution against the backend origin happens at display time;
      // the model preserves the reference exactly as returned.
      expect(model.imageUrl, relativeRef);
    });

    test('keeps existing fields unchanged', () {
      final model = ProductModel.fromJson(_productJson());

      expect(model.id, 'prod-1');
      expect(model.categoryId, 'cat-1');
      expect(model.sku, 'BVR-001');
      expect(model.price, 12000);
      expect(model.imageUrl, isNull);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:payment_simulator/features/products/domain/product_image_url.dart';

void main() {
  group('resolveProductImageUrl', () {
    test('keeps absolute HTTPS URLs unchanged', () {
      const url = 'https://cdn.example.com/images/tea.png?size=large';
      expect(resolveProductImageUrl(url, apiBaseUrl: 'http://base:8081'), url);
    });

    test('keeps absolute HTTP URLs unchanged', () {
      const url = 'http://cdn.example.com/images/tea.png';
      expect(resolveProductImageUrl(url, apiBaseUrl: 'http://base:8081'), url);
    });

    test('resolves backend-local references against an origin-only base', () {
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/merchant-1/file-1.png',
          apiBaseUrl: 'http://10.0.2.2:8081',
        ),
        'http://10.0.2.2:8081/api/v1/product-images/merchant-1/file-1.png',
      );
    });

    test('never appends /api/v1 twice when the base carries a path', () {
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/merchant-1/file-1.png',
          apiBaseUrl: 'http://10.0.2.2:8081/api/v1',
        ),
        'http://10.0.2.2:8081/api/v1/product-images/merchant-1/file-1.png',
      );
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/merchant-1/file-1.png',
          apiBaseUrl: 'http://10.0.2.2:8081/api/v1/',
        ),
        'http://10.0.2.2:8081/api/v1/product-images/merchant-1/file-1.png',
      );
    });

    test('tolerates a trailing slash on the base URL', () {
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/m/f.png',
          apiBaseUrl: 'http://10.0.2.2:8081/',
        ),
        'http://10.0.2.2:8081/api/v1/product-images/m/f.png',
      );
    });

    test('trims surrounding whitespace before resolving', () {
      expect(
        resolveProductImageUrl(
          '  /api/v1/product-images/m/f.png  ',
          apiBaseUrl: 'http://10.0.2.2:8081',
        ),
        'http://10.0.2.2:8081/api/v1/product-images/m/f.png',
      );
    });

    test('returns null for null, empty, and blank input', () {
      expect(resolveProductImageUrl(null), isNull);
      expect(resolveProductImageUrl(''), isNull);
      expect(resolveProductImageUrl('   '), isNull);
    });

    test('returns null for malformed URLs', () {
      expect(
        resolveProductImageUrl(
          'ht!tp://[::1]nomatch',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          'not a url with spaces',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
    });

    test('returns null for unsupported schemes', () {
      expect(
        resolveProductImageUrl(
          'ftp://files.example.com/tea.png',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          'data:image/png;base64,iVBORw0KGgo=',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          'javascript:alert(1)',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
    });

    test('returns null for relative paths outside the catalog prefix', () {
      expect(
        resolveProductImageUrl(
          '/other/path/tea.png',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          'product-images/m/f.png',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          '//cdn.example.com/tea.png',
          apiBaseUrl: 'http://base:8081',
        ),
        isNull,
      );
    });

    test('returns null when no backend origin is configured', () {
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/m/f.png',
          apiBaseUrl: '',
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/m/f.png',
          apiBaseUrl: '   ',
        ),
        isNull,
      );
    });

    test('returns null when the base URL has no usable origin', () {
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/m/f.png',
          apiBaseUrl: 'not-a-url',
        ),
        isNull,
      );
      expect(
        resolveProductImageUrl(
          '/api/v1/product-images/m/f.png',
          apiBaseUrl: '192.168.1.5:8081',
        ),
        isNull,
      );
    });

    test('resolved URLs carry no credentials or extra parameters', () {
      final resolved = resolveProductImageUrl(
        '/api/v1/product-images/m/f.png',
        apiBaseUrl: 'http://10.0.2.2:8081',
      );
      expect(resolved, isNotNull);
      final uri = Uri.parse(resolved!);
      expect(uri.userInfo, isEmpty);
      expect(uri.query, isEmpty);
    });
  });
}

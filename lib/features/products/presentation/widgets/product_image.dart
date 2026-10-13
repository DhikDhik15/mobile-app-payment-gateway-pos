import 'package:flutter/material.dart';
import 'package:payment_simulator/features/products/domain/product_image_url.dart';

/// Fixed-size product image with a stable placeholder.
///
/// The fixed size prevents layout jumps while the image loads. A missing,
/// blank, invalid, or failed URL renders the placeholder instead of a
/// broken image. Backend `image_url` values are resolved centrally via
/// [resolveProductImageUrl] (relative catalog references become absolute
/// against the configured backend origin); absolute URLs pass through
/// untouched. Images are fetched with a plain GET — no auth headers or
/// tokens — and are display-only; uploads are out of scope.
class ProductImage extends StatelessWidget {
  const ProductImage({
    super.key,
    required this.imageUrl,
    required this.productName,
    this.size = 56.0,
    this.borderRadius = 8.0,
    this.fit = BoxFit.cover,
    this.apiBaseUrl,
  });

  final String? imageUrl;
  final String productName;
  final double size;
  final double borderRadius;
  final BoxFit fit;

  /// Backend origin override used only to resolve relative catalog
  /// references (defaults to the configured API base URL). Exposed so
  /// previews and widget tests can resolve without global `.env` state.
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final url = resolveProductImageUrl(imageUrl, apiBaseUrl: apiBaseUrl);
    if (url == null) {
      return _ProductImagePlaceholder(
        size: size,
        borderRadius: borderRadius,
        productName: productName,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: fit,
        semanticLabel: '$productName image',
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _ProductImagePlaceholder(
            size: size,
            borderRadius: borderRadius,
            productName: productName,
          );
        },
        errorBuilder: (context, error, stackTrace) =>
            _ProductImagePlaceholder(
              size: size,
              borderRadius: borderRadius,
              productName: productName,
            ),
      ),
    );
  }
}

class _ProductImagePlaceholder extends StatelessWidget {
  const _ProductImagePlaceholder({
    required this.size,
    required this.borderRadius,
    required this.productName,
  });

  final double size;
  final double borderRadius;
  final String productName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Icon(
        Icons.image_outlined,
        color: Colors.grey,
        semanticLabel: '$productName (no image)',
      ),
    );
  }
}

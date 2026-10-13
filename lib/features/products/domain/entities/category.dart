/// Merchant POS category domain entity.
class Category {
  const Category({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
}

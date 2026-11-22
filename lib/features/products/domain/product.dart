class Product {
  const Product({
    required this.id,
    required this.name,
    required this.description,
    required this.unit,
    required this.defaultPriceMinor,
    required this.requiresCustomPrice,
    required this.isActive,
  });

  factory Product.fromMap(Map<String, Object?> map) => Product(
    id: map['id']! as int,
    name: map['name']! as String,
    description: map['description']! as String,
    unit: map['unit']! as String,
    defaultPriceMinor: map['default_price_minor'] as int?,
    requiresCustomPrice: map['requires_custom_price'] == 1,
    isActive: map['is_active'] == 1,
  );

  final int id;
  final String name;
  final String description;
  final String unit;
  final int? defaultPriceMinor;
  final bool requiresCustomPrice;
  final bool isActive;
}

enum StockStatus {
  inStock('En stock'),
  low('Stock bas'),
  outOfStock('Rupture');

  const StockStatus(this.label);
  final String label;
}

enum ProductSort {
  name('Nom'),
  quantity('Quantité'),
  price('Prix de vente');

  const ProductSort(this.label);
  final String label;
}

/// Editable product fields, as entered in the form. Validated by the service.
class ProductInput {
  const ProductInput({
    required this.name,
    required this.sku,
    this.barcode,
    this.description,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.minStockThreshold,
  });

  final String name;
  final String sku;
  final String? barcode;
  final String? description;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int minStockThreshold;
}

class Product {
  const Product({
    this.id,
    required this.userId,
    required this.name,
    required this.sku,
    this.barcode,
    required this.qrIdentifier,
    this.description,
    required this.category,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.quantity,
    required this.minStockThreshold,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final int userId;
  final String name;
  final String sku;
  final String? barcode;

  /// Stable random identifier encoded in the product's QR code.
  /// It never changes, even when the name or SKU are edited.
  final String qrIdentifier;
  final String? description;
  final String category;
  final double purchasePrice;
  final double sellingPrice;
  final int quantity;
  final int minStockThreshold;
  final DateTime createdAt;
  final DateTime updatedAt;

  StockStatus get status {
    if (quantity <= 0) return StockStatus.outOfStock;
    if (quantity <= minStockThreshold) return StockStatus.low;
    return StockStatus.inStock;
  }

  double get stockValue => quantity * purchasePrice;
  double get potentialRevenue => quantity * sellingPrice;
  double get unitMargin => sellingPrice - purchasePrice;

  Product copyWithInput(ProductInput input, DateTime now) => Product(
        id: id,
        userId: userId,
        name: input.name,
        sku: input.sku,
        barcode: input.barcode,
        qrIdentifier: qrIdentifier,
        description: input.description,
        category: input.category,
        purchasePrice: input.purchasePrice,
        sellingPrice: input.sellingPrice,
        quantity: input.quantity,
        minStockThreshold: input.minStockThreshold,
        createdAt: createdAt,
        updatedAt: now,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'user_id': userId,
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'qr_identifier': qrIdentifier,
        'description': description,
        'category': category,
        'purchase_price': purchasePrice,
        'selling_price': sellingPrice,
        'quantity': quantity,
        'min_stock_threshold': minStockThreshold,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  factory Product.fromMap(Map<String, Object?> map) => Product(
        id: map['id']! as int,
        userId: map['user_id']! as int,
        name: map['name']! as String,
        sku: map['sku']! as String,
        barcode: map['barcode'] as String?,
        qrIdentifier: map['qr_identifier']! as String,
        description: map['description'] as String?,
        category: map['category']! as String,
        purchasePrice: (map['purchase_price']! as num).toDouble(),
        sellingPrice: (map['selling_price']! as num).toDouble(),
        quantity: map['quantity']! as int,
        minStockThreshold: map['min_stock_threshold']! as int,
        createdAt: DateTime.parse(map['created_at']! as String),
        updatedAt: DateTime.parse(map['updated_at']! as String),
      );
}

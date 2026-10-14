enum PartyKind { rep, wholesaler }

enum MovementType { stockIn, stockOut }

class Product {
  final int? id;
  final String name;
  final String sku;
  final int openingStock;
  final int reorderLevel;

  Product({
    this.id,
    required this.name,
    this.sku = '',
    this.openingStock = 0,
    this.reorderLevel = 20,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'sku': sku,
        'opening_stock': openingStock,
        'reorder_level': reorderLevel,
      };

  factory Product.fromMap(Map<String, dynamic> map) => Product(
        id: map['id'] as int?,
        name: map['name'] as String,
        sku: map['sku'] as String? ?? '',
        openingStock: map['opening_stock'] as int,
        reorderLevel: map['reorder_level'] as int,
      );
}

// A product together with how many units are currently on the shelf
class StockLevel {
  final Product product;
  final int onHand;

  StockLevel(this.product, this.onHand);

  bool get needsReorder => onHand <= product.reorderLevel;
}

// A sales rep or a wholesaler
class Party {
  final int? id;
  final String name;
  final PartyKind kind;

  Party({this.id, required this.name, required this.kind});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'kind': kind == PartyKind.rep ? 'rep' : 'wholesaler',
      };

  factory Party.fromMap(Map<String, dynamic> map) => Party(
        id: map['id'] as int?,
        name: map['name'] as String,
        kind: map['kind'] == 'rep' ? PartyKind.rep : PartyKind.wholesaler,
      );
}

// One stock-in or stock-out entry
class StockMovement {
  final int? id;
  final int productId;
  final int? partyId; // empty for stock in (restocking)
  final MovementType type;
  final int quantity;
  final DateTime date;
  final String note;

  // Filled in only when loaded together with the product/party names
  final String? productName;
  final String? partyName;

  StockMovement({
    this.id,
    required this.productId,
    this.partyId,
    required this.type,
    required this.quantity,
    required this.date,
    this.note = '',
    this.productName,
    this.partyName,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'product_id': productId,
        'party_id': partyId,
        'type': type == MovementType.stockIn ? 'in' : 'out',
        'quantity': quantity,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory StockMovement.fromMap(Map<String, dynamic> map) => StockMovement(
        id: map['id'] as int?,
        productId: map['product_id'] as int,
        partyId: map['party_id'] as int?,
        type: map['type'] == 'in' ? MovementType.stockIn : MovementType.stockOut,
        quantity: map['quantity'] as int,
        date: DateTime.parse(map['date'] as String),
        note: map['note'] as String? ?? '',
        productName: map['product_name'] as String?,
        partyName: map['party_name'] as String?,
      );
}
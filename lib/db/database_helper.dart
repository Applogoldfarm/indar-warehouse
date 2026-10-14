import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/models.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    _database ??= await _initDB('warehouse_inventory.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, fileName),
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL DEFAULT '',
        opening_stock INTEGER NOT NULL DEFAULT 0,
        reorder_level INTEGER NOT NULL DEFAULT 20
      )
    ''');
    await db.execute('''
      CREATE TABLE parties (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        kind TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        party_id INTEGER,
        type TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (product_id) REFERENCES products (id),
        FOREIGN KEY (party_id) REFERENCES parties (id)
      )
    ''');
  }

  // ---------- Products ----------

  Future<int> insertProduct(Product product) async {
    final db = await instance.database;
    return db.insert('products', product.toMap());
  }

  Future<int> updateProduct(Product product) async {
    final db = await instance.database;
    return db.update('products', product.toMap(),
        where: 'id = ?', whereArgs: [product.id]);
  }

  // Every product with its current stock:
  // opening stock + everything received - everything sent out
  Future<List<StockLevel>> getStockLevels() async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT p.*,
        p.opening_stock
        + COALESCE((SELECT SUM(quantity) FROM movements m
                    WHERE m.product_id = p.id AND m.type = 'in'), 0)
        - COALESCE((SELECT SUM(quantity) FROM movements m
                    WHERE m.product_id = p.id AND m.type = 'out'), 0)
        AS on_hand
      FROM products p
      ORDER BY p.name
    ''');
    return rows
        .map((row) => StockLevel(Product.fromMap(row), row['on_hand'] as int))
        .toList();
  }

  // ---------- Sales reps and wholesalers ----------

  Future<int> insertParty(Party party) async {
    final db = await instance.database;
    return db.insert('parties', party.toMap());
  }

  Future<int> updateParty(Party party) async {
    final db = await instance.database;
    return db.update('parties', party.toMap(),
        where: 'id = ?', whereArgs: [party.id]);
  }

  Future<List<Party>> getParties({PartyKind? kind}) async {
    final db = await instance.database;
    final rows = kind == null
        ? await db.query('parties', orderBy: 'name')
        : await db.query(
            'parties',
            where: 'kind = ?',
            whereArgs: [kind == PartyKind.rep ? 'rep' : 'wholesaler'],
            orderBy: 'name',
          );
    return rows.map((row) => Party.fromMap(row)).toList();
  }

  // ---------- Stock movements ----------

  Future<int> insertMovement(StockMovement movement) async {
    final db = await instance.database;
    return db.insert('movements', movement.toMap());
  }

  Future<int> deleteMovement(int id) async {
    final db = await instance.database;
    return db.delete('movements', where: 'id = ?', whereArgs: [id]);
  }

  // Movements between two dates, newest first, with product and party names
  Future<List<StockMovement>> getMovementsBetween(
      DateTime start, DateTime end) async {
    final db = await instance.database;
    final rows = await db.rawQuery('''
      SELECT m.*, p.name AS product_name, pa.name AS party_name
      FROM movements m
      JOIN products p ON p.id = m.product_id
      LEFT JOIN parties pa ON pa.id = m.party_id
      WHERE m.date >= ? AND m.date <= ?
      ORDER BY m.date DESC, m.id DESC
    ''', [start.toIso8601String(), end.toIso8601String()]);
    return rows.map((row) => StockMovement.fromMap(row)).toList();
  }
}
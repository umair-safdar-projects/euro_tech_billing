import '../../../core/database/app_database.dart';
import '../domain/product.dart';

class ProductRepository {
  ProductRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<List<Product>> getAll() async {
    final rows = await _appDatabase.database.query(
      'products',
      orderBy: 'id ASC',
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }

  Future<List<Product>> getActive({String search = ''}) async {
    final term = search.trim();
    final rows = await _appDatabase.database.query(
      'products',
      where: term.isEmpty
          ? 'is_active = 1'
          : 'is_active = 1 AND name LIKE ? ESCAPE \'\\\'',
      whereArgs: term.isEmpty ? null : ['%${_escapeLike(term)}%'],
      orderBy: 'name COLLATE NOCASE, id',
      limit: 100,
    );
    return rows.map(Product.fromMap).toList(growable: false);
  }

  String _escapeLike(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');

  Future<void> updatePrice(int id, int priceMinor) async {
    final count = await _appDatabase.database.update(
      'products',
      {
        'default_price_minor': priceMinor,
        'requires_custom_price': 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('Product price could not be updated.');
  }

  Future<void> setActive(int id, bool active) async {
    final count = await _appDatabase.database.update(
      'products',
      {
        'is_active': active ? 1 : 0,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('Product status could not be updated.');
  }

  Future<int> add({
    required String name,
    required String unit,
    required int? priceMinor,
    required bool requiresCustomPrice,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return _appDatabase.database.insert('products', {
      'name': name.trim(),
      'description': '',
      'unit': unit.trim(),
      'default_price_minor': requiresCustomPrice ? null : priceMinor,
      'requires_custom_price': requiresCustomPrice ? 1 : 0,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });
  }
}

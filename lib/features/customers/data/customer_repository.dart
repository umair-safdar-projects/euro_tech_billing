import '../../../core/database/app_database.dart';
import '../domain/customer.dart';

class CustomerRepository {
  CustomerRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<List<Customer>> search(String search, {int limit = 100}) async {
    final term = search.trim();
    final rows = await _appDatabase.database.query(
      'customers',
      where: term.isEmpty
          ? null
          : "name LIKE ? ESCAPE '\\' OR phone LIKE ? ESCAPE '\\'",
      whereArgs: term.isEmpty
          ? null
          : ['%${_escape(term)}%', '%${_escape(term)}%'],
      orderBy: 'name COLLATE NOCASE, id',
      limit: limit,
    );
    return rows.map(Customer.fromMap).toList(growable: false);
  }

  Future<Customer?> find(int id) async {
    final rows = await _appDatabase.database.query(
      'customers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.single);
  }

  Future<Customer> create(
    CustomerInput input, {
    required String saveToken,
  }) async {
    input.validate();
    final existing = await _byToken(saveToken);
    if (existing != null) return existing;
    final now = DateTime.now().toUtc().toIso8601String();
    try {
      final id = await _appDatabase.database.insert('customers', {
        'name': input.name.trim(),
        'phone': input.phone.trim(),
        'address': input.address.trim(),
        'notes': input.notes.trim(),
        'save_token': saveToken,
        'created_at': now,
        'updated_at': now,
      });
      return (await find(id))!;
    } catch (_) {
      final repeated = await _byToken(saveToken);
      if (repeated != null) return repeated;
      rethrow;
    }
  }

  Future<void> update(int id, CustomerInput input) async {
    input.validate();
    final count = await _appDatabase.database.update(
      'customers',
      {
        'name': input.name.trim(),
        'phone': input.phone.trim(),
        'address': input.address.trim(),
        'notes': input.notes.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
    if (count != 1) throw StateError('Customer could not be updated.');
  }

  Future<Customer?> _byToken(String token) async {
    final rows = await _appDatabase.database.query(
      'customers',
      where: 'save_token = ?',
      whereArgs: [token],
      limit: 1,
    );
    return rows.isEmpty ? null : Customer.fromMap(rows.single);
  }

  String _escape(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('%', r'\%')
      .replaceAll('_', r'\_');
}

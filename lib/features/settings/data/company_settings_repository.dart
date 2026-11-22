import '../../../core/database/app_database.dart';
import '../domain/company_settings.dart';

class CompanySettingsRepository {
  CompanySettingsRepository(this._appDatabase);

  final AppDatabase _appDatabase;

  Future<CompanySettings> load() async {
    final rows = await _appDatabase.database.query(
      'company_settings',
      where: 'id = ?',
      whereArgs: [1],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Company settings record is missing.');
    return CompanySettings.fromMap(rows.single);
  }

  Future<void> save(CompanySettings settings) async {
    final count = await _appDatabase.database.update(
      'company_settings',
      settings.toUpdateMap(),
      where: 'id = ?',
      whereArgs: [1],
    );
    if (count != 1) throw StateError('Company settings could not be saved.');
  }
}

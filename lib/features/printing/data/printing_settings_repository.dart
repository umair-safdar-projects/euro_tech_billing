import '../../../core/database/app_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../domain/printing_models.dart';

class PrintingSettingsRepository {
  PrintingSettingsRepository(this._appDatabase);
  final AppDatabase _appDatabase;

  static const _paperKey = 'printing.paper';
  static const _placementKey = 'printing.a4_placement';
  static const _footerKey = 'printing.footer';

  Future<PrintingSettings> load() async {
    final rows = await _appDatabase.database.query(
      'app_settings',
      where: 'key IN (?, ?, ?)',
      whereArgs: [_paperKey, _placementKey, _footerKey],
    );
    final values = {
      for (final row in rows) row['key']! as String: row['value']! as String,
    };
    return PrintingSettings(
      paper: values[_paperKey] == 'a4' ? InvoicePaper.a4 : InvoicePaper.a5,
      a4Placement: values[_placementKey] == 'top_left'
          ? A4Placement.topLeft
          : A4Placement.centered,
      footerMessage: values[_footerKey] ?? 'Thank you for your business!',
    );
  }

  Future<void> save(PrintingSettings settings) =>
      _appDatabase.database.transaction((transaction) async {
        final now = DateTime.now().toUtc().toIso8601String();
        final values = <String, String>{
          _paperKey: settings.paper.name,
          _placementKey: settings.a4Placement == A4Placement.topLeft
              ? 'top_left'
              : 'centered',
          _footerKey: settings.footerMessage.trim(),
        };
        for (final entry in values.entries) {
          await transaction.insert('app_settings', {
            'key': entry.key,
            'value': entry.value,
            'updated_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
}

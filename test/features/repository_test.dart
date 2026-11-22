import 'dart:io';

import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/features/products/data/product_repository.dart';
import 'package:eurotechbilling/features/settings/data/company_settings_repository.dart';
import 'package:eurotechbilling/features/settings/domain/company_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  late Directory temporaryDirectory;
  late AppDatabase appDatabase;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'euro_tech_repo_test_',
    );
    appDatabase = AppDatabase.forTesting(
      factory: databaseFactoryFfi,
      databasePath: p.join(temporaryDirectory.path, 'test.sqlite'),
    );
    await appDatabase.initialize();
  });

  tearDown(() async {
    await appDatabase.close();
    await temporaryDirectory.delete(recursive: true);
  });

  test('company settings persist after database reopen', () async {
    var repository = CompanySettingsRepository(appDatabase);
    const expected = CompanySettings(
      companyName: 'Euro Tech Updated',
      ownerName: 'Owner',
      primaryPhone: '03000000000',
      secondaryPhone: '',
      additionalContactName: 'Contact',
      additionalContactPhone: '03111111111',
      email: 'billing@example.com',
      address: 'Rawalpindi',
    );
    await repository.save(expected);
    await appDatabase.close();
    await appDatabase.initialize();
    repository = CompanySettingsRepository(appDatabase);

    final actual = await repository.load();
    expect(actual.companyName, expected.companyName);
    expect(actual.email, expected.email);
    expect(actual.address, expected.address);
  });

  test('product price update persists in minor units', () async {
    final repository = ProductRepository(appDatabase);
    final product = (await repository.getAll()).first;
    await repository.updatePrice(product.id, 42550);

    final updated = (await repository.getAll()).singleWhere(
      (candidate) => candidate.id == product.id,
    );
    expect(updated.defaultPriceMinor, 42550);
    expect(updated.requiresCustomPrice, isFalse);
  });
}

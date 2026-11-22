import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../constants/business_defaults.dart';

abstract final class DatabaseSeeder {
  static Future<void> seed(DatabaseExecutor db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await db.insert('company_settings', {
      'id': 1,
      'company_name': BusinessDefaults.companyName,
      'owner_name': BusinessDefaults.ownerName,
      'primary_phone': BusinessDefaults.primaryPhone,
      'secondary_phone': BusinessDefaults.secondaryPhone,
      'additional_contact_name': BusinessDefaults.additionalContactName,
      'additional_contact_phone': BusinessDefaults.additionalContactPhone,
      'email': BusinessDefaults.email,
      'address': BusinessDefaults.address,
      'created_at': now,
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);

    const products = <Map<String, Object?>>[
      {
        'key': 'sheet_cutting_350',
        'name': 'Sheet Cutting',
        'price': 35000,
        'custom': 0,
      },
      {
        'key': 'sheet_cutting_custom',
        'name': 'Sheet Cutting Custom',
        'price': null,
        'custom': 1,
      },
      {
        'key': 'edging_taping_30',
        'name': 'Edging & Taping',
        'price': 3000,
        'custom': 0,
      },
      {
        'key': 'edging_taping_40',
        'name': 'Edging & Taping',
        'price': 4000,
        'custom': 0,
      },
      {
        'key': 'edging_taping_50',
        'name': 'Edging & Taping',
        'price': 5000,
        'custom': 0,
      },
      {
        'key': 'edging_taping_80',
        'name': 'Edging & Taping',
        'price': 8000,
        'custom': 0,
      },
      {
        'key': 'edging_taping_custom',
        'name': 'Edging & Taping Custom',
        'price': null,
        'custom': 1,
      },
    ];
    for (final product in products) {
      await db.insert('products', {
        'seed_key': product['key'],
        'name': product['name'],
        'description': '',
        'unit': 'piece',
        'default_price_minor': product['price'],
        'requires_custom_price': product['custom'],
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
  }
}

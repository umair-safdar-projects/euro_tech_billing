import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app/app.dart';
import 'core/database/app_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();

  Object? initializationError;
  try {
    await AppDatabase.instance.initialize();
  } catch (error, stackTrace) {
    initializationError = error;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'database initialization',
      ),
    );
  }
  runApp(EuroTechBillingApp(initializationError: initializationError));
}

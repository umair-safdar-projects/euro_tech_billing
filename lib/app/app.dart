import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/shell/presentation/app_shell.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class EuroTechBillingApp extends StatelessWidget {
  const EuroTechBillingApp({super.key, this.initializationError});

  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'EURO TECH — EDGING AND CUTTING',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialBinding: initializationError == null ? InitialBinding() : null,
      initialRoute: AppRoutes.home,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => initializationError == null
              ? const AppShell()
              : InitializationErrorScreen(error: initializationError!),
        ),
      ],
    );
  }
}

class InitializationErrorScreen extends StatelessWidget {
  const InitializationErrorScreen({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Unable to open local data',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Euro Tech Billing could not initialize its local database. '
                    'Check that the application data folder is writable, then restart the application.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Technical details have been recorded for troubleshooting.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../features/shell/presentation/app_shell.dart';
import '../features/shell/domain/shell_destination.dart';
import '../features/shell/presentation/shell_controller.dart';
import 'bindings/initial_binding.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

class EuroTechBillingApp extends StatelessWidget {
  const EuroTechBillingApp({super.key, this.initializationError});

  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    Widget shellFor(ShellDestination destination) {
      if (initializationError != null) {
        return InitializationErrorScreen(error: initializationError!);
      }
      Get.find<ShellController>().selectDestination(destination);
      return const AppShell();
    }

    return GetMaterialApp(
      title: 'EURO TECH — EDGING AND CUTTING',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialBinding: initializationError == null ? InitialBinding() : null,
      initialRoute: AppRoutes.home,
      getPages: [
        GetPage(
          name: AppRoutes.home,
          page: () => shellFor(ShellDestination.dashboard),
        ),
        for (final destination in ShellDestination.values)
          GetPage(name: destination.route, page: () => shellFor(destination)),
      ],
      unknownRoute: GetPage(
        name: AppRoutes.notFound,
        page: () => const RouteErrorScreen(),
      ),
    );
  }
}

class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.route_rounded, size: 44, color: Colors.orange),
              const SizedBox(height: 14),
              Text(
                'This section could not be opened',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Return to the dashboard and try again.'),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Get.offAllNamed(AppRoutes.home),
                icon: const Icon(Icons.dashboard_rounded),
                label: const Text('Open dashboard'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
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

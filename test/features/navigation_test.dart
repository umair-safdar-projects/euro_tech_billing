import 'dart:io';

import 'package:eurotechbilling/app/app.dart';
import 'package:eurotechbilling/app/bindings/initial_binding.dart';
import 'package:eurotechbilling/core/database/app_database.dart';
import 'package:eurotechbilling/features/customers/presentation/customers_controller.dart';
import 'package:eurotechbilling/features/dashboard/presentation/dashboard_controller.dart';
import 'package:eurotechbilling/features/invoices/presentation/invoice_editor_controller.dart';
import 'package:eurotechbilling/features/invoices/presentation/invoice_history_controller.dart';
import 'package:eurotechbilling/features/payments/presentation/payments_credit_controller.dart';
import 'package:eurotechbilling/features/products/presentation/products_controller.dart';
import 'package:eurotechbilling/features/reports/presentation/reports_controller.dart';
import 'package:eurotechbilling/features/settings/presentation/settings_controller.dart';
import 'package:eurotechbilling/features/shared/presentation/empty_module_screen.dart';
import 'package:eurotechbilling/features/shell/domain/shell_destination.dart';
import 'package:eurotechbilling/features/shell/presentation/app_shell.dart';
import 'package:eurotechbilling/features/shell/presentation/shell_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.reset();
  });

  tearDown(Get.reset);

  test('all completed destinations have unique routes and real screens', () {
    expect(ShellDestination.values, hasLength(8));
    expect(
      ShellDestination.values.map((destination) => destination.route).toSet(),
      hasLength(ShellDestination.values.length),
    );
    expect(AppShell.defaultScreens, hasLength(ShellDestination.values.length));
    expect(AppShell.defaultScreens.whereType<EmptyModuleScreen>(), isEmpty);
  });

  test('company branding assets are bundled for installed builds', () async {
    final logo = await rootBundle.load('assets/branding/euro_tech_logo.png');
    final icon = await rootBundle.load(
      'assets/branding/euro_tech_icon_256.png',
    );

    expect(logo.lengthInBytes, greaterThan(10_000));
    expect(icon.lengthInBytes, greaterThan(5_000));
  });

  testWidgets('application root starts with the desktop shell', (tester) async {
    final controller = Get.put(ShellController());
    tester.view.physicalSize = const Size(1366, 768);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(home: AppShell(screens: _probeScreens())),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('desktop-shell')), findsOneWidget);
    expect(controller.selected, ShellDestination.dashboard);
    expect(find.byKey(const ValueKey('probe-screen-0')), findsOneWidget);
  });

  for (final scale in [1.0, 1.25, 1.5]) {
    testWidgets(
      'every destination opens at 1366x768 and ${(scale * 100).round()}% scaling',
      (tester) async {
        final controller = Get.put(ShellController());
        // Windows display scaling reduces the logical viewport available to
        // Flutter. Using the equivalent logical size keeps pointer hit testing
        // deterministic in the headless test environment.
        tester.view.physicalSize = Size(1366 / scale, 768 / scale);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          GetMaterialApp(home: AppShell(screens: _probeScreens())),
        );
        await tester.pump();

        final compact = 1366 / scale < 1100;
        expect(
          find.byKey(ValueKey(compact ? 'compact-shell' : 'desktop-shell')),
          findsOneWidget,
        );
        final destinations = [
          ...ShellDestination.values.skip(1),
          ShellDestination.dashboard,
        ];
        for (final destination in destinations) {
          if (compact) {
            await tester.tap(find.byKey(const ValueKey('shell-menu-button')));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 400));
          }
          final item = find.byKey(ValueKey('nav-${destination.keyName}'));
          await tester.ensureVisible(item);
          await tester.pump();
          await tester.tap(item);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          expect(controller.selected, destination);
          expect(
            find.byKey(ValueKey('probe-screen-${destination.index}')),
            findsOneWidget,
          );
        }
      },
    );
  }

  testWidgets('unknown routes show a recoverable screen', (tester) async {
    await tester.pumpWidget(
      EuroTechBillingApp(
        initializationError: StateError('test initialization error'),
      ),
    );
    await tester.pump();
    final app = tester.widget<GetMaterialApp>(find.byType(GetMaterialApp));
    expect(app.unknownRoute?.name, '/not-found');
    expect(
      app.getPages?.map((page) => page.name),
      containsAll([
        '/',
        ...ShellDestination.values.map((destination) => destination.route),
      ]),
    );

    await tester.pumpWidget(const MaterialApp(home: RouteErrorScreen()));
    await tester.pump();
    expect(find.text('This section could not be opened'), findsOneWidget);
    expect(find.text('Open dashboard'), findsOneWidget);
  });

  test(
    'initial binding registers feature controllers without duplicates',
    () async {
      sqfliteFfiInit();
      final directory = await Directory.systemTemp.createTemp('et_binding_');
      final database = AppDatabase.forTesting(
        factory: databaseFactoryFfi,
        databasePath: p.join(directory.path, 'billing.sqlite'),
      );
      await database.initialize();
      try {
        final binding = InitialBinding(
          database: database,
          startAutomaticBackup: false,
        );
        expect(binding.dependencies, returnsNormally);
        expect(binding.dependencies, returnsNormally);
        for (final registered in [
          Get.isRegistered<ShellController>(),
          Get.isRegistered<DashboardController>(),
          Get.isRegistered<InvoiceEditorController>(),
          Get.isRegistered<InvoiceHistoryController>(),
          Get.isRegistered<CustomersController>(),
          Get.isRegistered<ProductsController>(),
          Get.isRegistered<PaymentsCreditController>(),
          Get.isRegistered<ReportsController>(),
          Get.isRegistered<SettingsController>(),
        ]) {
          expect(registered, isTrue);
        }
      } finally {
        Get.reset();
        await database.close();
        await directory.delete(recursive: true);
      }
    },
  );
}

List<Widget> _probeScreens() => [
  for (final destination in ShellDestination.values)
    ColoredBox(
      key: ValueKey('probe-screen-${destination.index}'),
      color: Colors.white,
      child: Center(child: Text(destination.label)),
    ),
];

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_theme.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../invoices/presentation/invoice_editor_screen.dart';
import '../../invoices/presentation/invoice_editor_controller.dart';
import '../../invoices/presentation/invoice_history_screen.dart';
import '../../products/presentation/products_screen.dart';
import '../../payments/presentation/payments_credit_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import 'shell_controller.dart';

class AppShell extends GetView<ShellController> {
  const AppShell({super.key});

  static const _items = <(String, IconData)>[
    ('Dashboard', Icons.dashboard_rounded),
    ('New Invoice', Icons.note_add_rounded),
    ('Invoice History', Icons.history_rounded),
    ('Customers', Icons.people_alt_rounded),
    ('Products & Prices', Icons.inventory_2_rounded),
    ('Payments / Credit', Icons.payments_rounded),
    ('Reports', Icons.bar_chart_rounded),
    ('Settings', Icons.settings_rounded),
  ];

  static const _screens = <Widget>[
    DashboardScreen(),
    InvoiceEditorScreen(),
    InvoiceHistoryScreen(),
    CustomersScreen(),
    ProductsScreen(),
    PaymentsCreditScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          Container(
            width: 260,
            color: AppTheme.navy,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(24, 28, 20, 26),
                    child: Row(
                      children: [
                        _BrandMark(),
                        SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EURO TECH',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'EDGING AND CUTTING',
                                style: TextStyle(
                                  color: Color(0xFF9FB3C8),
                                  fontSize: 11,
                                  letterSpacing: .8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF243B53), height: 1),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Obx(
                      () => ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final selected =
                              controller.selectedIndex.value == index;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Material(
                              color: selected
                                  ? const Color(0xFF243B53)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () => _selectPage(context, index),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 13,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        _items[index].$2,
                                        size: 21,
                                        color: selected
                                            ? Colors.white
                                            : const Color(0xFF9FB3C8),
                                      ),
                                      const SizedBox(width: 13),
                                      Text(
                                        _items[index].$1,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFFD9E2EC),
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text(
                      'Offline • Local data',
                      style: TextStyle(color: Color(0xFF829AB1), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Obx(
              () => IndexedStack(
                index: controller.selectedIndex.value,
                children: _screens,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _selectPage(BuildContext context, int index) async {
    if (controller.selectedIndex.value == 1 && index != 1) {
      final editor = Get.find<InvoiceEditorController>();
      if (editor.hasUnsavedChanges) {
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved invoice?'),
            content: const Text(
              'The selected customer, items, and discount have not been saved.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Keep editing'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Discard'),
              ),
            ],
          ),
        );
        if (!(discard ?? false)) return;
        editor.clear(force: true);
      }
    }
    controller.select(index);
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: const Text(
        'ET',
        style: TextStyle(
          color: AppTheme.navy,
          fontWeight: FontWeight.w900,
          fontSize: 17,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

enum ShellDestination {
  dashboard(
    label: 'Dashboard',
    route: '/dashboard',
    icon: Icons.dashboard_rounded,
  ),
  newInvoice(
    label: 'New Invoice',
    route: '/invoices/new',
    icon: Icons.note_add_rounded,
  ),
  invoiceHistory(
    label: 'Invoice History',
    route: '/invoices/history',
    icon: Icons.history_rounded,
  ),
  customers(
    label: 'Customers',
    route: '/customers',
    icon: Icons.people_alt_rounded,
  ),
  products(
    label: 'Products & Prices',
    route: '/products',
    icon: Icons.inventory_2_rounded,
  ),
  paymentsCredit(
    label: 'Payments / Credit',
    route: '/payments-credit',
    icon: Icons.payments_rounded,
  ),
  reports(label: 'Reports', route: '/reports', icon: Icons.bar_chart_rounded),
  settings(
    label: 'Settings & Backup',
    route: '/settings',
    icon: Icons.settings_rounded,
  );

  const ShellDestination({
    required this.label,
    required this.route,
    required this.icon,
  });

  final String label;
  final String route;
  final IconData icon;

  String get keyName => name.replaceAllMapped(
    RegExp(r'([A-Z])'),
    (match) => '-${match.group(1)!.toLowerCase()}',
  );
}

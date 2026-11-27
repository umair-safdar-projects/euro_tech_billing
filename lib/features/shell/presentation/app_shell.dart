import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_theme.dart';
import '../../customers/presentation/customers_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../invoices/presentation/invoice_editor_controller.dart';
import '../../invoices/presentation/invoice_editor_screen.dart';
import '../../invoices/presentation/invoice_history_screen.dart';
import '../../payments/presentation/payments_credit_screen.dart';
import '../../products/presentation/products_screen.dart';
import '../../reports/presentation/reports_screen.dart';
import '../../settings/presentation/settings_screen.dart';
import '../domain/shell_destination.dart';
import 'shell_controller.dart';

class AppShell extends GetView<ShellController> {
  const AppShell({
    super.key,
    this.screens = defaultScreens,
    this.compactBreakpoint = 1100,
  });

  static const defaultScreens = <Widget>[
    DashboardScreen(),
    InvoiceEditorScreen(),
    InvoiceHistoryScreen(),
    CustomersScreen(),
    ProductsScreen(),
    PaymentsCreditScreen(),
    ReportsScreen(),
    SettingsScreen(),
  ];

  final List<Widget> screens;
  final double compactBreakpoint;

  @override
  Widget build(BuildContext context) {
    assert(screens.length == ShellDestination.values.length);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < compactBreakpoint;
        if (compact) {
          return Scaffold(
            key: const ValueKey('compact-shell'),
            appBar: AppBar(
              leading: Builder(
                builder: (context) => IconButton(
                  key: const ValueKey('shell-menu-button'),
                  tooltip: 'Open navigation',
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
              title: Obx(
                () => Column(
                  key: const ValueKey('current-destination-title'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      controller.selected.label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Text(
                      'EURO TECH EDGING AND CUTTING',
                      style: TextStyle(fontSize: 10, letterSpacing: .4),
                    ),
                  ],
                ),
              ),
            ),
            drawer: Drawer(
              width: 290,
              child: _NavigationPanel(
                controller: controller,
                closeOnSelect: true,
                onSelect: (index) => _selectPage(context, index),
              ),
            ),
            body: _content(),
          );
        }
        var collapsed = false;
        return Scaffold(
          key: const ValueKey('desktop-shell'),
          body: StatefulBuilder(
            builder: (context, setState) {
              return Row(
                children: [
                  SizedBox(
                    width: collapsed ? 84 : 260,
                    child: _NavigationPanel(
                      controller: controller,
                      collapsed: collapsed,
                      onToggleCollapsed: () =>
                          setState(() => collapsed = !collapsed),
                      onSelect: (index) => _selectPage(context, index),
                    ),
                  ),
                  Expanded(child: _content()),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _content() => Obx(
    () => IndexedStack(
      key: const ValueKey('feature-stack'),
      index: controller.selectedIndex.value,
      children: screens,
    ),
  );

  Future<void> _selectPage(BuildContext context, int index) async {
    if (controller.selectedIndex.value == ShellDestination.newInvoice.index &&
        index != ShellDestination.newInvoice.index &&
        Get.isRegistered<InvoiceEditorController>()) {
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
    if (index == ShellDestination.newInvoice.index &&
        Get.isRegistered<InvoiceEditorController>()) {
      await Get.find<InvoiceEditorController>().loadLookups();
    }
  }
}

class _NavigationPanel extends StatefulWidget {
  const _NavigationPanel({
    required this.controller,
    required this.onSelect,
    this.closeOnSelect = false,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final ShellController controller;
  final ValueChanged<int> onSelect;
  final bool closeOnSelect;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  State<_NavigationPanel> createState() => _NavigationPanelState();
}

class _NavigationPanelState extends State<_NavigationPanel> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: AppTheme.navy,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _BrandHeader(
            collapsed: widget.collapsed,
            onToggleCollapsed: widget.onToggleCollapsed,
          ),
          const Divider(color: Color(0xFF243B53), height: 1),
          const SizedBox(height: 10),
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: true,
              child: Obx(() {
                final selectedIndex = widget.controller.selectedIndex.value;
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(12, 4, 18, 64),
                  itemCount: ShellDestination.values.length,
                  itemBuilder: (context, index) {
                    final destination = ShellDestination.values[index];
                    final selected = selectedIndex == index;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Tooltip(
                        message: widget.collapsed ? destination.label : '',
                        child: Material(
                          color: selected
                              ? const Color(0xFF243B53)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            key: ValueKey('nav-${destination.keyName}'),
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              if (widget.closeOnSelect) {
                                Scaffold.of(context).closeDrawer();
                              }
                              widget.onSelect(index);
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: widget.collapsed ? 0 : 14,
                                vertical: 13,
                              ),
                              child: Row(
                                mainAxisAlignment: widget.collapsed
                                    ? MainAxisAlignment.center
                                    : MainAxisAlignment.start,
                                children: [
                                  Icon(
                                    destination.icon,
                                    size: 21,
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF9FB3C8),
                                  ),
                                  if (!widget.collapsed) ...[
                                    const SizedBox(width: 13),
                                    Expanded(
                                      child: Text(
                                        destination.label,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: selected
                                              ? Colors.white
                                              : const Color(0xFFD9E2EC),
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
          if (!widget.collapsed)
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 18),
              child: Text(
                'Offline • Local data',
                style: TextStyle(color: Color(0xFF829AB1), fontSize: 12),
              ),
            ),
        ],
      ),
    ),
  );
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.collapsed, this.onToggleCollapsed});

  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            const _BrandMark(),
            if (onToggleCollapsed != null)
              IconButton(
                onPressed: onToggleCollapsed,
                tooltip: 'Expand navigation',
                color: const Color(0xFF9FB3C8),
                icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
              ),
          ],
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 12, 18),
      child: Row(
        children: [
          const _BrandMark(),
          const SizedBox(width: 13),
          const Expanded(
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF9FB3C8),
                    fontSize: 11,
                    letterSpacing: .8,
                  ),
                ),
              ],
            ),
          ),
          if (onToggleCollapsed != null)
            IconButton(
              onPressed: onToggleCollapsed,
              tooltip: 'Collapse navigation',
              color: const Color(0xFF9FB3C8),
              icon: const Icon(Icons.keyboard_double_arrow_left_rounded),
            ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(10),
    child: Image.asset(
      'assets/branding/euro_tech_icon_256.png',
      width: 42,
      height: 42,
      fit: BoxFit.cover,
      semanticLabel: 'Euro Tech company logo',
    ),
  );
}

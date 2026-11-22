import 'dart:async';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../customers/presentation/customers_controller.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../invoices/presentation/invoice_editor_controller.dart';
import '../../invoices/presentation/invoice_history_controller.dart';
import '../../payments/presentation/payments_credit_controller.dart';
import '../../products/presentation/products_controller.dart';
import '../../reports/presentation/reports_controller.dart';
import '../../settings/presentation/settings_controller.dart';
import '../data/backup_service.dart';
import '../domain/backup_models.dart';

class BackupController extends GetxController {
  BackupController(this._service);
  final BackupService _service;

  final status = Rxn<BackupStatus>();
  final isBusy = false.obs;
  final warning = RxnString();

  @override
  void onInit() {
    super.onInit();
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    await load();
    try {
      final created = await _service.runAutomaticBackupIfDue();
      if (created != null) await load();
    } catch (error, stackTrace) {
      warning.value =
          'Automatic backup failed. Open Settings to check the backup destination.';
      _diagnose(error, stackTrace);
    }
  }

  Future<void> load() async {
    try {
      status.value = await _service.loadStatus();
    } catch (error, stackTrace) {
      warning.value = 'Backup status could not be loaded.';
      _diagnose(error, stackTrace);
    }
  }

  Future<void> chooseDestination() async {
    final path = await getDirectoryPath(
      initialDirectory: status.value?.destination,
      confirmButtonText: 'Use for backups',
    );
    if (path == null) return;
    await _run(() async {
      await _service.setDestination(path);
      await load();
      Get.snackbar(
        'Backup folder saved',
        path,
        snackPosition: SnackPosition.BOTTOM,
      );
    }, 'The backup folder could not be saved.');
  }

  Future<void> createManualBackup() => _run(() async {
    final result = await _service.createBackup();
    await load();
    Get.snackbar(
      'Backup created',
      result.path,
      snackPosition: SnackPosition.BOTTOM,
    );
  }, 'The backup could not be created. Check the destination and disk space.');

  Future<BackupMetadata?> chooseRestoreFile() async {
    final file = await openFile(
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'Euro Tech database backup',
          extensions: ['sqlite', 'db'],
        ),
      ],
    );
    if (file == null) return null;
    try {
      return await _service.verify(file.path);
    } catch (error, stackTrace) {
      _showFailure(
        error,
        stackTrace,
        'The selected backup is invalid or unreadable.',
      );
      return null;
    }
  }

  Future<bool> restore(BackupMetadata selected) async {
    var restored = false;
    await _run(
      () async {
        await _service.restore(selected.path);
        await _refreshApplication();
        await load();
        restored = true;
        Get.snackbar(
          'Restore complete',
          'The restored data is now active.',
          snackPosition: SnackPosition.BOTTOM,
        );
      },
      'Restore failed. Your original database has been preserved or recovered.',
    );
    return restored;
  }

  Future<void> _refreshApplication() async {
    if (Get.isRegistered<DashboardController>()) {
      await Get.find<DashboardController>().load();
    }
    if (Get.isRegistered<InvoiceHistoryController>()) {
      await Get.find<InvoiceHistoryController>().load(targetPage: 1);
    }
    if (Get.isRegistered<CustomersController>()) {
      await Get.find<CustomersController>().load();
    }
    if (Get.isRegistered<ProductsController>()) {
      await Get.find<ProductsController>().load();
    }
    if (Get.isRegistered<PaymentsCreditController>()) {
      await Get.find<PaymentsCreditController>().refreshAll(targetPage: 1);
    }
    if (Get.isRegistered<SettingsController>()) {
      await Get.find<SettingsController>().load();
    }
    if (Get.isRegistered<ReportsController>()) {
      await Get.find<ReportsController>().load();
    }
    if (Get.isRegistered<InvoiceEditorController>()) {
      final editor = Get.find<InvoiceEditorController>();
      editor.clear(force: true);
      await editor.loadLookups();
    }
  }

  Future<void> _run(Future<void> Function() action, String fallback) async {
    if (isBusy.value) return;
    isBusy.value = true;
    warning.value = null;
    try {
      await action();
    } catch (error, stackTrace) {
      _showFailure(error, stackTrace, fallback);
    } finally {
      isBusy.value = false;
    }
  }

  void _showFailure(Object error, StackTrace stackTrace, String fallback) {
    final message = error is BackupException ? error.message : fallback;
    warning.value = message;
    Get.snackbar(
      'Backup operation failed',
      message,
      snackPosition: SnackPosition.BOTTOM,
    );
    _diagnose(error, stackTrace);
  }

  void _diagnose(Object error, StackTrace stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'backup and restore',
      ),
    );
  }
}

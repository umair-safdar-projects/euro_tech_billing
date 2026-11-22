import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../data/report_repository.dart';
import '../domain/report_models.dart';
import '../services/report_export_service.dart';

class ReportsController extends GetxController {
  ReportsController(this._repository, this._export);
  final ReportRepository _repository;
  final ReportExportService _export;

  final report = Rxn<ReportSnapshot>();
  final isLoading = false.obs;
  final errorMessage = RxnString();
  late DateTime from;
  late DateTime to;

  @override
  void onInit() {
    super.onInit();
    setThisMonth(load: false);
    load();
  }

  void setToday({bool load = true}) {
    from = to = DateTime.now();
    if (load) this.load();
  }

  void setThisMonth({bool load = true}) {
    final now = DateTime.now();
    from = DateTime(now.year, now.month);
    to = DateTime(now.year, now.month + 1, 0);
    if (load) this.load();
  }

  Future<void> chooseRange(BuildContext context) async {
    final selected = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(start: from, end: to),
    );
    if (selected == null) return;
    from = selected.start;
    to = selected.end;
    await load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      report.value = await _repository.load(ReportRange(from, to));
    } catch (error, stackTrace) {
      errorMessage.value =
          'Reports could not be loaded. Try refreshing the screen.';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'reports',
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> exportCsv() async {
    final value = report.value;
    if (value == null) return;
    await _save(
      extension: 'csv',
      label: 'CSV spreadsheet',
      mimeType: 'text/csv',
      bytes: Uint8List.fromList(
        utf8.encode('\ufeff${_export.buildCsv(value)}'),
      ),
    );
  }

  Future<void> exportPdf() async {
    final value = report.value;
    if (value == null) return;
    await _save(
      extension: 'pdf',
      label: 'PDF document',
      mimeType: 'application/pdf',
      bytes: await _export.buildPdf(value),
    );
  }

  Future<void> _save({
    required String extension,
    required String label,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      final name =
          'euro-tech-report-${DateFormat('yyyyMMdd').format(from)}-${DateFormat('yyyyMMdd').format(to)}.$extension';
      final location = await getSaveLocation(
        suggestedName: name,
        acceptedTypeGroups: [
          XTypeGroup(
            label: label,
            extensions: [extension],
            mimeTypes: [mimeType],
          ),
        ],
      );
      if (location == null) return;
      await XFile.fromData(
        bytes,
        mimeType: mimeType,
        name: name,
      ).saveTo(location.path);
      Get.snackbar(
        'Report exported',
        location.path,
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (error, stackTrace) {
      Get.snackbar(
        'Export failed',
        'The report could not be written to that location. Check folder permissions and free disk space.',
        snackPosition: SnackPosition.BOTTOM,
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'report export',
        ),
      );
    }
  }
}

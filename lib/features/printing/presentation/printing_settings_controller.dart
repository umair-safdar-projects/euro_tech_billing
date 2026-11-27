import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/printing_settings_repository.dart';
import '../domain/printing_models.dart';

class PrintingSettingsController extends GetxController {
  PrintingSettingsController(this._repository);
  final PrintingSettingsRepository _repository;
  final paper = InvoicePaper.a5.obs;
  final placement = A4Placement.centered.obs;
  final showLogo = true.obs;
  final showEmail = true.obs;
  final footer = TextEditingController();
  final isLoading = true.obs;
  final isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final value = await _repository.load();
      paper.value = value.paper;
      placement.value = value.a4Placement;
      showLogo.value = value.showLogo;
      showEmail.value = value.showEmail;
      footer.text = value.footerMessage;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> save() async {
    isSaving.value = true;
    try {
      await _repository.save(
        PrintingSettings(
          paper: paper.value,
          a4Placement: placement.value,
          footerMessage: footer.text,
          showLogo: showLogo.value,
          showEmail: showEmail.value,
        ),
      );
      Get.snackbar(
        'Printing settings saved',
        'New previews, print jobs, and exports will use these preferences.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    footer.dispose();
    super.onClose();
  }
}

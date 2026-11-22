import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/company_settings_repository.dart';
import '../domain/company_settings.dart';

class SettingsController extends GetxController {
  SettingsController(this._repository);

  final CompanySettingsRepository _repository;
  final formKey = GlobalKey<FormState>();
  final companyName = TextEditingController();
  final ownerName = TextEditingController();
  final primaryPhone = TextEditingController();
  final secondaryPhone = TextEditingController();
  final contactName = TextEditingController();
  final contactPhone = TextEditingController();
  final email = TextEditingController();
  final address = TextEditingController();
  final isLoading = true.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  final logoPath = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final settings = await _repository.load();
      companyName.text = settings.companyName;
      ownerName.text = settings.ownerName;
      primaryPhone.text = settings.primaryPhone;
      secondaryPhone.text = settings.secondaryPhone;
      contactName.text = settings.additionalContactName;
      contactPhone.text = settings.additionalContactPhone;
      email.text = settings.email;
      address.text = settings.address;
      logoPath.value = settings.logoPath;
    } catch (error, stackTrace) {
      errorMessage.value =
          'Company settings could not be read from local storage.';
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'company settings',
        ),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    isSaving.value = true;
    try {
      await _repository.save(
        CompanySettings(
          companyName: companyName.text,
          ownerName: ownerName.text,
          primaryPhone: primaryPhone.text,
          secondaryPhone: secondaryPhone.text,
          additionalContactName: contactName.text,
          additionalContactPhone: contactPhone.text,
          email: email.text,
          address: address.text,
          logoPath: logoPath.value,
        ),
      );
      Get.snackbar(
        'Settings saved',
        'Company information was updated successfully.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    } catch (error, stackTrace) {
      Get.snackbar(
        'Unable to save settings',
        'Check the application data folder permissions and available disk space.',
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'company settings',
        ),
      );
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    for (final controller in [
      companyName,
      ownerName,
      primaryPhone,
      secondaryPhone,
      contactName,
      contactPhone,
      email,
      address,
    ]) {
      controller.dispose();
    }
    super.onClose();
  }
}

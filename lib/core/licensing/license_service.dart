import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:get/get.dart';

import 'license_code.dart';

class LicenseService extends GetxService {
  final isActive = false.obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();
  final pendingCode = ''.obs;
  final deviceCode = ''.obs;
  final licensedCompany = RxnString();

  Future<LicenseService> init() async {
    deviceCode.value = _deviceCode();
    await load();
    return this;
  }

  Future<void> load() async {
    if (deviceCode.value.isEmpty) {
      deviceCode.value = _deviceCode();
    }
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final file = await _licenseFile();
      if (!await file.exists()) {
        isActive.value = false;
        licensedCompany.value = null;
        return;
      }
      final document = jsonDecode(await file.readAsString());
      final code = document is Map<String, Object?>
          ? document['code'] as String?
          : null;
      final result = _verify(code);
      isActive.value = result != null;
      licensedCompany.value = result?.company;
      if (result == null) {
        errorMessage.value = 'The saved activation is invalid for this device.';
      }
    } catch (_) {
      isActive.value = false;
      licensedCompany.value = null;
      errorMessage.value = 'The activation file could not be read.';
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> activate(String code) async {
    if (deviceCode.value.isEmpty) {
      deviceCode.value = _deviceCode();
    }
    errorMessage.value = null;
    final result = _verify(code);
    if (result == null) {
      isActive.value = false;
      licensedCompany.value = null;
      errorMessage.value =
          'Activation code is invalid or belongs to another computer.';
      return false;
    }
    try {
      final file = await _licenseFile();
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'format': LicenseCode.format,
          'code': code.trim(),
          'activated_at': DateTime.now().toUtc().toIso8601String(),
        }),
      );
      isActive.value = true;
      licensedCompany.value = result.company;
      pendingCode.value = '';
      return true;
    } catch (_) {
      errorMessage.value =
          'The activation could not be saved on this computer.';
      return false;
    }
  }

  Future<void> requireActive() async {
    if (isLoading.value || deviceCode.value.isEmpty) await load();
    if (!isActive.value) {
      throw const FormatException(
        'Lifetime activation is required before saving invoices. Open Settings and enter your activation code.',
      );
    }
  }

  String _deviceCode() {
    final raw = [
      Platform.operatingSystem,
      Platform.localHostname,
      Platform.environment['COMPUTERNAME'] ?? '',
      Platform.environment['PROCESSOR_IDENTIFIER'] ?? '',
    ].join('|');
    return sha256
        .convert(utf8.encode(raw))
        .toString()
        .substring(0, 16)
        .toUpperCase();
  }

  LicensePayload? _verify(String? rawCode) =>
      LicenseCode.verify(rawCode, deviceCode: deviceCode.value);

  Future<File> _licenseFile() async {
    final directory = await getApplicationSupportDirectory();
    return File(p.join(directory.path, 'EuroTechBilling', 'license.json'));
  }
}

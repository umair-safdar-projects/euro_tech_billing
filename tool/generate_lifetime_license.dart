import 'dart:io';

import 'package:eurotechbilling/core/licensing/license_code.dart';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/generate_lifetime_license.dart "Company name" DEVICECODE',
    );
    exitCode = 64;
    return;
  }

  final company = args[0].trim();
  final device = args[1].trim().toUpperCase();
  if (company.isEmpty || !RegExp(r'^[A-F0-9]{16}$').hasMatch(device)) {
    stderr.writeln(
      'Company must be non-empty and device code must be 16 hex characters.',
    );
    exitCode = 64;
    return;
  }

  stdout.writeln(LicenseCode.issue(company: company, deviceCode: device));
}

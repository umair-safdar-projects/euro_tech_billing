import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Offline lifetime-license format shared by the app and the vendor tool.
///
/// This is an activation deterrent, not a tamper-proof DRM system: the signing
/// secret is necessarily present in an offline desktop binary. Payment terms
/// and manual re-issue remain the source of truth.
class LicenseCode {
  static const format = 'ETL1';
  static const _secret = 'euro-tech-lifetime-license-v1';

  static String issue({required String company, required String deviceCode}) {
    final normalizedCompany = company.trim();
    final normalizedDevice = deviceCode.trim().toUpperCase();
    final encodedCompany = base64Url
        .encode(utf8.encode(normalizedCompany))
        .replaceAll('=', '');
    final signature = _signature(normalizedCompany, normalizedDevice);
    return '$format.$encodedCompany.$normalizedDevice.$signature';
  }

  static LicensePayload? verify(String? rawCode, {required String deviceCode}) {
    if (rawCode == null || rawCode.trim().isEmpty) return null;
    final parts = rawCode.trim().split('.');
    if (parts.length != 4 || parts[0] != format) return null;
    try {
      final company = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final expected = _signature(company, parts[2]);
      if (parts[2] != deviceCode || parts[3] != expected) return null;
      if (company.trim().isEmpty) return null;
      return LicensePayload(company: company);
    } catch (_) {
      return null;
    }
  }

  static String _signature(String company, String deviceCode) => sha256
      .convert(utf8.encode('$company|$deviceCode|$_secret'))
      .toString()
      .substring(0, 32)
      .toUpperCase();
}

class LicensePayload {
  const LicensePayload({required this.company});

  final String company;
}

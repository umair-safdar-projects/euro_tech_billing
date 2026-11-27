import 'package:flutter_test/flutter_test.dart';

import 'package:eurotechbilling/core/licensing/license_code.dart';

void main() {
  test('lifetime code verifies only for its issued device', () {
    const device = 'ABCDEF0123456789';
    final code = LicenseCode.issue(
      company: 'EURO TECH EDGING AND CUTTING',
      deviceCode: device,
    );

    expect(
      LicenseCode.verify(code, deviceCode: device)?.company,
      'EURO TECH EDGING AND CUTTING',
    );
    expect(LicenseCode.verify(code, deviceCode: '0123456789ABCDEF'), isNull);
    expect(LicenseCode.verify('$code-x', deviceCode: device), isNull);
  });
}

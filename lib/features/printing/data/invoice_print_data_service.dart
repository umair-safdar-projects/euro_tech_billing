import 'dart:io';

import 'package:flutter/services.dart';

import '../../invoices/data/invoice_repository.dart';
import '../../settings/data/company_settings_repository.dart';
import '../../settings/domain/company_settings.dart';
import '../domain/printing_models.dart';
import 'printing_settings_repository.dart';

class InvoicePrintDataService {
  static const defaultLogoAsset = 'assets/branding/euro_tech_logo.png';

  InvoicePrintDataService(this._invoices, this._company, this._settings);

  final InvoiceRepository _invoices;
  final CompanySettingsRepository _company;
  final PrintingSettingsRepository _settings;

  Future<InvoicePrintModel> load(int invoiceId) async {
    final invoice = await _invoices.detail(invoiceId);
    if (invoice == null) throw StateError('Invoice could not be found.');
    final currentCompany = await _company.load();
    final snapshot = invoice.companyIdentity;
    final company = snapshot == null
        ? currentCompany
        : CompanySettings(
            companyName: snapshot.companyName,
            ownerName: snapshot.ownerName,
            primaryPhone: snapshot.primaryPhone,
            secondaryPhone: snapshot.secondaryPhone,
            additionalContactName: snapshot.additionalContactName,
            additionalContactPhone: snapshot.additionalContactPhone,
            email: snapshot.email,
            address: snapshot.address,
            logoPath: currentCompany.logoPath,
          );
    final settings = await _settings.load();
    final logo = settings.showLogo ? await _loadLogo(company.logoPath) : null;
    return InvoicePrintModel(
      company: company,
      invoice: invoice,
      settings: settings,
      balanceAsOf: DateTime.now(),
      logoBytes: logo,
    );
  }

  Future<Uint8List?> _loadLogo(String? configuredPath) async {
    final path = configuredPath?.trim();
    if (path != null) {
      if (path.isEmpty) return null;
      if (path.startsWith('asset:')) {
        return _loadAsset(path.substring('asset:'.length));
      }
      try {
        final file = File(path);
        if (await file.exists()) return await file.readAsBytes();
      } catch (_) {
        // Fall through to the bundled company mark for stale paths.
      }
    }
    return _loadAsset(defaultLogoAsset);
  }

  Future<Uint8List?> _loadAsset(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }
}

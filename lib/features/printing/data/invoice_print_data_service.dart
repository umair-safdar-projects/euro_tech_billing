import 'dart:io';
import 'dart:typed_data';

import '../../invoices/data/invoice_repository.dart';
import '../../settings/data/company_settings_repository.dart';
import '../../settings/domain/company_settings.dart';
import '../domain/printing_models.dart';
import 'printing_settings_repository.dart';

class InvoicePrintDataService {
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
    Uint8List? logo;
    final logoPath = company.logoPath?.trim();
    if (logoPath != null && logoPath.isNotEmpty) {
      try {
        final file = File(logoPath);
        if (await file.exists()) logo = await file.readAsBytes();
      } catch (_) {
        logo = null;
      }
    }
    return InvoicePrintModel(
      company: company,
      invoice: invoice,
      settings: settings,
      balanceAsOf: DateTime.now(),
      logoBytes: logo,
    );
  }
}

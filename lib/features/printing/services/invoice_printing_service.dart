import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:printing/printing.dart';

import '../data/invoice_print_data_service.dart';
import '../domain/printing_models.dart';
import 'invoice_pdf_service.dart';

class InvoicePrintingService {
  InvoicePrintingService(this._data, this._pdf);
  final InvoicePrintDataService _data;
  final InvoicePdfService _pdf;

  Future<(InvoicePrintModel, Uint8List)> generate(int invoiceId) async {
    final model = await _data.load(invoiceId);
    return (model, await _pdf.generate(model));
  }

  Future<bool> printInvoice(int invoiceId) async {
    final result = await generate(invoiceId);
    return Printing.layoutPdf(
      name: 'Invoice ${result.$1.invoice.invoiceNumber}',
      format: _pdf.layoutFor(result.$1.settings).pageFormat,
      dynamicLayout: false,
      onLayout: (_) async => result.$2,
    );
  }

  Future<String?> exportPdf(int invoiceId) async {
    final result = await generate(invoiceId);
    final fileName = '${result.$1.invoice.invoiceNumber}.pdf';
    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF document',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
        ),
      ],
    );
    if (location == null) return null;
    await XFile.fromData(
      result.$2,
      mimeType: 'application/pdf',
      name: fileName,
    ).saveTo(location.path);
    return location.path;
  }
}

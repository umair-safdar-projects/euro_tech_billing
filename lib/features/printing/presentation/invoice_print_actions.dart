import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:printing/printing.dart';

import '../services/invoice_printing_service.dart';
import '../services/invoice_pdf_service.dart';

Future<void> showInvoicePreview(BuildContext context, int invoiceId) async {
  try {
    final generated = await Get.find<InvoicePrintingService>().generate(
      invoiceId,
    );
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 850),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Preview ${generated.$1.invoice.invoiceNumber}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: PdfPreview(
                  build: (_) async => generated.$2,
                  pdfFileName: '${generated.$1.invoice.invoiceNumber}.pdf',
                  canChangePageFormat: false,
                  canChangeOrientation: false,
                  canDebug: false,
                  allowPrinting: false,
                  allowSharing: false,
                  dynamicLayout: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  } catch (error) {
    _showError('Unable to preview invoice', error);
  }
}

Future<void> printInvoice(int invoiceId) async {
  try {
    final service = Get.find<InvoicePrintingService>();
    final accepted = await service.printInvoice(invoiceId);
    if (!accepted) {
      Get.snackbar(
        'Print job not submitted',
        'If you did not cancel, check that an installed printer is available.',
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    }
  } catch (error) {
    _showError('Unable to print invoice', error);
  }
}

Future<void> exportInvoicePdf(int invoiceId) async {
  try {
    final path = await Get.find<InvoicePrintingService>().exportPdf(invoiceId);
    if (path != null) {
      Get.snackbar(
        'PDF exported',
        path,
        snackPosition: SnackPosition.BOTTOM,
        margin: const EdgeInsets.all(20),
      );
    }
  } catch (error) {
    _showError('Unable to export invoice', error);
  }
}

void _showError(String title, Object error) {
  final message = switch (error) {
    InvoicePdfException pdfError => pdfError.message,
    _ when title.contains('print') =>
      'The print job could not be started. Confirm that a printer is installed and available, or export the PDF instead.',
    _ when title.contains('export') =>
      'The PDF could not be written to that location. Check folder permissions and free disk space.',
    _ =>
      'The invoice PDF could not be generated. Check the invoice and logo settings, then try again.',
  };
  Get.snackbar(
    title,
    message,
    snackPosition: SnackPosition.BOTTOM,
    margin: const EdgeInsets.all(20),
  );
  FlutterError.reportError(
    FlutterErrorDetails(exception: error, library: 'invoice printing'),
  );
}

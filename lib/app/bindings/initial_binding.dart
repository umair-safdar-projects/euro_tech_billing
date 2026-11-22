import 'package:get/get.dart';

import '../../core/database/app_database.dart';
import '../../features/customers/data/customer_repository.dart';
import '../../features/customers/presentation/customers_controller.dart';
import '../../features/credit/data/credit_repository.dart';
import '../../features/dashboard/presentation/dashboard_controller.dart';
import '../../features/invoices/data/invoice_repository.dart';
import '../../features/invoices/presentation/invoice_editor_controller.dart';
import '../../features/invoices/presentation/invoice_history_controller.dart';
import '../../features/products/data/product_repository.dart';
import '../../features/products/presentation/products_controller.dart';
import '../../features/settings/data/company_settings_repository.dart';
import '../../features/payments/data/payment_repository.dart';
import '../../features/payments/presentation/payments_credit_controller.dart';
import '../../features/printing/data/invoice_print_data_service.dart';
import '../../features/printing/data/printing_settings_repository.dart';
import '../../features/printing/presentation/printing_settings_controller.dart';
import '../../features/printing/services/invoice_pdf_service.dart';
import '../../features/printing/services/invoice_printing_service.dart';
import '../../features/settings/presentation/settings_controller.dart';
import '../../features/shell/presentation/shell_controller.dart';
import '../../features/backups/data/backup_service.dart';
import '../../features/backups/presentation/backup_controller.dart';
import '../../features/reports/data/report_repository.dart';
import '../../features/reports/presentation/reports_controller.dart';
import '../../features/reports/services/report_export_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(AppDatabase.instance, permanent: true);
    Get.lazyPut(() => CompanySettingsRepository(Get.find()), fenix: true);
    Get.lazyPut(() => ProductRepository(Get.find()), fenix: true);
    Get.lazyPut(() => CustomerRepository(Get.find()), fenix: true);
    Get.lazyPut(() => InvoiceRepository(Get.find()), fenix: true);
    Get.lazyPut(() => PaymentRepository(Get.find()), fenix: true);
    Get.lazyPut(() => ReportRepository(Get.find()), fenix: true);
    Get.lazyPut(() => ReportExportService(), fenix: true);
    Get.put(BackupService(Get.find()), permanent: true);
    Get.lazyPut(() => PrintingSettingsRepository(Get.find()), fenix: true);
    Get.lazyPut(
      () => InvoicePrintDataService(Get.find(), Get.find(), Get.find()),
      fenix: true,
    );
    Get.lazyPut(() => InvoicePdfService(), fenix: true);
    Get.lazyPut(
      () => InvoicePrintingService(Get.find(), Get.find()),
      fenix: true,
    );
    Get.lazyPut(
      () => CreditRepository(Get.find(), Get.find(), Get.find()),
      fenix: true,
    );
    Get.put(ShellController(), permanent: true);
    Get.lazyPut(() => SettingsController(Get.find()), fenix: true);
    Get.lazyPut(() => ProductsController(Get.find()), fenix: true);
    Get.lazyPut(() => CustomersController(Get.find(), Get.find()), fenix: true);
    Get.lazyPut(
      () => InvoiceEditorController(Get.find(), Get.find(), Get.find()),
      fenix: true,
    );
    Get.lazyPut(() => InvoiceHistoryController(Get.find()), fenix: true);
    Get.lazyPut(
      () => PaymentsCreditController(Get.find(), Get.find()),
      fenix: true,
    );
    Get.lazyPut(() => DashboardController(Get.find()), fenix: true);
    Get.lazyPut(() => ReportsController(Get.find(), Get.find()), fenix: true);
    Get.lazyPut(() => PrintingSettingsController(Get.find()), fenix: true);
    Get.put(BackupController(Get.find()), permanent: true);
  }
}

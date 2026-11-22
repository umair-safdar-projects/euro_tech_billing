import 'package:get/get.dart';

import '../../../core/utils/submission_token.dart';
import '../../credit/data/credit_repository.dart';
import '../../credit/domain/credit_models.dart';
import '../../customers/presentation/customers_controller.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../invoices/presentation/invoice_history_controller.dart';
import '../data/payment_repository.dart';
import '../domain/payment_models.dart';

class PaymentsCreditController extends GetxController {
  PaymentsCreditController(this._payments, this._credit);

  final PaymentRepository _payments;
  final CreditRepository _credit;
  final payments = <PaymentRecord>[].obs;
  final outstandingCustomers = <CustomerCredit>[].obs;
  final creditSummary = Rxn<CreditSummary>();
  final totalPayments = 0.obs;
  final collectedMinor = 0.obs;
  final page = 1.obs;
  final search = ''.obs;
  final from = Rxn<DateTime>();
  final to = Rxn<DateTime>();
  final isLoading = false.obs;
  static const pageSize = 20;

  int get totalPages => totalPayments.value == 0
      ? 1
      : (totalPayments.value + pageSize - 1) ~/ pageSize;

  @override
  void onInit() {
    super.onInit();
    refreshAll();
  }

  Future<void> refreshAll({int? targetPage}) async {
    if (targetPage != null) page.value = targetPage;
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _payments.list(
          search: search.value,
          from: from.value,
          to: to.value,
          page: page.value,
          pageSize: pageSize,
        ),
        _credit.summary(),
        _credit.outstandingCustomers(search: search.value),
      ]);
      final paymentPage = results[0] as PaymentPage;
      payments.assignAll(paymentPage.items);
      totalPayments.value = paymentPage.total;
      collectedMinor.value = paymentPage.collectedMinor;
      creditSummary.value = results[1] as CreditSummary;
      outstandingCustomers.assignAll(results[2] as List<CustomerCredit>);
    } finally {
      isLoading.value = false;
    }
  }

  Future<PaymentRecord> record({
    required int invoiceId,
    required int amountMinor,
    required String method,
    required DateTime date,
    String notes = '',
    String reference = '',
    String? token,
  }) async {
    final result = await _payments.record(
      PaymentInput(
        invoiceId: invoiceId,
        amountMinor: amountMinor,
        method: method,
        paymentDate: date,
        saveToken: token ?? SubmissionToken.create(),
        notes: notes,
        reference: reference,
      ),
    );
    await refreshAll(targetPage: 1);
    if (Get.isRegistered<InvoiceHistoryController>()) {
      await Get.find<InvoiceHistoryController>().load();
    }
    if (Get.isRegistered<DashboardController>()) {
      await Get.find<DashboardController>().load();
    }
    if (Get.isRegistered<CustomersController>()) {
      await Get.find<CustomersController>().load();
    }
    return result;
  }

  Future<List<InvoiceBalance>> payableInvoices(String search) =>
      _payments.payableInvoices(search: search);
  Future<InvoiceBalance?> balance(int invoiceId) =>
      _payments.invoiceBalance(invoiceId);
  Future<PaymentRecord?> detail(int id) => _payments.detail(id);
  Future<CustomerLedger?> ledger(int customerId) => _credit.ledger(customerId);
}

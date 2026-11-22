import 'package:get/get.dart';

import '../../../core/utils/submission_token.dart';
import '../../invoices/data/invoice_repository.dart';
import '../../invoices/domain/invoice_models.dart';
import '../data/customer_repository.dart';
import '../domain/customer.dart';

class CustomersController extends GetxController {
  CustomersController(this._repository, this._invoiceRepository);

  final CustomerRepository _repository;
  final InvoiceRepository _invoiceRepository;
  final customers = <Customer>[].obs;
  final selected = Rxn<Customer>();
  final history = <InvoiceListItem>[].obs;
  final historyPage = 1.obs;
  final historyTotal = 0.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  String _query = '';

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load([String? query]) async {
    if (query != null) _query = query;
    isLoading.value = true;
    try {
      customers.assignAll(await _repository.search(_query));
      final current = selected.value;
      if (current != null) {
        selected.value = await _repository.find(current.id);
        await loadHistory(current.id);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<Customer> create(CustomerInput input, {String? token}) async {
    isSaving.value = true;
    try {
      final customer = await _repository.create(
        input,
        saveToken: token ?? SubmissionToken.create(),
      );
      await load();
      await select(customer);
      return customer;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> updateCustomer(int id, CustomerInput input) async {
    isSaving.value = true;
    try {
      await _repository.update(id, input);
      await load();
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> select(Customer customer) async {
    selected.value = customer;
    historyPage.value = 1;
    await loadHistory(customer.id);
  }

  int get historyTotalPages =>
      historyTotal.value == 0 ? 1 : (historyTotal.value + 19) ~/ 20;

  Future<void> loadHistory(int customerId, {int? targetPage}) async {
    if (targetPage != null) historyPage.value = targetPage;
    final result = await _invoiceRepository.list(
      customerId: customerId,
      page: historyPage.value,
      pageSize: 20,
    );
    history.assignAll(result.items);
    historyTotal.value = result.total;
  }
}

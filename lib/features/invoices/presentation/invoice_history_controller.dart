import 'package:get/get.dart';

import '../data/invoice_repository.dart';
import '../domain/invoice_models.dart';

class InvoiceHistoryController extends GetxController {
  InvoiceHistoryController(this._repository);

  final InvoiceRepository _repository;
  final invoices = <InvoiceListItem>[].obs;
  final isLoading = false.obs;
  final total = 0.obs;
  final page = 1.obs;
  final search = ''.obs;
  final from = Rxn<DateTime>();
  final to = Rxn<DateTime>();
  static const pageSize = 20;

  int get totalPages =>
      total.value == 0 ? 1 : (total.value + pageSize - 1) ~/ pageSize;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load({int? targetPage}) async {
    if (targetPage != null) page.value = targetPage;
    isLoading.value = true;
    try {
      final result = await _repository.list(
        search: search.value,
        from: from.value,
        to: to.value,
        page: page.value,
        pageSize: pageSize,
      );
      invoices.assignAll(result.items);
      total.value = result.total;
    } finally {
      isLoading.value = false;
    }
  }

  Future<InvoiceDetail?> detail(int id) => _repository.detail(id);

  void setRange(DateTimeRangeValue? range) {
    from.value = range?.from;
    to.value = range?.to;
    load(targetPage: 1);
  }
}

class DateTimeRangeValue {
  const DateTimeRangeValue(this.from, this.to);
  final DateTime from;
  final DateTime to;
}

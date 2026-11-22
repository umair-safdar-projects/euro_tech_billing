import 'package:get/get.dart';

import '../../../core/utils/currency.dart';
import '../../../core/utils/submission_token.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../dashboard/presentation/dashboard_controller.dart';
import '../../payments/presentation/payments_credit_controller.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice_calculator.dart';
import '../domain/invoice_models.dart';

class EditableInvoiceLine {
  EditableInvoiceLine({
    this.productId,
    required this.description,
    required this.unit,
    required this.quantityText,
    required this.priceText,
  });
  final int? productId;
  String description;
  String unit;
  String quantityText;
  String priceText;

  InvoiceLineInput toInput() {
    final quantity = int.tryParse(quantityText.trim());
    final price = Currency.parseRupees(priceText);
    if (quantity == null) {
      throw const FormatException('Quantity must be a positive whole number.');
    }
    if (price == null) {
      throw const FormatException('Enter a valid non-negative price.');
    }
    return InvoiceLineInput(
      productId: productId,
      description: description,
      quantity: quantity,
      unit: unit,
      unitPriceMinor: price,
    );
  }
}

class InvoiceEditorController extends GetxController {
  InvoiceEditorController(
    this._invoiceRepository,
    this._customerRepository,
    this._productRepository,
  );

  final InvoiceRepository _invoiceRepository;
  final CustomerRepository _customerRepository;
  final ProductRepository _productRepository;
  final customers = <Customer>[].obs;
  final products = <Product>[].obs;
  final selectedCustomer = Rxn<Customer>();
  final lines = <EditableInvoiceLine>[].obs;
  final discountText = '0'.obs;
  final subtotalMinor = 0.obs;
  final discountMinor = 0.obs;
  final grandTotalMinor = 0.obs;
  final validationMessage = RxnString();
  final paymentMode = 'pay_later'.obs;
  final paymentMethod = 'cash'.obs;
  final initialPaymentText = ''.obs;
  final isLoading = true.obs;
  final isSaving = false.obs;
  String _saveToken = SubmissionToken.create();

  @override
  void onInit() {
    super.onInit();
    loadLookups();
  }

  Future<void> loadLookups() async {
    isLoading.value = true;
    try {
      customers.assignAll(await _customerRepository.search('', limit: 500));
      products.assignAll(await _productRepository.getActive());
    } finally {
      isLoading.value = false;
    }
  }

  void selectCustomer(Customer? customer) => selectedCustomer.value = customer;

  void addProduct(Product product) {
    lines.add(
      EditableInvoiceLine(
        productId: product.id,
        description: product.name,
        unit: product.unit,
        quantityText: '1',
        priceText: product.defaultPriceMinor == null
            ? ''
            : _minorForInput(product.defaultPriceMinor!),
      ),
    );
    recalculate();
  }

  void addCustomLine() {
    lines.add(
      EditableInvoiceLine(
        productId: null,
        description: '',
        unit: 'piece',
        quantityText: '1',
        priceText: '',
      ),
    );
    recalculate();
  }

  void removeLine(int index) {
    lines.removeAt(index);
    recalculate();
  }

  void recalculate() {
    try {
      final items = lines.map((line) => line.toInput()).toList(growable: false);
      final discount = Currency.parseRupees(discountText.value);
      if (discount == null) {
        throw const FormatException('Enter a valid discount.');
      }
      if (items.isEmpty) {
        subtotalMinor.value = 0;
        discountMinor.value = discount;
        grandTotalMinor.value = 0;
        validationMessage.value = null;
        return;
      }
      final totals = InvoiceCalculator.calculate(items, discount);
      subtotalMinor.value = totals.subtotalMinor;
      discountMinor.value = totals.discountMinor;
      grandTotalMinor.value = totals.grandTotalMinor;
      validationMessage.value = null;
    } catch (error) {
      validationMessage.value = error is FormatException
          ? error.message
          : error.toString();
    }
  }

  int? lineTotalMinor(EditableInvoiceLine line) {
    try {
      return InvoiceCalculator.calculate([line.toInput()], 0).lineTotals.single;
    } catch (_) {
      return null;
    }
  }

  Future<SavedInvoice> save({bool startNew = false}) async {
    if (isSaving.value) {
      throw StateError('An invoice save is already in progress.');
    }
    final customer = selectedCustomer.value;
    final items = lines.map((line) => line.toInput()).toList(growable: false);
    final discount = Currency.parseRupees(discountText.value);
    if (discount == null) {
      throw const FormatException('Enter a valid discount.');
    }
    final totals = InvoiceCalculator.calculate(items, discount);
    InitialPaymentInput? initialPayment;
    if (paymentMode.value != 'pay_later') {
      final amount = paymentMode.value == 'full'
          ? totals.grandTotalMinor
          : Currency.parseRupees(initialPaymentText.value);
      if (amount == null || amount <= 0) {
        throw const FormatException(
          'Initial payment must be greater than zero.',
        );
      }
      if (paymentMode.value == 'partial' && amount >= totals.grandTotalMinor) {
        throw const FormatException(
          'A partial payment must be smaller than the grand total.',
        );
      }
      initialPayment = InitialPaymentInput(
        amountMinor: amount,
        method: paymentMethod.value,
        paymentDate: DateTime.now(),
        saveToken: '$_saveToken:initial-payment',
      );
    }
    isSaving.value = true;
    try {
      final saved = await _invoiceRepository.save(
        InvoiceSaveInput(
          customerId: customer?.id,
          issueDate: DateTime.now(),
          items: items,
          discountMinor: discount,
          saveToken: _saveToken,
          initialPayment: initialPayment,
        ),
      );
      if (Get.isRegistered<DashboardController>()) {
        await Get.find<DashboardController>().load();
      }
      if (Get.isRegistered<PaymentsCreditController>()) {
        await Get.find<PaymentsCreditController>().refreshAll(targetPage: 1);
      }
      if (startNew) clear(force: true);
      return saved;
    } finally {
      isSaving.value = false;
    }
  }

  bool get hasUnsavedChanges =>
      selectedCustomer.value != null ||
      lines.isNotEmpty ||
      discountText.value != '0' ||
      paymentMode.value != 'pay_later';

  void clear({bool force = false}) {
    selectedCustomer.value = null;
    lines.clear();
    discountText.value = '0';
    subtotalMinor.value = 0;
    discountMinor.value = 0;
    grandTotalMinor.value = 0;
    validationMessage.value = null;
    paymentMode.value = 'pay_later';
    paymentMethod.value = 'cash';
    initialPaymentText.value = '';
    _saveToken = SubmissionToken.create();
  }

  String _minorForInput(int value) => value.remainder(100) == 0
      ? (value ~/ 100).toString()
      : '${value ~/ 100}.${value.remainder(100).toString().padLeft(2, '0')}';
}

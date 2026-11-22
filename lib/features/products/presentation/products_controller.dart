import 'package:get/get.dart';

import '../../../core/utils/currency.dart';
import '../data/product_repository.dart';
import '../domain/product.dart';

class ProductsController extends GetxController {
  ProductsController(this._repository);

  final ProductRepository _repository;
  final products = <Product>[].obs;
  final isLoading = true.obs;
  final errorMessage = RxnString();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      products.assignAll(await _repository.getAll());
    } catch (error) {
      errorMessage.value = error.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updatePrice(Product product, String rupees) async {
    final value = Currency.parseRupees(rupees);
    if (value == null) {
      throw const FormatException('Enter a valid non-negative price.');
    }
    await _repository.updatePrice(product.id, value);
    await load();
  }

  Future<void> setActive(Product product, bool active) async {
    try {
      await _repository.setActive(product.id, active);
      await load();
    } catch (error) {
      Get.snackbar('Unable to update product', error.toString());
    }
  }

  Future<void> addProduct({
    required String name,
    required String unit,
    required String price,
    required bool customPrice,
  }) async {
    final priceMinor = customPrice ? null : Currency.parseRupees(price);
    if (name.trim().isEmpty || unit.trim().isEmpty) {
      throw const FormatException('Name and unit are required.');
    }
    if (!customPrice && priceMinor == null) {
      throw const FormatException('Enter a valid non-negative price.');
    }
    await _repository.add(
      name: name,
      unit: unit,
      priceMinor: priceMinor,
      requiresCustomPrice: customPrice,
    );
    await load();
  }
}

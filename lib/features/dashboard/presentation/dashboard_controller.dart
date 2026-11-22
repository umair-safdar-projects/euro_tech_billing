import 'package:get/get.dart';

import '../../credit/data/credit_repository.dart';
import '../../credit/domain/credit_models.dart';

class DashboardController extends GetxController {
  DashboardController(this._repository);
  final CreditRepository _repository;
  final snapshot = Rxn<DashboardSnapshot>();
  final isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      snapshot.value = await _repository.dashboard();
    } finally {
      isLoading.value = false;
    }
  }
}

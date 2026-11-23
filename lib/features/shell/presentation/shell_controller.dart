import 'package:get/get.dart';

import '../domain/shell_destination.dart';

class ShellController extends GetxController {
  final selectedIndex = 0.obs;

  ShellDestination get selected => ShellDestination.values[selectedIndex.value];

  void select(int index) {
    if (index < 0 || index >= ShellDestination.values.length) {
      throw RangeError.index(index, ShellDestination.values, 'index');
    }
    selectedIndex.value = index;
  }

  void selectDestination(ShellDestination destination) =>
      select(destination.index);
}

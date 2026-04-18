import 'package:get/get.dart';

class RootShellController extends GetxController {
  final currentIndex = 0.obs;

  void changeTab(int index) {
    if (index == currentIndex.value) return;
    currentIndex.value = index;
  }
}
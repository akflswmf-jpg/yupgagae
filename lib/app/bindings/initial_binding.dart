import 'package:get/get.dart';
import 'package:yupgagae/app/bindings/root_binding.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // 앱 시작 시 공통 의존성
    RootBinding().dependencies();
  }
}
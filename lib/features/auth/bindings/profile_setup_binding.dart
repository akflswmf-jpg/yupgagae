import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_binding.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';

class ProfileSetupBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthController>()) {
      AuthBinding().dependencies();
    }
  }
}
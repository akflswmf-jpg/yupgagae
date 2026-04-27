import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_repository.dart';
import 'package:yupgagae/core/auth/firebase_auth_repository.dart';

class AuthBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthRepository>()) {
      Get.put<AuthRepository>(
        FirebaseAuthRepository(),
        permanent: true,
      );
    }

    if (!Get.isRegistered<AuthController>()) {
      Get.put<AuthController>(
        AuthController(
          repository: Get.find<AuthRepository>(),
        ),
        permanent: true,
      );
    }
  }
}
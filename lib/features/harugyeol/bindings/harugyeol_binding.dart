import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/features/harugyeol/controller/harugyeol_controller.dart';
import 'package:yupgagae/features/harugyeol/data/firestore_harugyeol_repository.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_repository.dart';

class HarugyeolBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();

    if (!Get.isRegistered<HarugyeolRepository>()) {
      Get.put<HarugyeolRepository>(
        FirestoreHarugyeolRepository(),
        permanent: true,
      );
    }

    if (!Get.isRegistered<HarugyeolController>()) {
      Get.put<HarugyeolController>(
        HarugyeolController(
          repo: Get.find<HarugyeolRepository>(),
          authController: Get.find<AuthController>(),
        ),
        permanent: true,
      );
    }
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthController>()) {
      throw Exception(
        'AuthController must be registered before HarugyeolBinding.',
      );
    }
  }
}
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class MyStoreBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();

    if (!Get.isRegistered<MyStoreController>()) {
      Get.put<MyStoreController>(
        MyStoreController(
          repo: Get.find<StoreProfileRepository>(),
          postRepo: Get.find<PostRepository>(),
          auth: Get.find<AuthSessionService>(),
        ),
        permanent: true,
      );
    }
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered by RootBinding before MyStoreBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered by RootBinding before MyStoreBinding.',
      );
    }

    if (!Get.isRegistered<PostRepository>()) {
      throw Exception(
        'PostRepository must be registered by RootBinding before MyStoreBinding.',
      );
    }
  }
}
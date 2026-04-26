import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/data/in_memory_store_profile_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class MyStoreBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<StoreProfileRepository>()) {
      Get.put<StoreProfileRepository>(
        InMemoryStoreProfileRepository(
          session: Get.find<AnonSessionService>(),
        ),
        permanent: true,
      );
    }

    if (!Get.isRegistered<MyStoreController>()) {
      Get.put<MyStoreController>(
        MyStoreController(
          repo: Get.find<StoreProfileRepository>(),
          postRepo: Get.find<PostRepository>(),
          session: Get.find<AnonSessionService>(),
        ),
        permanent: true,
      );
    }
  }
}
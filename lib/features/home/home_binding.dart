import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/admin/domain/admin_notice_repository.dart';
import 'package:yupgagae/features/community/controller/home_feed_controller.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered by RootBinding before HomeBinding.',
      );
    }

    if (!Get.isRegistered<AuthController>()) {
      throw Exception(
        'AuthController must be registered by RootBinding before HomeBinding.',
      );
    }

    if (!Get.isRegistered<PostRepository>()) {
      throw Exception(
        'PostRepository must be registered by RootBinding before HomeBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered by RootBinding before HomeBinding.',
      );
    }

    if (!Get.isRegistered<AdminNoticeRepository>()) {
      Get.lazyPut<AdminNoticeRepository>(
        () => FirebaseAdminNoticeRepository(),
        fenix: true,
      );
    }

    if (!Get.isRegistered<HomeFeedController>()) {
      Get.lazyPut<HomeFeedController>(
        () => HomeFeedController(
          repo: Get.find<PostRepository>(),
          auth: Get.find<AuthSessionService>(),
          authController: Get.find<AuthController>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
          noticeRepo: Get.find<AdminNoticeRepository>(),
        ),
        fenix: true,
      );
    }
  }
}

// END_OF_FILE: lib/features/home/home_binding.dart
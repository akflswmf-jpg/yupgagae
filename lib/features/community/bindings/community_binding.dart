import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/controller/owner_board_controller.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/data/in_memory_store_profile_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class CommunityBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AnonSessionService>()) {
      Get.put<AnonSessionService>(
        AnonSessionService(),
        permanent: true,
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      Get.put<StoreProfileRepository>(
        InMemoryStoreProfileRepository(),
        permanent: true,
      );
    }

    if (!Get.isRegistered<PostListController>()) {
      Get.put<PostListController>(
        PostListController(
          repo: Get.find<PostRepository>(),
          session: Get.find<AnonSessionService>(),
        ),
      );
    }

    if (!Get.isRegistered<OwnerBoardController>()) {
      Get.put<OwnerBoardController>(
        OwnerBoardController(
          repo: Get.find<PostRepository>(),
          session: Get.find<AnonSessionService>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
      );
    }

    final freeC = Get.find<PostListController>();
    final ownerC = Get.find<OwnerBoardController>();

    if (freeC.posts.isEmpty && !freeC.isLoading.value) {
      scheduleMicrotask(() {
        unawaited(freeC.initLoad());
      });
    }

    if (ownerC.posts.isEmpty && !ownerC.isLoading.value) {
      scheduleMicrotask(() {
        unawaited(ownerC.initLoad());
      });
    }

    if (!ownerC.isAccessLoading.value) {
      scheduleMicrotask(() {
        unawaited(ownerC.refreshOwnerVerification());
      });
    }
  }
}
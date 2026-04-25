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
    _requireAnonSession();
    _bindStoreProfileRepository();
    _bindPostListController();
    _bindOwnerBoardController();

    _warmUpCommunityControllers();
  }

  void _requireAnonSession() {
    if (!Get.isRegistered<AnonSessionService>()) {
      throw Exception('AnonSessionService must be initialized in main.dart');
    }
  }

  void _bindStoreProfileRepository() {
    if (!Get.isRegistered<StoreProfileRepository>()) {
      Get.lazyPut<StoreProfileRepository>(
        () => InMemoryStoreProfileRepository(
          session: Get.find<AnonSessionService>(),
        ),
        fenix: true,
      );
    }
  }

  void _bindPostListController() {
    if (!Get.isRegistered<PostListController>()) {
      Get.lazyPut<PostListController>(
        () => PostListController(
          repo: Get.find<PostRepository>(),
          session: Get.find<AnonSessionService>(),
        ),
        fenix: true,
      );
    }
  }

  void _bindOwnerBoardController() {
    if (!Get.isRegistered<OwnerBoardController>()) {
      Get.lazyPut<OwnerBoardController>(
        () => OwnerBoardController(
          repo: Get.find<PostRepository>(),
          session: Get.find<AnonSessionService>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
        fenix: true,
      );
    }
  }

  void _warmUpCommunityControllers() {
    scheduleMicrotask(() {
      if (Get.isRegistered<PostListController>()) {
        final freeC = Get.find<PostListController>();
        if (freeC.posts.isEmpty && !freeC.isLoading.value) {
          unawaited(freeC.initLoad());
        }
      }

      if (Get.isRegistered<OwnerBoardController>()) {
        final ownerC = Get.find<OwnerBoardController>();

        if (ownerC.posts.isEmpty && !ownerC.isLoading.value) {
          unawaited(ownerC.initLoad());
        }

        if (!ownerC.isAccessLoading.value) {
          unawaited(ownerC.refreshOwnerVerification());
        }
      }
    });
  }
}
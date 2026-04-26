import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/owner_board_controller.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class CommunityBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();

    _bindPostListController();
    _bindOwnerBoardController();

    _warmUpCommunityControllers();
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered by RootBinding before CommunityBinding.',
      );
    }

    if (!Get.isRegistered<PostRepository>()) {
      throw Exception(
        'PostRepository must be registered by RootBinding before CommunityBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered by RootBinding before CommunityBinding.',
      );
    }
  }

  void _bindPostListController() {
    if (!Get.isRegistered<PostListController>()) {
      Get.lazyPut<PostListController>(
        () => PostListController(
          repo: Get.find<PostRepository>(),
          auth: Get.find<AuthSessionService>(),
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
          auth: Get.find<AuthSessionService>(),
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
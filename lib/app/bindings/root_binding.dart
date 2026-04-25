import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';

import 'package:yupgagae/features/community/controller/home_feed_controller.dart';
import 'package:yupgagae/features/community/controller/owner_board_controller.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/data/in_memory_post_repository.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';

import 'package:yupgagae/features/my_store/data/in_memory_store_profile_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';
import 'package:yupgagae/features/my_store/bindings/my_store_binding.dart';
import 'package:yupgagae/features/revenue/bindings/revenue_binding.dart';

class RootBinding extends Bindings {
  @override
  void dependencies() {
    _requireAnonSession();
    _bindStoreProfileRepository();
    _bindPostRepository();
    _bindFreeBoardController();
    _bindOwnerBoardController();
    _bindHomeFeedController();

    MyStoreBinding().dependencies();
    RevenueBinding().dependencies();

    _warmUpRepositories();
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

  void _bindPostRepository() {
    if (!Get.isRegistered<PostRepository>()) {
      Get.lazyPut<PostRepository>(
        () => InMemoryPostRepository(
          currentUserId: Get.find<AnonSessionService>().anonId,
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
        fenix: true,
      );
    }
  }

  void _bindFreeBoardController() {
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

  void _bindHomeFeedController() {
    if (!Get.isRegistered<HomeFeedController>()) {
      Get.lazyPut<HomeFeedController>(
        () => HomeFeedController(
          repo: Get.find<PostRepository>(),
          anonSessionService: Get.find<AnonSessionService>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
        fenix: true,
      );
    }
  }

  void _warmUpRepositories() {
    Future.microtask(() async {
      try {
        final storeProfileRepo = Get.find<StoreProfileRepository>();
        final postRepo = Get.find<PostRepository>();

        await Future.wait([
          storeProfileRepo.warmUp(),
          postRepo.warmUp(),
        ]);
      } catch (_) {
        // 워밍업 실패는 앱 진입을 막지 않는다.
      }
    });
  }
}
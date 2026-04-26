import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/auth/local_auth_session_service.dart';
import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/core/service/app_warm_up_service.dart';

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

    _bindAuthSessionService();
    _bindStoreProfileRepository();
    _bindPostRepository();

    _bindFreeBoardController();
    _bindOwnerBoardController();
    _bindHomeFeedController();

    MyStoreBinding().dependencies();
    RevenueBinding().dependencies();

    _bindAndStartWarmUpService();
  }

  void _requireAnonSession() {
    if (!Get.isRegistered<AnonSessionService>()) {
      throw Exception('AnonSessionService must be initialized in main.dart');
    }
  }

  void _bindAuthSessionService() {
    if (!Get.isRegistered<AuthSessionService>()) {
      Get.put<AuthSessionService>(
        LocalAuthSessionService(
          anonSessionService: Get.find<AnonSessionService>(),
        ),
        permanent: true,
      );
    }
  }

  void _bindStoreProfileRepository() {
    if (!Get.isRegistered<StoreProfileRepository>()) {
      Get.put<StoreProfileRepository>(
        InMemoryStoreProfileRepository(
          session: Get.find<AnonSessionService>(),
        ),
        permanent: true,
      );
    }
  }

  void _bindPostRepository() {
    if (!Get.isRegistered<PostRepository>()) {
      Get.put<PostRepository>(
        InMemoryPostRepository(
          currentUserId: Get.find<AuthSessionService>().currentUserId,
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
        permanent: true,
      );
    }
  }

  void _bindFreeBoardController() {
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

  void _bindHomeFeedController() {
    if (!Get.isRegistered<HomeFeedController>()) {
      Get.lazyPut<HomeFeedController>(
        () => HomeFeedController(
          repo: Get.find<PostRepository>(),
          auth: Get.find<AuthSessionService>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
        fenix: true,
      );
    }
  }

  void _bindAndStartWarmUpService() {
    final AppWarmUpService service;

    if (Get.isRegistered<AppWarmUpService>()) {
      service = Get.find<AppWarmUpService>();
    } else {
      service = Get.put<AppWarmUpService>(
        AppWarmUpService(),
        permanent: true,
      );
    }

    service.start();
  }
}
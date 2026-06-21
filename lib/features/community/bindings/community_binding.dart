import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/home_feed_controller.dart';
import 'package:yupgagae/features/community/controller/owner_board_controller.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/data/firestore_post_repository.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class CommunityBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();

    _bindPostRepository();
    _bindPostListController();
    _bindOwnerBoardController();
    _bindHomeFeedController();
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered before CommunityBinding.',
      );
    }

    if (!Get.isRegistered<AuthController>()) {
      throw Exception(
        'AuthController must be registered before CommunityBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered before CommunityBinding.',
      );
    }
  }

  void _bindPostRepository() {
    if (Get.isRegistered<PostRepository>()) return;

    Get.put<PostRepository>(
      FirestorePostRepository(
        storeProfileRepo: Get.find<StoreProfileRepository>(),
      ),
      permanent: true,
    );
  }

  void _bindPostListController() {
    if (Get.isRegistered<PostListController>()) return;

    Get.lazyPut<PostListController>(
      () => PostListController(
        repo: Get.find<PostRepository>(),
        auth: Get.find<AuthSessionService>(),
        storeProfileRepo: Get.find<StoreProfileRepository>(),
      ),
      fenix: true,
    );
  }

  void _bindOwnerBoardController() {
    if (Get.isRegistered<OwnerBoardController>()) return;

    Get.lazyPut<OwnerBoardController>(
      () => OwnerBoardController(
        repo: Get.find<PostRepository>(),
        auth: Get.find<AuthSessionService>(),
        storeProfileRepo: Get.find<StoreProfileRepository>(),
        authController: Get.find<AuthController>(),
      ),
      fenix: true,
    );
  }

  void _bindHomeFeedController() {
    if (Get.isRegistered<HomeFeedController>()) return;

    Get.lazyPut<HomeFeedController>(
      () => HomeFeedController(
        repo: Get.find<PostRepository>(),
        auth: Get.find<AuthSessionService>(),
        authController: Get.find<AuthController>(),
        storeProfileRepo: Get.find<StoreProfileRepository>(),
      ),
      fenix: true,
    );
  }
}
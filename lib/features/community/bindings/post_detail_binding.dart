import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/controller/post_detail_controller.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class PostDetailBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();

    final repo = Get.find<PostRepository>();
    final auth = Get.find<AuthSessionService>();
    final storeRepo = Get.find<StoreProfileRepository>();

    if (!Get.isRegistered<PostDetailController>()) {
      Get.lazyPut<PostDetailController>(
        () => PostDetailController(
          repo: repo,
          auth: auth,
          storeProfileRepo: storeRepo,
        ),
        fenix: false,
      );
    }

    if (!Get.isRegistered<CommentController>()) {
      Get.lazyPut<CommentController>(
        () => CommentController(
          repo: repo,
          auth: auth,
          storeProfileRepo: storeRepo,
        ),
        fenix: false,
      );
    }
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered by RootBinding before PostDetailBinding.',
      );
    }

    if (!Get.isRegistered<PostRepository>()) {
      throw Exception(
        'PostRepository must be registered by RootBinding before PostDetailBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered by RootBinding before PostDetailBinding.',
      );
    }
  }
}
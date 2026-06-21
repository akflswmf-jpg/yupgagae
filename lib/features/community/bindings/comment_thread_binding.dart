import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class CommentThreadBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();

    if (!Get.isRegistered<CommentController>()) {
      Get.lazyPut<CommentController>(
        () => CommentController(
          repo: Get.find<PostRepository>(),
          auth: Get.find<AuthSessionService>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
      );
    }
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered by RootBinding before CommentThreadBinding.',
      );
    }

    if (!Get.isRegistered<PostRepository>()) {
      throw Exception(
        'PostRepository must be registered by RootBinding before CommentThreadBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered by RootBinding before CommentThreadBinding.',
      );
    }
  }
}
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/navigation/route_input_resolver.dart';
import 'package:yupgagae/features/community/controller/write_post_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class WritePostBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();

    final rawPostId = RouteInputResolver.string('postId');
    final postId =
        (rawPostId == null || rawPostId.trim().isEmpty) ? null : rawPostId.trim();

    final rawBoardType = RouteInputResolver.string('boardType');
    final initialBoardType = boardTypeFromKey(rawBoardType);

    final tag = postId == null ? 'create:${initialBoardType.key}' : 'edit:$postId';

    if (!Get.isRegistered<WritePostController>(tag: tag)) {
      Get.lazyPut<WritePostController>(
        () => WritePostController(
          repo: Get.find<PostRepository>(),
          auth: Get.find<AuthSessionService>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
          editingPostId: postId,
          initialBoardType: initialBoardType,
        ),
        tag: tag,
      );
    }
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered by RootBinding before WritePostBinding.',
      );
    }

    if (!Get.isRegistered<PostRepository>()) {
      throw Exception(
        'PostRepository must be registered by RootBinding before WritePostBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered by RootBinding before WritePostBinding.',
      );
    }
  }
}
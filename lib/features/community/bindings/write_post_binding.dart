import 'package:get/get.dart';

import 'package:yupgagae/core/navigation/route_input_resolver.dart';
import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/controller/write_post_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/data/in_memory_store_profile_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class WritePostBinding extends Bindings {
  @override
  void dependencies() {
    final rawPostId = RouteInputResolver.string('postId');
    final postId =
        (rawPostId == null || rawPostId.trim().isEmpty) ? null : rawPostId.trim();

    final rawBoardType = RouteInputResolver.string('boardType');
    final initialBoardType = boardTypeFromKey(rawBoardType);

    final tag = postId == null ? 'create:${initialBoardType.key}' : 'edit:$postId';

    if (!Get.isRegistered<StoreProfileRepository>()) {
      Get.lazyPut<StoreProfileRepository>(
        () => InMemoryStoreProfileRepository(
          session: Get.find<AnonSessionService>(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<WritePostController>(tag: tag)) {
      Get.lazyPut<WritePostController>(
        () => WritePostController(
          repo: Get.find<PostRepository>(),
          session: Get.find<AnonSessionService>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
          editingPostId: postId,
          initialBoardType: initialBoardType,
        ),
        tag: tag,
      );
    }
  }
}
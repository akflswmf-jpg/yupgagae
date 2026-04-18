import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/controller/post_detail_controller.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class PostDetailBinding extends Bindings {
  @override
  void dependencies() {
    final repo = Get.find<PostRepository>();
    final session = Get.find<AnonSessionService>();
    final storeRepo = Get.find<StoreProfileRepository>();

    Get.lazyPut<PostDetailController>(
      () => PostDetailController(
        repo: repo,
        session: session,
        storeProfileRepo: storeRepo,
      ),
      fenix: false,
    );

    Get.lazyPut<CommentController>(
      () => CommentController(
        repo: repo,
        storeProfileRepo: storeRepo,
      ),
      fenix: false,
    );
  }
}
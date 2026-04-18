import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/comment_controller.dart';

class CommentThreadBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<CommentController>()) {
      throw Exception(
        'CommentController not found. PostDetail must be opened first.',
      );
    }
  }
}
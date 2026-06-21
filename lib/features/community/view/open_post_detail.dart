import 'package:get/get.dart';

import 'package:yupgagae/features/community/bindings/post_detail_binding.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/post_detail_screen.dart';
import 'package:yupgagae/routes/app_routes.dart';

Future<T?> openPostDetail<T>(
  String postId, {
  Post? initialPost,
  dynamic result,
}) async {
  final trimmedPostId = postId.trim();
  if (trimmedPostId.isEmpty) {
    throw ArgumentError('postId required');
  }

  final usableInitialPost =
      initialPost != null && initialPost.id.trim() == trimmedPostId
          ? initialPost
          : null;

  return Get.to<T>(
    () => PostDetailScreen(
      postId: trimmedPostId,
      initialPost: usableInitialPost,
    ),
    binding: PostDetailBinding(),
    routeName: AppRoutes.postDetail,
    arguments: {
      'postId': trimmedPostId,
      if (usableInitialPost != null) 'initialPost': usableInitialPost,
      if (result != null) 'result': result,
    },
  );
}
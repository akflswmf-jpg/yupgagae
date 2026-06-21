import 'post_image_upload_result.dart';

abstract class PostImageRepository {
  Future<PostImageUploadResult> uploadPostImages({
    required String postId,
    required String authorId,
    required List<String> localImagePaths,
  });

  Future<void> deletePostImages({
    required List<String> imageUrls,
  });
}
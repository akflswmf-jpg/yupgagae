import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

import 'package:yupgagae/core/image/app_image_provider_resolver.dart';
import 'package:yupgagae/features/community/domain/post_image_repository.dart';
import 'package:yupgagae/features/community/domain/post_image_upload_result.dart';

class FirebasePostImageRepository implements PostImageRepository {
  static const int maxImages = 5;
  static const int maxUploadBytes = 5 * 1024 * 1024;

  final FirebaseStorage storage;

  FirebasePostImageRepository({
    FirebaseStorage? storage,
  }) : storage = storage ?? FirebaseStorage.instance;

  @override
  Future<PostImageUploadResult> uploadPostImages({
    required String postId,
    required String authorId,
    required List<String> localImagePaths,
  }) async {
    final normalizedPostId = postId.trim();
    final normalizedAuthorId = authorId.trim();

    if (normalizedPostId.isEmpty) {
      throw Exception('게시글 정보를 찾을 수 없습니다.');
    }

    if (normalizedAuthorId.isEmpty) {
      throw Exception('로그인이 필요한 기능입니다.');
    }

    final safePaths = localImagePaths
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .take(maxImages)
        .toList(growable: false);

    if (safePaths.isEmpty) {
      return const PostImageUploadResult(imageUrls: <String>[]);
    }

    final urls = <String>[];

    for (var i = 0; i < safePaths.length; i++) {
      final source = safePaths[i];

      if (AppImageProviderResolver.isNetworkSource(source)) {
        urls.add(source);
        continue;
      }

      final file = File(source);

      if (!await file.exists()) {
        throw Exception('사진 파일을 찾을 수 없습니다.');
      }

      final fileSize = await file.length();

      if (fileSize <= 0) {
        throw Exception('비어 있는 사진 파일입니다.');
      }

      if (fileSize > maxUploadBytes) {
        throw Exception('사진 용량이 너무 큽니다. 다시 선택해주세요.');
      }

      final imageId = _makeImageId(index: i);
      final ref = storage.ref().child(
            'posts/$normalizedPostId/images/$imageId.jpg',
          );

      final metadata = SettableMetadata(
        contentType: 'image/jpeg',
        customMetadata: <String, String>{
          'postId': normalizedPostId,
          'authorId': normalizedAuthorId,
          'source': 'yupgagae_post',
        },
      );

      await ref.putFile(file, metadata);

      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return PostImageUploadResult(
      imageUrls: urls,
    );
  }

  @override
  Future<void> deletePostImages({
    required List<String> imageUrls,
  }) async {
    final safeUrls = imageUrls
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .where(AppImageProviderResolver.isNetworkSource)
        .toSet();

    if (safeUrls.isEmpty) return;

    for (final url in safeUrls) {
      try {
        final ref = storage.refFromURL(url);
        await ref.delete();
      } catch (_) {
        // 게시글 삭제/수정 흐름이 Storage 삭제 실패 때문에 막히면 안 된다.
        // 실제 운영에서는 실패 로그를 별도 수집 대상으로 분리한다.
      }
    }
  }

  String _makeImageId({
    required int index,
  }) {
    final now = DateTime.now().microsecondsSinceEpoch;
    return '${now}_$index';
  }
}
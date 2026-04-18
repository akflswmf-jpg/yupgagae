import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/core/ui/post_row_tile.dart';
import 'package:yupgagae/routes/app_routes.dart';

class AllFeedScreen extends StatelessWidget {
  const AllFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final listC = Get.find<PostListController>();

    // ✅ 최초 1회 로드
    if (listC.posts.isEmpty && !listC.isLoading.value) {
      Future.microtask(() => listC.initLoad());
    }

    return Obx(() {
      if (listC.isLoading.value && listC.posts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
          // ✅ 바닥 근처면 다음 페이지 요청
          if (n.metrics.extentAfter < 300) {
            listC.loadMore();
          }
          return false;
        },
        child: RefreshIndicator(
          onRefresh: () => listC.initLoad(),
          child: ListView.builder(
            itemCount: listC.posts.length + (listC.hasMore.value ? 1 : 0),
            itemBuilder: (context, i) {
              // ✅ 하단 로딩 인디케이터
              if (i >= listC.posts.length) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: listC.isLoadingMore.value
                        ? const CircularProgressIndicator()
                        : const SizedBox.shrink(),
                  ),
                );
              }

              final p = listC.posts[i];
              final liked = p.likedUserIds.contains(listC.currentUserId);

              return PostRowTile(
                post: p,
                liked: liked,
                onTap: () {
                  // ✅ 규칙: postId는 query string으로만 전달
                  Get.toNamed('${AppRoutes.postDetail}?postId=${p.id}');
                },
                onLike: () async {
                  await listC.toggleLikeOnList(p);
                },
              );
            },
          ),
        ),
      );
    });
  }
}
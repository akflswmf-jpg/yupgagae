import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/ui/post_row_tile.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/open_post_detail.dart';

class AllFeedScreen extends StatelessWidget {
  const AllFeedScreen({super.key});

  bool _shouldHideOwnerContent(Post post) {
    if (post.boardType != BoardType.owner) return false;
    if (!Get.isRegistered<AuthController>()) return true;

    return !(Get.find<AuthController>().currentUser.value?.isBusinessVerified ??
        false);
  }

  @override
  Widget build(BuildContext context) {
    final listC = Get.find<PostListController>();

    if (listC.posts.isEmpty && !listC.isLoading.value) {
      Future.microtask(() => listC.initLoad());
    }

    return Obx(() {
      if (listC.isLoading.value && listC.posts.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      return NotificationListener<ScrollNotification>(
        onNotification: (n) {
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
              final hideOwnerContent = _shouldHideOwnerContent(p);

              return PostRowTile(
                post: p,
                liked: liked,
                obscureOwnerContent: hideOwnerContent,
                onTap: () {
                  openPostDetail<void>(
                    p.id,
                    initialPost: p,
                  );
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
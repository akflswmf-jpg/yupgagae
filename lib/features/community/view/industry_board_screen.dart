import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/routes/app_routes.dart';

class IndustryBoardScreen extends StatefulWidget {
  final String industryId;
  final String title;

  const IndustryBoardScreen({
    super.key,
    required this.industryId,
    required this.title,
  });

  @override
  State<IndustryBoardScreen> createState() => _IndustryBoardScreenState();
}

class _IndustryBoardScreenState extends State<IndustryBoardScreen> {
  late final PostListController c;

  @override
  void initState() {
    super.initState();
    c = Get.find<PostListController>();

    if (c.posts.isEmpty && !c.isLoading.value) {
      Future.microtask(() async {
        await c.initLoad();
      });
    }
  }

  Future<void> _goWrite() async {
    try {
      final result = await Get.toNamed(
        AppRoutes.writePost,
        arguments: {
          'industryId': widget.industryId,
          'boardType': BoardType.free.key,
        },
      );

      if (result == true) {
        await c.initLoad();
      }
    } catch (e) {
      Get.snackbar('이동 실패', '글쓰기 화면 이동 중 오류: $e');
    }
  }

  Future<void> _goDetail(String postId) async {
    try {
      await Get.toNamed(
        AppRoutes.postDetail,
        arguments: {
          'postId': postId,
        },
      );

      await c.initLoad();
    } catch (e) {
      Get.snackbar('이동 실패', '상세 화면 이동 중 오류: $e');
    }
  }

  List<Post> _industryPosts(List<Post> posts) {
    return posts
        .where((p) => p.industryId == widget.industryId)
        .toList(growable: false);
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';

    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: '글쓰기',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _goWrite,
          ),
        ],
      ),
      body: Obx(() {
        final posts = _industryPosts(c.posts);

        if (c.isLoading.value && posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (posts.isEmpty) {
          return const Center(
            child: Text(
              '게시글이 없습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: c.initLoad,
          child: ListView.separated(
            itemCount: posts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = posts[index];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                title: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${p.authorLabel} · ${_timeAgo(p.createdAt)} · 조회 ${p.viewCount} · 댓글 ${p.commentCount}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
                trailing: p.imagePaths.isEmpty
                    ? null
                    : const Icon(
                        Icons.photo_outlined,
                        size: 18,
                        color: Color(0xFF9CA3AF),
                      ),
                onTap: () => _goDetail(p.id),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _goWrite,
        child: const Icon(Icons.add),
      ),
    );
  }
}
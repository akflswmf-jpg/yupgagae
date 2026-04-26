import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/view/open_post_detail.dart';

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  late final PostListController c;

  @override
  void initState() {
    super.initState();
    c = Get.find<PostListController>();

    if (c.posts.isEmpty && !c.isLoading.value) {
      Future.microtask(() async {
        await c.ensureFeedInitialized();
      });
    }
  }

  Future<void> _openPostDetail(Post post) async {
    final result = await openPostDetail<bool>(post.id);

    if (result == true) {
      await c.initLoad();
    }
  }

  Future<void> _changeSort(PostSort sort) async {
    await c.setSort(sort);
  }

  String _sortLabel(PostSort sort) {
    switch (sort) {
      case PostSort.latest:
        return '최신';
      case PostSort.hot:
        return '인기';
      case PostSort.mostCommented:
        return '댓글많은순';
    }
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
        title: const Text('커뮤니티'),
        actions: [
          Obx(() {
            final selectedSort = c.selectedSort.value;

            return PopupMenuButton<PostSort>(
              tooltip: '정렬',
              initialValue: selectedSort,
              onSelected: _changeSort,
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: PostSort.latest,
                  child: Text('최신'),
                ),
                PopupMenuItem(
                  value: PostSort.hot,
                  child: Text('인기'),
                ),
                PopupMenuItem(
                  value: PostSort.mostCommented,
                  child: Text('댓글많은순'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    _sortLabel(selectedSort),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF875646),
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
      body: Obx(() {
        final list = c.visiblePosts;

        if (c.isLoading.value && list.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (c.error.value != null && list.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '에러: ${c.error.value}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ),
          );
        }

        if (list.isEmpty) {
          return const Center(
            child: Text(
              '글 없음',
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
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final p = list[i];

              return _PostCard(
                post: p,
                timeLabel: _timeAgo(p.createdAt),
                onTap: () => _openPostDetail(p),
              );
            },
          ),
        );
      }),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final String timeLabel;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.timeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage = post.imagePaths.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Color(0xFF4B5563),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  post.authorLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  '·',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  timeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (hasImage) ...[
                  const Icon(
                    Icons.photo_outlined,
                    size: 15,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 3),
                ],
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 15,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 3),
                Text(
                  '${post.viewCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.chat_bubble_outline,
                  size: 15,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 3),
                Text(
                  '${post.commentCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.favorite_border,
                  size: 15,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 3),
                Text(
                  '${post.likeCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
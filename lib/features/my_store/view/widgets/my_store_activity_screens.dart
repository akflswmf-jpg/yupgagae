import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/view/widgets/my_store_common_widgets.dart';
import 'package:yupgagae/routes/app_routes.dart';

class MyPostsScreen extends StatelessWidget {
  final MyStoreController controller;

  const MyPostsScreen({
    super.key,
    required this.controller,
  });

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _boardLabel(BoardType type) {
    switch (type) {
      case BoardType.free:
        return '자유게시판';
      case BoardType.owner:
        return '사장님게시판';
      case BoardType.used:
        return '거래게시판';
    }
  }

  Future<void> _openDetail(BuildContext context, Post post) async {
    await Get.toNamed(
      AppRoutes.postDetail,
      arguments: {'postId': post.id},
    );

    await controller.refreshMyPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '내가 쓴 글',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoadingMyPosts.value && controller.myPosts.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final error = controller.myActivityError.value;
        if (error != null && controller.myPosts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ),
          );
        }

        final items = controller.myPosts;
        if (items.isEmpty) {
          return const CenteredState(
            child: Text(
              '작성한 글이 없습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshMyPosts,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF1F3F5)),
            itemBuilder: (context, index) {
              final post = items[index];

              return InkWell(
                onTap: () => _openDetail(context, post),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kMyStoreSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _boardLabel(post.boardType),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: kMyStoreAccentDark,
                              ),
                            ),
                          ),
                          if (post.industryId != null &&
                              post.industryId!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                IndustryCatalog.nameOf(
                                  post.industryId,
                                  fallback: '',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            _timeLabel(post.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                          fontSize: 13.5,
                          height: 1.45,
                          color: Color(0xFF4B5563),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          MetaChip(label: '조회 ${post.viewCount}'),
                          const SizedBox(width: 8),
                          MetaChip(label: '좋아요 ${post.likeCount}'),
                          const SizedBox(width: 8),
                          MetaChip(label: '댓글 ${post.commentCount}'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class MyCommentsScreen extends StatelessWidget {
  final MyStoreController controller;

  const MyCommentsScreen({
    super.key,
    required this.controller,
  });

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Future<void> _openDetail(BuildContext context, Comment comment) async {
    await Get.toNamed(
      AppRoutes.postDetail,
      arguments: {'postId': comment.postId},
    );

    await controller.refreshMyComments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          '내가 쓴 댓글',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Color(0xFF111111),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.isLoadingMyComments.value && controller.myComments.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final error = controller.myActivityError.value;
        if (error != null && controller.myComments.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
            ),
          );
        }

        final items = controller.myComments;
        if (items.isEmpty) {
          return const CenteredState(
            child: Text(
              '작성한 댓글이 없습니다.',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: controller.refreshMyComments,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFF1F3F5)),
            itemBuilder: (context, index) {
              final comment = items[index];

              return InkWell(
                onTap: () => _openDetail(context, comment),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (comment.isReply)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: kMyStoreSoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '답글',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: kMyStoreAccentDark,
                                ),
                              ),
                            )
                          else
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                '댓글',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF4B5563),
                                ),
                              ),
                            ),
                          const Spacer(),
                          Text(
                            _timeLabel(comment.createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF9CA3AF),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        comment.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: comment.isDeleted
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF111111),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          MetaChip(label: '좋아요 ${comment.likeCount}'),
                          const SizedBox(width: 8),
                          const MetaChip(label: '게시글 이동'),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
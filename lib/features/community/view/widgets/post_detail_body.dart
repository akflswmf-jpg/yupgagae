import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/controller/post_detail_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/post_detail_comments_section.dart';
import 'package:yupgagae/features/community/view/widgets/post_detail_content_section.dart';

class PostDetailBody extends StatelessWidget {
  final PostDetailController c;
  final CommentController commentC;
  final ScrollController scrollController;
  final String Function(DateTime) timeLabel;
  final VoidCallback onCommentTap;
  final Future<void> Function(String commentId) onReplyTap;
  final Future<void> Function(String commentId, String currentText) onEditTap;
  final String? activeReplyId;
  final String? activeEditingId;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;
  final Future<void> Function() onLikeTap;

  const PostDetailBody({
    super.key,
    required this.c,
    required this.commentC,
    required this.scrollController,
    required this.timeLabel,
    required this.onCommentTap,
    required this.onReplyTap,
    required this.onEditTap,
    required this.activeReplyId,
    required this.activeEditingId,
    required this.onDelete,
    required this.onReport,
    required this.onLikeTap,
  });

  Widget _buildPostSliver() {
    return Obx(() {
      if (c.isLoading.value) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      final Post? p = c.post.value;
      if (p == null) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: _DetailEmptyState(
            title: '게시글을 불러올 수 없습니다.',
            subtitle: '잠시 후 다시 시도해주세요.',
          ),
        );
      }

      if (p.isReportThresholdReached) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: _DetailEmptyState(
            title: '블라인드 처리된 게시글입니다.',
            subtitle: '신고 누적으로 인해 게시글을 볼 수 없습니다.',
          ),
        );
      }

      final liked = p.likedUserIds.contains(c.currentUserId);

      return SliverToBoxAdapter(
        child: RepaintBoundary(
          child: PostDetailContentSection(
            post: p,
            timeLabel: timeLabel(p.createdAt),
            liked: liked,
            likeColor: liked
                ? const Color(0xFFA56E5F)
                : const Color(0xFF9CA3AF),
            onLikeTap: onLikeTap,
            onCommentTap: onCommentTap,
          ),
        ),
      );
    });
  }

  Widget _buildCommentsHeaderSliver() {
    return Obx(() {
      final count = c.post.value?.commentCount ?? commentC.activeCommentCount;

      return SliverToBoxAdapter(
        child: Container(
          width: double.infinity,
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Row(
            children: [
              const Text(
                '댓글',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111111),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$count',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildCommentsBodySliver() {
    return Obx(() {
      if (commentC.isLoading.value && commentC.flattenedComments.isEmpty) {
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }

      final items = commentC.flattenedComments;
      if (items.isEmpty) {
        return const SliverToBoxAdapter(
          child: _CommentsEmptyBox(),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final item = items[index];

            return RepaintBoundary(
              key: ValueKey(item.comment.id),
              child: PostDetailCommentItem(
                item: item,
                timeLabel: timeLabel,
                currentUserId: commentC.currentUserId,
                activeReplyId: activeReplyId,
                activeEditingId: activeEditingId,
                onReportComment: onReport,
                onReplyTap: (cm) async {
                  await onReplyTap(cm.id);
                },
                onEditTap: (cm) async {
                  await onEditTap(cm.id, cm.text);
                },
                onDeleteTap: onDelete,
                onToggleLikeTap: (cm) async {
                  await commentC.toggleLike(cm.id);
                },
              ),
            );
          },
          childCount: items.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      controller: scrollController,
      physics: const ClampingScrollPhysics(),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      cacheExtent: 500,
      slivers: [
        _buildPostSliver(),
        const SliverToBoxAdapter(
          child: SizedBox(height: 20),
        ),
        const SliverToBoxAdapter(
          child: ColoredBox(
            color: Color(0xFFF9FAFB),
            child: SizedBox(height: 8),
          ),
        ),
        _buildCommentsHeaderSliver(),
        _buildCommentsBodySliver(),
        const SliverToBoxAdapter(
          child: SizedBox(height: 24),
        ),
      ],
    );
  }
}

class _CommentsEmptyBox extends StatelessWidget {
  const _CommentsEmptyBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      child: const Text(
        '아직 댓글이 없습니다.',
        style: TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }
}

class _DetailEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DetailEmptyState({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.article_outlined,
              size: 30,
              color: Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: Color(0xFF111111),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/view/widgets/author_meta_line.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';

class PostDetailCommentsHeader extends StatelessWidget {
  final int commentCount;

  const PostDetailCommentsHeader({
    super.key,
    required this.commentCount,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          const Text(
            '댓글',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$commentCount',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class PostDetailCommentItem extends StatelessWidget {
  final CommentViewItem item;
  final String Function(DateTime) timeLabel;
  final String currentUserId;

  final String? activeReplyId;
  final String? activeEditingId;

  final Future<void> Function(Comment comment) onReportComment;
  final Future<void> Function(Comment comment) onReplyTap;
  final Future<void> Function(Comment comment) onEditTap;
  final Future<void> Function(Comment comment) onDeleteTap;
  final Future<void> Function(Comment comment) onToggleLikeTap;

  const PostDetailCommentItem({
    super.key,
    required this.item,
    required this.timeLabel,
    required this.currentUserId,
    required this.activeReplyId,
    required this.activeEditingId,
    required this.onReportComment,
    required this.onReplyTap,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.onToggleLikeTap,
  });

  @override
  Widget build(BuildContext context) {
    final comment = item.comment;
    final depth = item.depth;

    final myStore = Get.find<MyStoreController>();
    final blockedIds = myStore.blockedUsers.map((e) => e.userId).toSet();

    if (blockedIds.contains(comment.authorId)) {
      return const SizedBox.shrink();
    }

    final isMine = comment.authorId == currentUserId;
    final isReply = depth > 0;
    final isBlocked = comment.isDeleted || comment.isReportThresholdReached;
    final isLikedByMe = comment.likedUserIds.contains(currentUserId);

    final horizontalInset = isReply ? 28.0 : 16.0;
    final likeColor =
        isLikedByMe ? const Color(0xFFE5484D) : const Color(0xFF6B7280);

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalInset, 0, 16, 0),
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Color(0xFFF3F4F6),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CommentTopLine(
              isReply: isReply,
              child: AuthorMetaLine(
                industryId: comment.industryId,
                locationLabel: comment.locationLabel,
                nicknameLabel: comment.authorLabel,
                timeLabel: timeLabel(comment.createdAt),
                dense: true,
                isOwnerVerified: comment.isOwnerVerified,
              ),
            ),
            const SizedBox(height: 7),
            _CommentBody(comment: comment),
            if (!isBlocked) ...[
              const SizedBox(height: 10),
              _CommentActionRow(
                comment: comment,
                isMine: isMine,
                isReply: isReply,
                isLikedByMe: isLikedByMe,
                likeCount: comment.likeCount,
                likeColor: likeColor,
                onLikeTap: () => onToggleLikeTap(comment),
                onReplyTap: () => onReplyTap(comment),
                onEditTap: () => onEditTap(comment),
                onDeleteTap: () => onDeleteTap(comment),
                onReportTap: () => onReportComment(comment),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PostDetailCommentsEmptyBox extends StatelessWidget {
  const PostDetailCommentsEmptyBox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1F3F5)),
      ),
      child: const Column(
        children: [
          Icon(
            Icons.mode_comment_outlined,
            size: 20,
            color: Color(0xFF9CA3AF),
          ),
          SizedBox(height: 8),
          Text(
            '아직 댓글이 없습니다.',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '첫 댓글을 남겨보세요.',
            style: TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTopLine extends StatelessWidget {
  final bool isReply;
  final Widget child;

  const _CommentTopLine({
    required this.isReply,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!isReply) return child;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Padding(
          padding: EdgeInsets.only(right: 6),
          child: Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 15,
            color: Color(0xFF9CA3AF),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _CommentBody extends StatelessWidget {
  final Comment comment;

  const _CommentBody({
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    if (comment.isDeleted) {
      return const Text(
        '삭제된 댓글입니다.',
        style: TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    if (comment.isReportThresholdReached) {
      return const Text(
        '블라인드 처리된 댓글입니다.',
        style: TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Text(
      comment.text,
      style: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: Color(0xFF1F2937),
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

class _CommentActionRow extends StatelessWidget {
  final Comment comment;
  final bool isMine;
  final bool isReply;
  final bool isLikedByMe;
  final int likeCount;
  final Color likeColor;

  final Future<void> Function() onLikeTap;
  final Future<void> Function() onReplyTap;
  final Future<void> Function() onEditTap;
  final Future<void> Function() onDeleteTap;
  final Future<void> Function() onReportTap;

  const _CommentActionRow({
    required this.comment,
    required this.isMine,
    required this.isReply,
    required this.isLikedByMe,
    required this.likeCount,
    required this.likeColor,
    required this.onLikeTap,
    required this.onReplyTap,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.onReportTap,
  });

  Future<void> _blockUser() async {
    final myStore = Get.find<MyStoreController>();

    await myStore.blockUser(
      BlockedUserItem(
        userId: comment.authorId,
        nickname: comment.authorLabel.trim().isEmpty ? '익명' : comment.authorLabel,
        industry: comment.industryId,
        region: comment.locationLabel,
        blockedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineActionButton(
          onTap: onLikeTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLikedByMe ? Icons.favorite : Icons.favorite_border,
                size: 15,
                color: likeColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$likeCount',
                style: TextStyle(
                  fontSize: 12.5,
                  color: likeColor,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        _InlineActionButton(
          onTap: onReplyTap,
          child: Text(
            isReply ? '답글 보기' : '답글',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
        if (isMine) ...[
          _InlineActionButton(
            onTap: onEditTap,
            child: const Text(
              '수정',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
          _InlineActionButton(
            onTap: onDeleteTap,
            child: const Text(
              '삭제',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFFE5484D),
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ] else ...[
          _InlineActionButton(
            onTap: onReportTap,
            child: const Text(
              '신고',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
          _InlineActionButton(
            onTap: _blockUser,
            child: const Text(
              '차단',
              style: TextStyle(
                fontSize: 12.5,
                color: Color(0xFFE5484D),
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineActionButton extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onTap;

  const _InlineActionButton({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await onTap();
      },
      borderRadius: BorderRadius.circular(6),
      splashColor: const Color(0x08000000),
      highlightColor: const Color(0x04000000),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: child,
      ),
    );
  }
}
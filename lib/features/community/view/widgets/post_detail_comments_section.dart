import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/view/widgets/author_meta_line.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';

const Color kCommentLikeActive = Color(0xFFA56E5F);
const Color kCommentLikeInactive = Color(0xFF9CA3AF);

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
    return CommunityCommentCard(
      comment: item.comment,
      depth: item.depth,
      currentUserId: currentUserId,
      timeLabel: timeLabel,
      onReplyTap: onReplyTap,
      onEditTap: onEditTap,
      onDeleteTap: onDeleteTap,
      onReportTap: onReportComment,
      onToggleLikeTap: onToggleLikeTap,
      replyLabel: item.depth > 0 ? '답글 보기' : '답글',
      showReplyAction: true,
      denseMeta: true,
      margin: EdgeInsets.fromLTRB(item.depth > 0 ? 28 : 16, 0, 16, 0),
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFF3F4F6),
          ),
        ),
      ),
      bodyLeftInset: 0,
      actionLeftInset: 0,
      replyArrowPadding: const EdgeInsets.only(right: 6),
      replyArrowSize: 15,
      actionSpacing: 14,
      actionRunSpacing: 8,
      moreIconSize: 16,
      likeIconSize: 15,
      likeTextSize: 12.5,
      moreIconColor: const Color(0xFF6B7280),
      deletedText: '삭제된 댓글입니다.',
      blindedText: '블라인드 처리된 댓글입니다.',
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1.55,
        color: Color(0xFF1F2937),
        fontWeight: FontWeight.w500,
      ),
      blockedTextStyle: const TextStyle(
        color: Color(0xFF9CA3AF),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
      actionTopSpacing: 10,
    );
  }
}

class CommunityCommentCard extends StatelessWidget {
  final Comment comment;
  final int depth;
  final String currentUserId;
  final String Function(DateTime) timeLabel;

  final Future<void> Function(Comment comment) onReportTap;
  final Future<void> Function(Comment comment) onReplyTap;
  final Future<void> Function(Comment comment) onEditTap;
  final Future<void> Function(Comment comment) onDeleteTap;
  final Future<void> Function(Comment comment) onToggleLikeTap;

  final String replyLabel;
  final bool showReplyAction;
  final bool denseMeta;

  final EdgeInsetsGeometry margin;
  final EdgeInsetsGeometry padding;
  final Decoration? decoration;

  final double bodyLeftInset;
  final double actionLeftInset;

  final EdgeInsetsGeometry replyArrowPadding;
  final double replyArrowSize;

  final double actionSpacing;
  final double actionRunSpacing;
  final double moreIconSize;
  final double likeIconSize;
  final double likeTextSize;
  final Color moreIconColor;

  final String deletedText;
  final String blindedText;

  final TextStyle textStyle;
  final TextStyle blockedTextStyle;

  final double actionTopSpacing;

  const CommunityCommentCard({
    super.key,
    required this.comment,
    required this.depth,
    required this.currentUserId,
    required this.timeLabel,
    required this.onReportTap,
    required this.onReplyTap,
    required this.onEditTap,
    required this.onDeleteTap,
    required this.onToggleLikeTap,
    required this.replyLabel,
    required this.showReplyAction,
    required this.denseMeta,
    required this.margin,
    required this.padding,
    required this.decoration,
    required this.bodyLeftInset,
    required this.actionLeftInset,
    required this.replyArrowPadding,
    required this.replyArrowSize,
    required this.actionSpacing,
    required this.actionRunSpacing,
    required this.moreIconSize,
    required this.likeIconSize,
    required this.likeTextSize,
    required this.moreIconColor,
    required this.deletedText,
    required this.blindedText,
    required this.textStyle,
    required this.blockedTextStyle,
    required this.actionTopSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final isMine = comment.authorId == currentUserId;
    final isReply = depth > 0;
    final isBlocked = comment.isDeleted || comment.isReportThresholdReached;
    final isLikedByMe = comment.likedUserIds.contains(currentUserId);
    final likeColor =
        isLikedByMe ? kCommentLikeActive : kCommentLikeInactive;

    return Container(
      margin: margin,
      padding: padding,
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CommentTopLine(
            isReply: isReply,
            arrowPadding: replyArrowPadding,
            arrowSize: replyArrowSize,
            child: AuthorMetaLine(
              industryId: comment.industryId,
              locationLabel: comment.locationLabel,
              nicknameLabel: comment.authorLabel,
              timeLabel: timeLabel(comment.createdAt),
              dense: denseMeta,
              isOwnerVerified: comment.isOwnerVerified,
            ),
          ),
          const SizedBox(height: 7),
          if (bodyLeftInset > 0)
            Padding(
              padding: EdgeInsets.only(left: bodyLeftInset),
              child: _CommentBody(
                comment: comment,
                deletedText: deletedText,
                blindedText: blindedText,
                textStyle: textStyle,
                blockedTextStyle: blockedTextStyle,
              ),
            )
          else
            _CommentBody(
              comment: comment,
              deletedText: deletedText,
              blindedText: blindedText,
              textStyle: textStyle,
              blockedTextStyle: blockedTextStyle,
            ),
          if (!isBlocked) ...[
            SizedBox(height: actionTopSpacing),
            if (actionLeftInset > 0)
              Padding(
                padding: EdgeInsets.only(left: actionLeftInset),
                child: _CommentActionRow(
                  comment: comment,
                  isMine: isMine,
                  isLikedByMe: isLikedByMe,
                  likeCount: comment.likeCount,
                  likeColor: likeColor,
                  replyLabel: replyLabel,
                  showReplyAction: showReplyAction,
                  actionSpacing: actionSpacing,
                  actionRunSpacing: actionRunSpacing,
                  moreIconSize: moreIconSize,
                  likeIconSize: likeIconSize,
                  likeTextSize: likeTextSize,
                  moreIconColor: moreIconColor,
                  onLikeTap: () => onToggleLikeTap(comment),
                  onReplyTap: () => onReplyTap(comment),
                  onEditTap: () => onEditTap(comment),
                  onDeleteTap: () => onDeleteTap(comment),
                  onReportTap: () => onReportTap(comment),
                ),
              )
            else
              _CommentActionRow(
                comment: comment,
                isMine: isMine,
                isLikedByMe: isLikedByMe,
                likeCount: comment.likeCount,
                likeColor: likeColor,
                replyLabel: replyLabel,
                showReplyAction: showReplyAction,
                actionSpacing: actionSpacing,
                actionRunSpacing: actionRunSpacing,
                moreIconSize: moreIconSize,
                likeIconSize: likeIconSize,
                likeTextSize: likeTextSize,
                moreIconColor: moreIconColor,
                onLikeTap: () => onToggleLikeTap(comment),
                onReplyTap: () => onReplyTap(comment),
                onEditTap: () => onEditTap(comment),
                onDeleteTap: () => onDeleteTap(comment),
                onReportTap: () => onReportTap(comment),
              ),
          ],
        ],
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
  final EdgeInsetsGeometry arrowPadding;
  final double arrowSize;

  const _CommentTopLine({
    required this.isReply,
    required this.child,
    required this.arrowPadding,
    required this.arrowSize,
  });

  @override
  Widget build(BuildContext context) {
    if (!isReply) return child;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Padding(
          padding: arrowPadding,
          child: Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: arrowSize,
            color: const Color(0xFF9CA3AF),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _CommentBody extends StatelessWidget {
  final Comment comment;
  final String deletedText;
  final String blindedText;
  final TextStyle textStyle;
  final TextStyle blockedTextStyle;

  const _CommentBody({
    required this.comment,
    required this.deletedText,
    required this.blindedText,
    required this.textStyle,
    required this.blockedTextStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (comment.isDeleted) {
      return Text(
        deletedText,
        style: blockedTextStyle,
      );
    }

    if (comment.isReportThresholdReached) {
      return Text(
        blindedText,
        style: blockedTextStyle,
      );
    }

    return Text(
      comment.text,
      style: textStyle,
    );
  }
}

class _CommentActionRow extends StatelessWidget {
  final Comment comment;
  final bool isMine;
  final bool isLikedByMe;
  final int likeCount;
  final Color likeColor;
  final String replyLabel;
  final bool showReplyAction;

  final double actionSpacing;
  final double actionRunSpacing;
  final double moreIconSize;
  final double likeIconSize;
  final double likeTextSize;
  final Color moreIconColor;

  final Future<void> Function() onLikeTap;
  final Future<void> Function() onReplyTap;
  final Future<void> Function() onEditTap;
  final Future<void> Function() onDeleteTap;
  final Future<void> Function() onReportTap;

  const _CommentActionRow({
    required this.comment,
    required this.isMine,
    required this.isLikedByMe,
    required this.likeCount,
    required this.likeColor,
    required this.replyLabel,
    required this.showReplyAction,
    required this.actionSpacing,
    required this.actionRunSpacing,
    required this.moreIconSize,
    required this.likeIconSize,
    required this.likeTextSize,
    required this.moreIconColor,
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
        nickname:
            comment.authorLabel.trim().isEmpty ? '익명' : comment.authorLabel,
        industry: comment.industryId,
        region: comment.locationLabel,
        blockedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _showMoreMenu(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isMine) ...[
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  title: const Text(
                    '수정',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await onEditTap();
                  },
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  title: const Text(
                    '삭제',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5484D),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await onDeleteTap();
                  },
                ),
              ] else ...[
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  title: const Text(
                    '신고',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await onReportTap();
                  },
                ),
                ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                  title: const Text(
                    '차단',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5484D),
                    ),
                  ),
                  onTap: () async {
                    Navigator.of(bottomSheetContext).pop();
                    await _blockUser();
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: actionSpacing,
      runSpacing: actionRunSpacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _InlineActionButton(
          onTap: onLikeTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLikedByMe ? Icons.favorite : Icons.favorite_border,
                size: likeIconSize,
                color: likeColor,
              ),
              const SizedBox(width: 4),
              Text(
                '$likeCount',
                style: TextStyle(
                  fontSize: likeTextSize,
                  color: likeColor,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (showReplyAction)
          _InlineActionButton(
            onTap: onReplyTap,
            child: Text(
              replyLabel,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        _InlineActionButton(
          onTap: () => _showMoreMenu(context),
          child: Icon(
            Icons.more_vert,
            size: moreIconSize,
            color: moreIconColor,
          ),
        ),
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
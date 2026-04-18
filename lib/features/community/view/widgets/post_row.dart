import 'dart:io';

import 'package:flutter/material.dart';

import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/author_meta_line.dart';

class PostRow extends StatelessWidget {
  final Post post;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final bool liked;

  const PostRow({
    super.key,
    required this.post,
    required this.timeLabel,
    required this.onTap,
    required this.onLike,
    required this.liked,
  });

  @override
  Widget build(BuildContext context) {
    final rawTitle = post.title.trim();
    final title = rawTitle.isEmpty ? '(제목 없음)' : rawTitle;

    final isBlind = post.isReportThresholdReached;
    final previewSource =
        isBlind ? '블라인드 처리된 게시글입니다.' : post.body.trim().replaceAll('\n', ' ');
    final preview = previewSource.length > 88
        ? '${previewSource.substring(0, 88)}...'
        : previewSource;

    final thumbPath = post.imagePaths.isNotEmpty ? post.imagePaths.first : null;
    final likeColor = liked ? const Color(0xFFCC5A4E) : const Color(0xFF6B7280);

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          splashColor: const Color(0x08000000),
          highlightColor: const Color(0x04000000),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AuthorMetaLine(
                  industryId: post.industryId,
                  locationLabel: post.locationLabel,
                  nicknameLabel: post.authorLabel,
                  timeLabel: timeLabel,
                  isOwnerVerified: post.isOwnerVerified,
                  dense: true,
                ),
                const SizedBox(height: 8),
                _PostMainBlock(
                  title: isBlind ? '블라인드 처리된 게시글입니다.' : title,
                  preview: preview,
                  thumbPath: isBlind ? null : thumbPath,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _MetaLabel(
                      icon: Icons.remove_red_eye_outlined,
                      text: '${post.viewCount}',
                    ),
                    const SizedBox(width: 12),
                    _MetaLabel(
                      icon: Icons.mode_comment_outlined,
                      text: '${post.commentCount}',
                    ),
                    const SizedBox(width: 12),
                    _LikeButton(
                      liked: liked,
                      likeCount: post.likeCount,
                      color: likeColor,
                      onTap: onLike,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PostMainBlock extends StatelessWidget {
  final String title;
  final String preview;
  final String? thumbPath;

  const _PostMainBlock({
    required this.title,
    required this.preview,
    required this.thumbPath,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PostTextBlock(
              title: title,
              preview: preview,
            ),
          ),
          if (thumbPath != null) ...[
            const SizedBox(width: 12),
            _Thumb(path: thumbPath!),
          ],
        ],
      ),
    );
  }
}

class _PostTextBlock extends StatelessWidget {
  final String title;
  final String preview;

  const _PostTextBlock({
    required this.title,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
              height: 1.32,
              letterSpacing: -0.1,
            ),
          ),
          const Spacer(),
          if (preview.trim().isNotEmpty)
            Text(
              preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;

  const _Thumb({required this.path});

  ImageProvider _provider(File file) {
    return ResizeImage(
      FileImage(file),
      width: 160, // 🔥 더 줄여서 decode 부담 감소
    );
  }

  @override
  Widget build(BuildContext context) {
    final file = File(path);

    if (!file.existsSync()) {
      return const _ErrorThumb();
    }

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Image(
            image: _provider(file),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            gaplessPlayback: true,

            // 🔥 핵심: lazy 렌더링
            frameBuilder: (context, child, frame, wasSync) {
              if (wasSync || frame != null) {
                return child;
              }

              return const Center(
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },

            errorBuilder: (_, __, ___) {
              return const _ErrorThumb();
            },
          ),
        ),
      ),
    );
  }
}

class _ErrorThumb extends StatelessWidget {
  const _ErrorThumb();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_not_supported_outlined,
        size: 18,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

class _LikeButton extends StatelessWidget {
  final bool liked;
  final int likeCount;
  final Color color;
  final VoidCallback onTap;

  const _LikeButton({
    required this.liked,
    required this.likeCount,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite : Icons.favorite_border,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$likeCount',
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaLabel extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaLabel({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF6B7280);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
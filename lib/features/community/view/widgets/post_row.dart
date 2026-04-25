import 'dart:io';

import 'package:flutter/material.dart';

import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/author_meta_line.dart';

class PostRow extends StatelessWidget {
  static const Color _accentColor = Color(0xFFA56E5F);
  static const Color _normalTextColor = Color(0xFF111111);
  static const Color _mutedTextColor = Color(0xFF6B7280);

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

  String _usedPrefix() {
    if (post.boardType != BoardType.used || post.usedType == null) {
      return '';
    }

    switch (post.usedType!) {
      case UsedPostType.store:
        return '[가게양도]';
      case UsedPostType.item:
        return '[중고거래]';
    }
  }

  String _safeTitle(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '(제목 없음)';
    return trimmed;
  }

  String _safePreview({
    required bool isBlind,
    required String body,
  }) {
    if (isBlind) return '블라인드 처리된 게시글입니다.';

    final normalized = body.trim().replaceAll('\n', ' ');
    if (normalized.length <= 88) return normalized;
    return '${normalized.substring(0, 88)}...';
  }

  @override
  Widget build(BuildContext context) {
    final isBlind = post.isReportThresholdReached;
    final prefix = isBlind ? '' : _usedPrefix();
    final title = isBlind ? '블라인드 처리된 게시글입니다.' : _safeTitle(post.title);
    final preview = _safePreview(
      isBlind: isBlind,
      body: post.body,
    );
    final thumbPath = post.imagePaths.isNotEmpty ? post.imagePaths.first : null;

    final likeColor = liked ? _accentColor : _mutedTextColor;

    return RepaintBoundary(
      child: Opacity(
        opacity: post.isSold ? 0.72 : 1,
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
                    prefix: prefix,
                    title: title,
                    preview: preview,
                    thumbPath: isBlind ? null : thumbPath,
                    isSold: post.isSold,
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
      ),
    );
  }
}

class _PostMainBlock extends StatelessWidget {
  final String prefix;
  final String title;
  final String preview;
  final String? thumbPath;
  final bool isSold;

  const _PostMainBlock({
    required this.prefix,
    required this.title,
    required this.preview,
    required this.thumbPath,
    required this.isSold,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _PostTextBlock(
              prefix: prefix,
              title: title,
              preview: preview,
              isSold: isSold,
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
  final String prefix;
  final String title;
  final String preview;
  final bool isSold;

  const _PostTextBlock({
    required this.prefix,
    required this.title,
    required this.preview,
    required this.isSold,
  });

  @override
  Widget build(BuildContext context) {
    final hasPreview = preview.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PostTitleLine(
          prefix: prefix,
          title: title,
          isSold: isSold,
        ),
        if (hasPreview) ...[
          const SizedBox(height: 12),
          Text(
            preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
              height: 1.38,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ],
    );
  }
}

class _PostTitleLine extends StatelessWidget {
  static const Color _accentColor = Color(0xFFA56E5F);
  static const Color _titleColor = Color(0xFF111111);

  final String prefix;
  final String title;
  final bool isSold;

  const _PostTitleLine({
    required this.prefix,
    required this.title,
    required this.isSold,
  });

  @override
  Widget build(BuildContext context) {
    final hasPrefix = prefix.trim().isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isSold) ...[
          const _SoldBadge(),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                if (hasPrefix)
                  TextSpan(
                    text: '$prefix ',
                    style: const TextStyle(
                      color: _accentColor,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                TextSpan(
                  text: title,
                  style: const TextStyle(
                    color: _titleColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              height: 1.28,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _SoldBadge extends StatelessWidget {
  static const Color _soldTextColor = Color(0xFF8A4F43);
  static const Color _soldBgColor = Color(0xFFF6EEEA);
  static const Color _soldBorderColor = Color(0xFFE8D8D2);

  const _SoldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 20,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: _soldBgColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _soldBorderColor),
      ),
      alignment: Alignment.center,
      child: const Text(
        '거래완료',
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 11,
          height: 1,
          fontWeight: FontWeight.w900,
          color: _soldTextColor,
          letterSpacing: -0.2,
        ),
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
      width: 160,
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
    return const SizedBox(
      width: 72,
      height: 72,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          size: 18,
          color: Color(0xFF9CA3AF),
        ),
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
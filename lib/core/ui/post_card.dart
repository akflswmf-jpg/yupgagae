import 'dart:io';

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_badge.dart';

class PostCard extends StatelessWidget {
  final String title;

  // ✅ 추가: 작성자/메타
  final String? authorLabel;
  final int? viewCount;
  final int? imageCount;

  // ✅ 추가: 실제 이미지 경로 (썸네일 렌더링용)
  final List<String>? imagePaths;

  final UserAuthBadge authBadge;
  final String? locationLabel;
  final String? industryLabel;

  final String timeLabel;

  final int commentCount;
  final int likeCount;

  final bool liked;
  final VoidCallback? onLike;
  final VoidCallback? onTap;

  const PostCard({
    super.key,
    required this.title,
    required this.authBadge,
    required this.timeLabel,
    required this.commentCount,
    required this.likeCount,
    required this.liked,
    this.onLike,
    this.locationLabel,
    this.industryLabel,
    this.onTap,
    this.authorLabel,
    this.viewCount,
    this.imageCount,
    this.imagePaths,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final hasAuthor = (authorLabel != null && authorLabel!.trim().isNotEmpty);
    final hasViews = (viewCount != null);
    final hasImages = (imageCount != null && imageCount! > 0);
    final thumbPath = (imagePaths != null && imagePaths!.isNotEmpty)
        ? imagePaths!.first
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: cs.outline, width: 1),
          boxShadow: AppShadow.card(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TopBadgesRow(
              authBadge: authBadge,
              locationLabel: locationLabel,
              industryLabel: industryLabel,
            ),
            const SizedBox(height: AppSpace.xs),

            // ✅ 제목 + 썸네일(있으면)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (thumbPath != null) ...[
                  const SizedBox(width: 10),
                  _Thumb(path: thumbPath),
                ],
              ],
            ),

            if (hasAuthor || hasViews || hasImages) ...[
              const SizedBox(height: AppSpace.xs),
              _MetaRow(
                authorLabel: authorLabel,
                viewCount: viewCount,
                imageCount: imageCount,
              ),
            ],

            const SizedBox(height: AppSpace.xs),

            Row(
              children: [
                Text(timeLabel, style: theme.textTheme.bodySmall),
                const Spacer(),
                _MiniReaction(
                  icon: Icons.mode_comment_outlined,
                  label: '댓글 $commentCount',
                ),
                const SizedBox(width: AppSpace.xs),
                _LikeButton(
                  liked: liked,
                  likeCount: likeCount,
                  onPressed: onLike,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;
  const _Thumb({required this.path});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget img;
    if (path.startsWith('http')) {
      img = Image.network(path, fit: BoxFit.cover);
    } else {
      final f = File(path);
      img = f.existsSync()
          ? Image.file(f, fit: BoxFit.cover)
          : Icon(Icons.broken_image_outlined, color: cs.outline);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 66,
        height: 66,
        color: cs.surfaceContainerHighest,
        child: img,
      ),
    );
  }
}

class _TopBadgesRow extends StatelessWidget {
  final UserAuthBadge authBadge;
  final String? locationLabel;
  final String? industryLabel;

  const _TopBadgesRow({
    required this.authBadge,
    this.locationLabel,
    this.industryLabel,
  });

  @override
  Widget build(BuildContext context) {
    final hasLocation =
        (locationLabel != null && locationLabel!.trim().isNotEmpty);
    final hasIndustry =
        (industryLabel != null && industryLabel!.trim().isNotEmpty);

    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AuthBadge(type: authBadge),
        if (hasIndustry)
          const AppBadge(
            text: '업종',
            icon: Icons.storefront_outlined,
            tone: AppBadgeTone.soft,
          )._copyWithText(industryLabel!),
        if (hasLocation)
          const AppBadge(
            text: '동네',
            icon: Icons.place_outlined,
            tone: AppBadgeTone.outline,
          )._copyWithText(locationLabel!),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String? authorLabel;
  final int? viewCount;
  final int? imageCount;

  const _MetaRow({
    required this.authorLabel,
    required this.viewCount,
    required this.imageCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final hasAuthor = (authorLabel != null && authorLabel!.trim().isNotEmpty);
    final hasViews = (viewCount != null);
    final hasImages = (imageCount != null && imageCount! > 0);

    return Row(
      children: [
        if (hasAuthor) ...[
          const Icon(Icons.person_outline, size: 14, color: Color(0xFF7A7A7A)),
          const SizedBox(width: 4),
          Text(
            authorLabel!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (hasAuthor && (hasViews || hasImages)) ...[
          const SizedBox(width: 10),
          const Text('·', style: TextStyle(color: Color(0xFF999999))),
          const SizedBox(width: 10),
        ],
        if (hasViews) ...[
          const Icon(Icons.remove_red_eye_outlined,
              size: 14, color: Color(0xFF7A7A7A)),
          const SizedBox(width: 4),
          Text(
            '$viewCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (hasViews && hasImages) ...[
          const SizedBox(width: 10),
          const Text('·', style: TextStyle(color: Color(0xFF999999))),
          const SizedBox(width: 10),
        ],
        if (hasImages) ...[
          const Icon(Icons.photo_outlined, size: 14, color: Color(0xFF7A7A7A)),
          const SizedBox(width: 4),
          Text(
            '$imageCount',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF666666),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }
}

class _MiniReaction extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniReaction({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.chat_bubble_outline, size: 16, color: Color(0xFF7A7A7A)),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  const _LikeButton({
    required this.liked,
    required this.likeCount,
    required this.onPressed,
  });

  final bool liked;
  final int likeCount;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final iconColor = liked ? cs.secondary : const Color(0xFF7A7A7A);
    final textColor = liked ? cs.secondary : const Color(0xFF555555);

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: iconColor,
            ),
            const SizedBox(width: 4),
            Text(
              '공감 $likeCount',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 내부 헬퍼
extension _BadgeCopy on AppBadge {
  AppBadge _copyWithText(String newText) {
    return AppBadge(
      text: newText,
      icon: icon,
      tone: tone,
      color: color,
      padding: padding,
    );
  }
}
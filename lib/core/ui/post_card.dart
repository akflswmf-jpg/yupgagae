import 'dart:io';

import 'package:flutter/material.dart';

import 'package:yupgagae/core/theme/app_theme.dart';
import 'package:yupgagae/core/ui/app_badge.dart';

class PostCard extends StatelessWidget {
  final String title;

  final String? authorLabel;
  final int? viewCount;
  final int? imageCount;
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
    final thumbPath = (imagePaths != null && imagePaths!.isNotEmpty)
        ? imagePaths!.first.trim()
        : null;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: const Color(0xFFE5E7EB),
            width: 1,
          ),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      height: 1.3,
                    ),
                  ),
                ),
                if (thumbPath != null && thumbPath.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  _Thumb(path: thumbPath),
                ],
              ],
            ),
            if (_hasMeta) ...[
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
                Text(
                  timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF6B7280),
                  ),
                ),
                const Spacer(),
                _MiniReaction(
                  icon: Icons.mode_comment_outlined,
                  label: '$commentCount',
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

  bool get _hasMeta {
    final hasAuthor = authorLabel != null && authorLabel!.trim().isNotEmpty;
    final hasViews = viewCount != null;
    final hasImages = imageCount != null && imageCount! > 0;

    return hasAuthor || hasViews || hasImages;
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
        locationLabel != null && locationLabel!.trim().isNotEmpty;
    final hasIndustry =
        industryLabel != null && industryLabel!.trim().isNotEmpty;

    return Wrap(
      spacing: AppSpace.xs,
      runSpacing: AppSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        AuthBadge(type: authBadge),
        if (hasIndustry)
          AppBadge(
            text: industryLabel!.trim(),
            icon: Icons.storefront_outlined,
            tone: AppBadgeTone.soft,
            color: const Color(0xFFA56E5F),
          ),
        if (hasLocation)
          AppBadge(
            text: locationLabel!.trim(),
            icon: Icons.place_outlined,
            tone: AppBadgeTone.outline,
            color: const Color(0xFF6B7280),
          ),
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
    final children = <Widget>[];

    void addDot() {
      if (children.isEmpty) return;
      children.add(const SizedBox(width: 8));
      children.add(
        const Text(
          '·',
          style: TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 12,
          ),
        ),
      );
      children.add(const SizedBox(width: 8));
    }

    final safeAuthor = authorLabel?.trim();
    if (safeAuthor != null && safeAuthor.isNotEmpty) {
      children.add(
        _MetaLabel(
          icon: Icons.person_outline,
          text: safeAuthor,
        ),
      );
    }

    if (viewCount != null) {
      addDot();
      children.add(
        _MetaLabel(
          icon: Icons.remove_red_eye_outlined,
          text: '$viewCount',
        ),
      );
    }

    if (imageCount != null && imageCount! > 0) {
      addDot();
      children.add(
        _MetaLabel(
          icon: Icons.photo_outlined,
          text: '$imageCount',
        ),
      );
    }

    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 0,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: children,
          ),
        ),
      ],
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
        Icon(
          icon,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            height: 1.0,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
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
    const color = Color(0xFF6B7280);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            height: 1.0,
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _LikeButton extends StatelessWidget {
  final bool liked;
  final int likeCount;
  final VoidCallback? onPressed;

  const _LikeButton({
    required this.liked,
    required this.likeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = liked ? const Color(0xFFA56E5F) : const Color(0xFF6B7280);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 4),
            Text(
              '$likeCount',
              style: TextStyle(
                fontSize: 12,
                height: 1.0,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String path;

  const _Thumb({
    required this.path,
  });

  @override
  Widget build(BuildContext context) {
    Widget child;

    if (path.startsWith('http')) {
      child = Image.network(
        path,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.low,
        errorBuilder: (_, __, ___) => const _BrokenThumb(),
      );
    } else {
      final file = File(path);
      if (file.existsSync()) {
        child = Image.file(
          file,
          fit: BoxFit.cover,
          filterQuality: FilterQuality.low,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => const _BrokenThumb(),
        );
      } else {
        child = const _BrokenThumb();
      }
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 66,
        height: 66,
        color: const Color(0xFFF3F4F6),
        child: child,
      ),
    );
  }
}

class _BrokenThumb extends StatelessWidget {
  const _BrokenThumb();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 20,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}
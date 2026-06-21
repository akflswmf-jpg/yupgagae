import 'package:flutter/material.dart';

import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/post_row.dart';

const Color kHomeAccent = Color(0xFFA56E5F);
const Color kHomeAccentDark = Color(0xFF875646);
const Color kHomeAccentSoft = Color(0xFFF5ECE8);

class HomeSectionHeader extends StatelessWidget {
  final String title;
  final String? badgeText;
  final Widget? trailing;
  final Color accentColor;

  const HomeSectionHeader({
    super.key,
    required this.title,
    this.badgeText,
    this.trailing,
    this.accentColor = const Color(0xFF111111),
  });

  @override
  Widget build(BuildContext context) {
    final hasBadge = badgeText != null && badgeText!.trim().isNotEmpty;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
      child: Row(
        children: [
          if (hasBadge) ...[
            _HeaderBadge(
              text: badgeText!.trim(),
              accentColor: accentColor,
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Color(0xFF111111),
                letterSpacing: -0.2,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class HomeInlineDividerLabel extends StatelessWidget {
  final String label;
  final IconData? icon;
  final EdgeInsetsGeometry padding;

  const HomeInlineDividerLabel({
    super.key,
    required this.label,
    this.icon,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 10),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: padding,
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 15,
                    color: const Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 5),
                ],
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF6B7280),
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeMiniList extends StatelessWidget {
  final List<Post> posts;
  final String Function(DateTime dt) timeLabelBuilder;
  final Future<void> Function(Post post) onTap;
  final void Function(Post post) onLike;
  final bool Function(Post post) isLiked;
  final String emptyMessage;
  final bool compactTopPadding;

  const HomeMiniList({
    super.key,
    required this.posts,
    required this.timeLabelBuilder,
    required this.onTap,
    required this.onLike,
    required this.isLiked,
    this.emptyMessage = '아직 등록된 글이 없습니다.',
    this.compactTopPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    if (posts.isEmpty) {
      return _HomeEmptyState(
        message: emptyMessage,
        compactTopPadding: compactTopPadding,
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compactTopPadding) const SizedBox(height: 2),
          for (int i = 0; i < posts.length; i++) ...[
            PostRow(
              post: posts[i],
              timeLabel: timeLabelBuilder(posts[i].createdAt),
              onTap: () => onTap(posts[i]),
              onLike: () => onLike(posts[i]),
              liked: isLiked(posts[i]),
            ),
            if (i != posts.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F3F5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HomeLockedOwnerMiniList extends StatelessWidget {
  final int count;
  final bool compactTopPadding;

  const HomeLockedOwnerMiniList({
    super.key,
    required this.count,
    this.compactTopPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    if (count <= 0) {
      return _HomeEmptyState(
        message: '사장님 게시판 인기글이 없습니다.',
        compactTopPadding: compactTopPadding,
      );
    }

    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compactTopPadding) const SizedBox(height: 2),
          for (int i = 0; i < count; i++) ...[
            const HomeLockedOwnerRow(),
            if (i != count - 1)
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F3F5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class HomeLockedOwnerRow extends StatelessWidget {
  const HomeLockedOwnerRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '사장님 인증 사용자만 열람 가능합니다.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HomeLatestEmptyState extends StatelessWidget {
  const HomeLatestEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeEmptyState(
      message: '최신글이 아직 없습니다.',
      compactTopPadding: true,
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  final String message;
  final bool compactTopPadding;

  const _HomeEmptyState({
    required this.message,
    this.compactTopPadding = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        compactTopPadding ? 12 : 14,
        16,
        16,
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }
}

class _HeaderBadge extends StatelessWidget {
  final String text;
  final Color accentColor;

  const _HeaderBadge({
    required this.text,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: accentColor.withOpacity(0.16),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: accentColor,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}
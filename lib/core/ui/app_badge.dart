import 'package:flutter/material.dart';

enum UserAuthBadge {
  neighbor,
  owner,
  verified,
}

enum AppBadgeTone {
  soft,
  outline,
  solid,
}

class AuthBadge extends StatelessWidget {
  final UserAuthBadge type;

  const AuthBadge({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case UserAuthBadge.neighbor:
        return const AppBadge(
          text: '이웃',
          icon: Icons.person_outline,
          tone: AppBadgeTone.soft,
          color: Color(0xFF6B7280),
        );
      case UserAuthBadge.owner:
        return const AppBadge(
          text: '사장님',
          icon: Icons.storefront_outlined,
          tone: AppBadgeTone.soft,
          color: Color(0xFFA56E5F),
        );
      case UserAuthBadge.verified:
        return const AppBadge(
          text: '인증',
          icon: Icons.verified_outlined,
          tone: AppBadgeTone.soft,
          color: Color(0xFF2563EB),
        );
    }
  }
}

class AppBadge extends StatelessWidget {
  final UserAuthBadge? authBadge;

  final String? text;
  final IconData? icon;
  final AppBadgeTone tone;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const AppBadge({
    super.key,
    this.authBadge,
    this.text,
    this.icon,
    this.tone = AppBadgeTone.soft,
    this.color,
    this.padding,
  });

  String get _resolvedText {
    final direct = text?.trim();
    if (direct != null && direct.isNotEmpty) return direct;

    switch (authBadge) {
      case UserAuthBadge.neighbor:
        return '이웃';
      case UserAuthBadge.owner:
        return '사장님';
      case UserAuthBadge.verified:
        return '인증';
      case null:
        return '';
    }
  }

  IconData? get _resolvedIcon {
    if (icon != null) return icon;

    switch (authBadge) {
      case UserAuthBadge.neighbor:
        return Icons.person_outline;
      case UserAuthBadge.owner:
        return Icons.storefront_outlined;
      case UserAuthBadge.verified:
        return Icons.verified_outlined;
      case null:
        return null;
    }
  }

  Color get _resolvedColor {
    if (color != null) return color!;

    switch (authBadge) {
      case UserAuthBadge.neighbor:
        return const Color(0xFF6B7280);
      case UserAuthBadge.owner:
        return const Color(0xFFA56E5F);
      case UserAuthBadge.verified:
        return const Color(0xFF2563EB);
      case null:
        return const Color(0xFF6B7280);
    }
  }

  Color _backgroundColor(Color base) {
    switch (tone) {
      case AppBadgeTone.soft:
        return base.withOpacity(0.10);
      case AppBadgeTone.outline:
        return Colors.white;
      case AppBadgeTone.solid:
        return base;
    }
  }

  Color _borderColor(Color base) {
    switch (tone) {
      case AppBadgeTone.soft:
        return Colors.transparent;
      case AppBadgeTone.outline:
        return base.withOpacity(0.35);
      case AppBadgeTone.solid:
        return Colors.transparent;
    }
  }

  Color _foregroundColor(Color base) {
    switch (tone) {
      case AppBadgeTone.soft:
      case AppBadgeTone.outline:
        return base;
      case AppBadgeTone.solid:
        return Colors.white;
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _resolvedText;
    final resolvedIcon = _resolvedIcon;

    if (label.isEmpty && resolvedIcon == null) {
      return const SizedBox.shrink();
    }

    final base = _resolvedColor;
    final fg = _foregroundColor(base);

    return Container(
      padding: padding ??
          const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
      decoration: BoxDecoration(
        color: _backgroundColor(base),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _borderColor(base),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (resolvedIcon != null) ...[
            Icon(
              resolvedIcon,
              size: 13,
              color: fg,
            ),
            if (label.isNotEmpty) const SizedBox(width: 4),
          ],
          if (label.isNotEmpty)
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                height: 1.0,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
        ],
      ),
    );
  }
}
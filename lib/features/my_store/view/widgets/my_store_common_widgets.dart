import 'package:flutter/material.dart';

import 'package:yupgagae/features/my_store/domain/store_profile.dart';

const Color kMyStoreAccent = Color(0xFFA56E5F);
const Color kMyStoreAccentDark = Color(0xFF875646);
const Color kMyStoreSoft = Color(0xFFF5ECE8);

class MetaChip extends StatelessWidget {
  final String label;

  const MetaChip({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF4B5563),
        ),
      ),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;

  const CountBadge({
    super.key,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kMyStoreAccentDark,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class SheetEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SheetEmptyState({
    super.key,
    required this.icon,
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
            Icon(
              icon,
              size: 30,
              color: const Color(0xFF9CA3AF),
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

class CenteredState extends StatelessWidget {
  final Widget child;

  const CenteredState({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(child: child);
  }
}

class ProfileHeader extends StatelessWidget {
  final StoreProfile profile;

  const ProfileHeader({
    super.key,
    required this.profile,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.nickname,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: Color(0xFF111111),
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              InlineTag(label: profile.region),
              InlineTag(label: profile.industry),
              if (profile.isIdentityVerified) const InlineTag(label: '본인 인증'),
              if (profile.isOwnerVerified) const InlineTag(label: '사업자 인증'),
            ],
          ),
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;

  const SectionHeader({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w900,
        color: Color(0xFF111111),
      ),
    );
  }
}

class SectionGroup extends StatelessWidget {
  final List<Widget> children;

  const SectionGroup({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(children: children),
    );
  }
}

class InlineTag extends StatelessWidget {
  final String label;

  const InlineTag({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: Color(0xFF374151),
        ),
      ),
    );
  }
}

class LineSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool emphasis;
  final bool showDivider;

  const LineSettingTile({
    super.key,
    required this.title,
    required this.subtitle,
    this.emphasis = false,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: emphasis
                      ? const Color(0xFF111111)
                      : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
      ],
    );
  }
}

class ArrowSettingTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget trailing;
  final bool showDivider;

  const ArrowSettingTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.trailing,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Opacity(
                    opacity: onTap == null ? 0.55 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: trailing,
                ),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: Color(0xFFF1F3F5)),
      ],
    );
  }
}

class SwitchLineTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool isBusy;
  final ValueChanged<bool>? onChanged;

  const SwitchLineTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.isBusy,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Opacity(
                    opacity: onChanged == null ? 0.55 : 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111111),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (isBusy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Switch(
                  value: value,
                  onChanged: onChanged,
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F3F5)),
      ],
    );
  }
}
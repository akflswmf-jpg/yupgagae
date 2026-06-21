import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_theme.dart';

class YeopAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title; // null이면 "옆가게" 브랜드 타이틀
  final bool showBrand; // 좌측 브랜드 고정 여부
  final bool showSearch;
  final bool showSettings;

  final VoidCallback? onTapBrand;
  final VoidCallback? onTapSearch;
  final VoidCallback? onTapSettings;

  const YeopAppBar({
    super.key,
    this.title,
    this.showBrand = true,
    this.showSearch = true,
    this.showSettings = true,
    this.onTapBrand,
    this.onTapSearch,
    this.onTapSettings,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Widget left;
    if (showBrand) {
      left = InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTapBrand,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ✅ 로고 대신 텍스트 먼저(앵꼬 방지: 나중에 로고로 교체 쉬움)
              Text(
                '옆가게',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (title != null) ...[
                const SizedBox(width: AppSpace.xs),
                Container(
                  width: 1,
                  height: 14,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: AppSpace.xs),
                Text(
                  title!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    } else {
      left = Text(
        title ?? '',
        style: theme.textTheme.titleMedium,
      );
    }

    return AppBar(
      leadingWidth: showBrand ? 140 : null,
      automaticallyImplyLeading: !showBrand,
      titleSpacing: showBrand ? 0 : null,
      title: left,
      actions: [
        if (showSearch)
          IconButton(
            tooltip: '검색',
            onPressed: onTapSearch,
            icon: const Icon(Icons.search_rounded),
          ),
        if (showSettings)
          IconButton(
            tooltip: '설정',
            onPressed: onTapSettings,
            icon: const Icon(Icons.settings_rounded),
          ),
        const SizedBox(width: AppSpace.xs),
      ],
    );
  }
}
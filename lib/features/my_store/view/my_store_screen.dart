import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/view/widgets/my_store_activity_screens.dart';
import 'package:yupgagae/features/my_store/view/widgets/my_store_body.dart';
import 'package:yupgagae/features/my_store/view/widgets/my_store_bottom_sheets.dart';
import 'package:yupgagae/features/my_store/view/widgets/nickname_edit_screen.dart';

class MyStoreScreen extends StatelessWidget {
  const MyStoreScreen({super.key});

  Future<void> _showNicknameSheet(
    BuildContext context,
    MyStoreController c,
    StoreProfile profile,
  ) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await Future.delayed(const Duration(milliseconds: 120));

    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => NicknameEditScreen(
          initialValue: profile.nickname,
        ),
      ),
    );

    if (result == null) return;

    final normalized = result.trim();
    if (normalized.isEmpty) return;
    if (normalized == profile.nickname.trim()) return;

    try {
      await c.changeNickname(normalized);
      AppToast.show('닉네임이 변경되었습니다.', title: '완료');
    } catch (e) {
      AppToast.show('$e', title: '실패', isError: true);
    }
  }

  Future<void> _showRegionSheet(
    BuildContext context,
    MyStoreController c,
    StoreProfile profile,
  ) async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '지역 변경',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: StoreProfile.regionOptions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F3F5)),
                  itemBuilder: (ctx, index) {
                    final region = StoreProfile.regionOptions[index];
                    final isSelected = region == profile.region;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      title: Text(
                        region,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF111111))
                          : const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFB0B8C1),
                            ),
                      onTap: () => Navigator.of(ctx).pop(region),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      await c.changeRegion(result);
      AppToast.show('지역이 변경되었습니다.', title: '완료');
    } catch (e) {
      AppToast.show('$e', title: '실패', isError: true);
    }
  }

  Future<void> _showIndustrySheet(
    BuildContext context,
    MyStoreController c,
    StoreProfile profile,
  ) async {
    final items = IndustryCatalog.ordered();

    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '업종 변경',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F3F5)),
                  itemBuilder: (ctx, index) {
                    final item = items[index];
                    final isSelected = item.name == profile.industry;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 2,
                      ),
                      leading: Icon(item.icon, color: item.color),
                      title: Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111111),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xFF111111))
                          : const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFB0B8C1),
                            ),
                      onTap: () => Navigator.of(ctx).pop(item.name),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (result == null) return;

    try {
      await c.changeIndustry(result);
      AppToast.show('업종이 변경되었습니다.', title: '완료');
    } catch (e) {
      AppToast.show('$e', title: '실패', isError: true);
    }
  }

  Future<void> _showInquiryDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
          contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: const Text(
            '의견 보내기',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
          ),
          content: const Text(
            '의견 보내기 기능은 다음 단계에서 연결됩니다.\n\n지금은 화면 구조만 먼저 정리한 상태입니다.',
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Color(0xFF4B5563),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF111111),
              ),
              child: const Text(
                '확인',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showNotificationsSheet(
    BuildContext context,
    MyStoreController c,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NotificationsBottomSheet(controller: c),
    );
  }

  Future<void> _showBlockedUsersSheet(
    BuildContext context,
    MyStoreController c,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => BlockedUsersBottomSheet(controller: c),
    );
  }

  Future<void> _openMyPosts(
    BuildContext context,
    MyStoreController c,
  ) async {
    await c.loadMyPosts(force: true);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyPostsScreen(controller: c),
      ),
    );
  }

  Future<void> _openMyComments(
    BuildContext context,
    MyStoreController c,
  ) async {
    await c.loadMyComments(force: true);
    if (!context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MyCommentsScreen(controller: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = Get.find<MyStoreController>();

    return Scaffold(
      body: SafeArea(
        child: MyStoreBody(
          controller: c,
          onShowNicknameSheet: (profile) => _showNicknameSheet(context, c, profile),
          onShowRegionSheet: (profile) => _showRegionSheet(context, c, profile),
          onShowIndustrySheet: (profile) => _showIndustrySheet(context, c, profile),
          onShowInquiryDialog: () => _showInquiryDialog(context),
          onShowNotificationsSheet: () => _showNotificationsSheet(context, c),
          onShowBlockedUsersSheet: () => _showBlockedUsersSheet(context, c),
          onOpenMyPosts: () => _openMyPosts(context, c),
          onOpenMyComments: () => _openMyComments(context, c),
        ),
      ),
    );
  }
}
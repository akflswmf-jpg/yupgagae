import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/features/admin/view/admin_notice_write_screen.dart';
import 'package:yupgagae/features/admin/view/admin_reported_comments_screen.dart';
import 'package:yupgagae/features/admin/view/admin_reported_posts_screen.dart';

class AdminMenuScreen extends StatelessWidget {
  const AdminMenuScreen({super.key});

  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kPrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kBorder = Color(0xFFEDE7E3);

  AuthController? _findAuthControllerOrNull() {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>();
  }

  void _openPreparingScreen(String title) {
    Get.to(
      () => AdminPreparingScreen(title: title),
      transition: Transition.rightToLeft,
    );
  }

  void _openReportedPostsScreen() {
    Get.to(
      () => const AdminReportedPostsScreen(),
      transition: Transition.rightToLeft,
    );
  }

  void _openReportedCommentsScreen() {
    Get.to(
      () => const AdminReportedCommentsScreen(),
      transition: Transition.rightToLeft,
    );
  }

  void _openNoticeWriteScreen() {
    Get.to(
      () => const AdminNoticeWriteScreen(),
      transition: Transition.rightToLeft,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = _findAuthControllerOrNull();

    if (auth == null) {
      return const _AdminAccessDeniedScreen(
        message: '계정 정보를 확인할 수 없습니다.',
      );
    }

    return Obx(() {
      final initialized = auth.isInitialized.value;
      final user = auth.currentUser.value;

      if (!initialized) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }

      if (!PermissionPolicy.canAccessAdmin(user)) {
        return const _AdminAccessDeniedScreen(
          message: '관리자 권한이 있는 계정만 접근할 수 있습니다.',
        );
      }

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            '관리자 메뉴',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _kTextStrong,
              letterSpacing: -0.3,
            ),
          ),
          leading: IconButton(
            onPressed: Get.back,
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: _kTextStrong,
            ),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
                decoration: BoxDecoration(
                  color: _kPrimarySoft,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _kBorder),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 22,
                      color: _kPrimary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '관리자 권한이 확인되었습니다.\n공지 작성, 신고 게시글, 신고 댓글 확인 기능이 연결되었습니다.',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                          color: _kTextNormal,
                          letterSpacing: -0.15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const _AdminSectionHeader(title: '신고 관리'),
              const SizedBox(height: 10),
              _AdminSectionGroup(
                children: [
                  _AdminMenuTile(
                    icon: Icons.article_outlined,
                    title: '신고된 게시글',
                    subtitle: '신고 누적 게시글을 확인합니다',
                    onTap: _openReportedPostsScreen,
                  ),
                  _AdminMenuTile(
                    icon: Icons.mode_comment_outlined,
                    title: '신고된 댓글',
                    subtitle: '신고 누적 댓글을 확인합니다',
                    onTap: _openReportedCommentsScreen,
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _AdminSectionHeader(title: '운영 관리'),
              const SizedBox(height: 10),
              _AdminSectionGroup(
                children: [
                  _AdminMenuTile(
                    icon: Icons.campaign_outlined,
                    title: '공지 작성',
                    subtitle: '서비스 공지를 작성합니다',
                    onTap: _openNoticeWriteScreen,
                  ),
                  _AdminMenuTile(
                    icon: Icons.block_outlined,
                    title: '유저 제재 관리',
                    subtitle: '정지, 제한 등 유저 상태를 관리합니다',
                    onTap: () => _openPreparingScreen('유저 제재 관리'),
                    showDivider: false,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }
}

class AdminPreparingScreen extends StatelessWidget {
  final String title;

  const AdminPreparingScreen({
    super.key,
    required this.title,
  });

  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _kTextStrong,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: _kTextStrong,
          ),
        ),
      ),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.construction_rounded,
                  size: 42,
                  color: _kPrimary,
                ),
                SizedBox(height: 14),
                Text(
                  '준비 중',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: _kTextStrong,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '아직 실제 기능은 연결되지 않았습니다.\n관리자 기능 서버 작업 때 이 화면에 연결하면 됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: _kTextNormal,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAccessDeniedScreen extends StatelessWidget {
  final String message;

  const _AdminAccessDeniedScreen({
    required this.message,
  });

  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '관리자 메뉴',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _kTextStrong,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: _kTextStrong,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: _kTextNormal,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSectionHeader extends StatelessWidget {
  final String title;

  const _AdminSectionHeader({
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w900,
        color: Color(0xFF8A817C),
        letterSpacing: -0.15,
      ),
    );
  }
}

class _AdminSectionGroup extends StatelessWidget {
  final List<Widget> children;

  const _AdminSectionGroup({
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE7E3)),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _AdminMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _AdminMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: onTap,
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6EEEA),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Icon(
                      icon,
                      size: 19,
                      color: const Color(0xFFA56E5F),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF25211F),
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8A817C),
                            height: 1.35,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB0B8C1),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFF1F3F5)),
      ],
    );
  }
}
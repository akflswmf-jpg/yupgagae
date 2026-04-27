import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/view/widgets/my_store_common_widgets.dart';
import 'package:yupgagae/routes/app_routes.dart';

class MyStoreBody extends StatelessWidget {
  final MyStoreController controller;
  final Future<void> Function(StoreProfile profile) onShowNicknameSheet;
  final Future<void> Function(StoreProfile profile) onShowRegionSheet;
  final Future<void> Function(StoreProfile profile) onShowIndustrySheet;
  final Future<void> Function() onShowInquiryDialog;
  final Future<void> Function() onShowNotificationsSheet;
  final Future<void> Function() onShowBlockedUsersSheet;
  final Future<void> Function() onOpenMyPosts;
  final Future<void> Function() onOpenMyComments;

  const MyStoreBody({
    super.key,
    required this.controller,
    required this.onShowNicknameSheet,
    required this.onShowRegionSheet,
    required this.onShowIndustrySheet,
    required this.onShowInquiryDialog,
    required this.onShowNotificationsSheet,
    required this.onShowBlockedUsersSheet,
    required this.onOpenMyPosts,
    required this.onOpenMyComments,
  });

  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kPrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  void _openLogin() {
    Get.toNamed(AppRoutes.login);
  }

  Future<void> _mockVerifyIdentity(AuthController auth) async {
    try {
      await auth.mockVerifyIdentity();
      AppToast.show('본인 인증 mock 처리가 완료되었습니다.', title: '완료');
    } catch (e) {
      AppToast.show('$e', title: '실패', isError: true);
    }
  }

  Future<void> _mockVerifyBusiness(AuthController auth) async {
    try {
      await auth.mockVerifyBusiness();
      AppToast.show('사업자 인증 mock 처리가 완료되었습니다.', title: '완료');
    } catch (e) {
      AppToast.show('$e', title: '실패', isError: true);
    }
  }

  AuthController? _findAuthControllerOrNull() {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>();
  }

  Widget _buildAccountCard() {
    final auth = _findAuthControllerOrNull();

    if (auth == null) {
      return _AccountFallbackCard(
        onTap: _openLogin,
      );
    }

    return Obx(() {
      final initialized = auth.isInitialized.value;
      final user = auth.currentUser.value;

      if (!initialized) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _kBorder),
          ),
          child: const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '계정 상태를 확인하는 중입니다.',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _kTextNormal,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        );
      }

      if (user == null) {
        return Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            onTap: _openLogin,
            borderRadius: BorderRadius.circular(18),
            splashFactory: NoSplash.splashFactory,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _kBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _kPrimarySoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Icon(
                      Icons.login_rounded,
                      size: 20,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '계정 로그인',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: _kTextStrong,
                            letterSpacing: -0.25,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          '본인인증과 사업자 인증을 연결하려면\n로그인이 필요합니다.',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _kTextSoft,
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
        );
      }

      final email = user.email ?? '이메일 없음';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: _kPrimarySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                size: 20,
                color: _kPrimary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '계정 연결됨',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: _kTextStrong,
                      letterSpacing: -0.25,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _kTextSoft,
                      height: 1.35,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: _openLogin,
              style: TextButton.styleFrom(
                foregroundColor: _kPrimary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                '관리',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildVerificationSection() {
    final auth = _findAuthControllerOrNull();

    if (auth == null) {
      return SectionGroup(
        children: [
          _VerificationTile(
            title: '본인 인증',
            subtitle: '로그인이 필요합니다',
            statusText: '로그인 필요',
            statusKind: _VerificationStatusKind.required,
            onTap: _openLogin,
          ),
          _VerificationTile(
            title: '사업자 인증',
            subtitle: '로그인이 필요합니다',
            statusText: '로그인 필요',
            statusKind: _VerificationStatusKind.required,
            onTap: _openLogin,
            showDivider: false,
          ),
        ],
      );
    }

    return Obx(() {
      final initialized = auth.isInitialized.value;
      final user = auth.currentUser.value;
      final isMockVerifyingIdentity = auth.isMockVerifyingIdentity.value;
      final isMockVerifyingBusiness = auth.isMockVerifyingBusiness.value;

      if (!initialized) {
        return const SectionGroup(
          children: [
            _VerificationTile(
              title: '본인 인증',
              subtitle: '계정 상태를 확인하는 중입니다',
              statusText: '확인 중',
              statusKind: _VerificationStatusKind.loading,
            ),
            _VerificationTile(
              title: '사업자 인증',
              subtitle: '계정 상태를 확인하는 중입니다',
              statusText: '확인 중',
              statusKind: _VerificationStatusKind.loading,
              showDivider: false,
            ),
          ],
        );
      }

      if (user == null) {
        return SectionGroup(
          children: [
            _VerificationTile(
              title: '본인 인증',
              subtitle: '로그인 후 본인 인증을 진행할 수 있습니다',
              statusText: '로그인 필요',
              statusKind: _VerificationStatusKind.required,
              onTap: _openLogin,
            ),
            _VerificationTile(
              title: '사업자 인증',
              subtitle: '로그인 후 사업자 인증을 진행할 수 있습니다',
              statusText: '로그인 필요',
              statusKind: _VerificationStatusKind.required,
              onTap: _openLogin,
              showDivider: false,
            ),
          ],
        );
      }

      return SectionGroup(
        children: [
          _VerificationTile(
            title: '본인 인증',
            subtitle: _identitySubtitle(user),
            statusText: _statusLabel(user.identityStatus),
            statusKind: _statusKind(user.identityStatus),
            isBusy: isMockVerifyingIdentity,
            onTap: user.isIdentityVerified || isMockVerifyingIdentity
                ? null
                : () => _mockVerifyIdentity(auth),
          ),
          _VerificationTile(
            title: '사업자 인증',
            subtitle: _businessSubtitle(user),
            statusText: _statusLabel(user.businessStatus),
            statusKind: _statusKind(user.businessStatus),
            isBusy: isMockVerifyingBusiness,
            onTap: user.isBusinessVerified || isMockVerifyingBusiness
                ? null
                : () => _mockVerifyBusiness(auth),
            showDivider: false,
          ),
        ],
      );
    });
  }

  String _identitySubtitle(AppUser user) {
    switch (user.identityStatus) {
      case 'verified':
        return '본인 인증이 완료되었습니다';
      case 'pending':
        return '본인 인증 확인이 진행 중입니다';
      case 'failed':
        return '본인 인증에 실패했습니다. 다시 시도해주세요';
      case 'locked':
        return '실패 횟수 초과로 일시 제한되었습니다';
      case 'none':
      default:
        return '실명 기반 인증을 연결할 수 있습니다';
    }
  }

  String _businessSubtitle(AppUser user) {
    switch (user.businessStatus) {
      case 'verified':
        return '사업자 인증이 완료되었습니다';
      case 'pending':
        return '사업자 정보 확인이 진행 중입니다';
      case 'failed':
        return '사업자 인증에 실패했습니다. 다시 시도해주세요';
      case 'locked':
        return '실패 횟수 초과로 일시 제한되었습니다';
      case 'none':
      default:
        return '사장님 게시판 이용을 위해 필요합니다';
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'verified':
        return '완료';
      case 'pending':
        return '확인 중';
      case 'failed':
        return '실패';
      case 'locked':
        return '제한됨';
      case 'none':
      default:
        return '미완료';
    }
  }

  _VerificationStatusKind _statusKind(String status) {
    switch (status) {
      case 'verified':
        return _VerificationStatusKind.verified;
      case 'pending':
        return _VerificationStatusKind.pending;
      case 'failed':
        return _VerificationStatusKind.failed;
      case 'locked':
        return _VerificationStatusKind.locked;
      case 'none':
      default:
        return _VerificationStatusKind.none;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value) {
        return const CenteredState(
          child: CircularProgressIndicator(),
        );
      }

      final error = controller.error.value;
      if (error != null) {
        return CenteredState(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.5,
              ),
            ),
          ),
        );
      }

      final profile = controller.profile.value;
      if (profile == null) {
        return const CenteredState(
          child: Text(
            '내가게 정보가 없습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
          ),
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          ProfileHeader(profile: profile),
          const SizedBox(height: 12),
          _buildAccountCard(),
          const SizedBox(height: 24),
          const SectionHeader(title: '인증 상태'),
          const SizedBox(height: 10),
          _buildVerificationSection(),
          const SizedBox(height: 28),
          const SectionHeader(title: '내 활동'),
          const SizedBox(height: 10),
          SectionGroup(
            children: [
              Obx(() {
                final unread = controller.unreadNotificationCount;

                return ArrowSettingTile(
                  title: '알림함',
                  subtitle: unread > 0 ? '읽지 않은 알림 $unread개' : '새 알림이 없습니다',
                  onTap: onShowNotificationsSheet,
                  trailing: unread > 0
                      ? CountBadge(count: unread)
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B8C1),
                        ),
                );
              }),
              Obx(() {
                final isLoading = controller.isLoadingMyPosts.value;
                final count = controller.myPosts.length;

                return ArrowSettingTile(
                  title: '내가 쓴 글',
                  subtitle: isLoading
                      ? '불러오는 중입니다'
                      : count > 0
                          ? '작성한 글 $count개'
                          : '작성한 글을 확인할 수 있습니다',
                  onTap: isLoading ? null : onOpenMyPosts,
                  trailing: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B8C1),
                        ),
                );
              }),
              Obx(() {
                final isLoading = controller.isLoadingMyComments.value;
                final count = controller.myComments.length;

                return ArrowSettingTile(
                  title: '내가 쓴 댓글',
                  subtitle: isLoading
                      ? '불러오는 중입니다'
                      : count > 0
                          ? '작성한 댓글 $count개'
                          : '작성한 댓글을 확인할 수 있습니다',
                  onTap: isLoading ? null : onOpenMyComments,
                  trailing: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B8C1),
                        ),
                  showDivider: false,
                );
              }),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: '설정'),
          const SizedBox(height: 10),
          SectionGroup(
            children: [
              Obx(() {
                final current = controller.profile.value;
                final currentProfile = current ?? profile;

                return ArrowSettingTile(
                  title: '닉네임 변경',
                  subtitle: '현재 닉네임 ${currentProfile.nickname}',
                  onTap: controller.isSavingNickname.value
                      ? null
                      : () => onShowNicknameSheet(currentProfile),
                  trailing: controller.isSavingNickname.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B8C1),
                        ),
                );
              }),
              Obx(() {
                final current = controller.profile.value;
                final currentProfile = current ?? profile;

                return ArrowSettingTile(
                  title: '업종 변경',
                  subtitle: '현재 업종 ${currentProfile.industry}',
                  onTap: controller.isSavingIndustry.value
                      ? null
                      : () => onShowIndustrySheet(currentProfile),
                  trailing: controller.isSavingIndustry.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B8C1),
                        ),
                );
              }),
              Obx(() {
                final current = controller.profile.value;
                final currentProfile = current ?? profile;

                return ArrowSettingTile(
                  title: '지역 변경',
                  subtitle: '현재 지역 ${currentProfile.region}',
                  onTap: controller.isSavingRegion.value
                      ? null
                      : () => onShowRegionSheet(currentProfile),
                  trailing: controller.isSavingRegion.value
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.chevron_right,
                          color: Color(0xFFB0B8C1),
                        ),
                );
              }),
              Obx(() {
                final current = controller.profile.value;
                if (current == null) return const SizedBox.shrink();

                return SwitchLineTile(
                  title: '알림 설정',
                  subtitle:
                      current.notificationsEnabled ? '알림 받기 켜짐' : '알림 받기 꺼짐',
                  value: current.notificationsEnabled,
                  isBusy: controller.isSavingNotification.value,
                  onChanged: controller.isSavingNotification.value
                      ? null
                      : (value) async {
                          try {
                            await controller.setNotificationsEnabled(value);
                          } catch (e) {
                            AppToast.show('$e', title: '실패', isError: true);
                          }
                        },
                );
              }),
              Obx(() {
                final count = controller.blockedUsers.length;

                return ArrowSettingTile(
                  title: '차단 사용자 관리',
                  subtitle: count > 0 ? '현재 $count명 차단 중' : '차단한 사용자가 없습니다',
                  onTap: onShowBlockedUsersSheet,
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: Color(0xFFB0B8C1),
                  ),
                );
              }),
              ArrowSettingTile(
                title: '의견 보내기',
                subtitle: '서비스에 대한 의견을 남길 수 있습니다',
                onTap: () => onShowInquiryDialog(),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: Color(0xFFB0B8C1),
                ),
                showDivider: false,
              ),
            ],
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: '기타'),
          const SizedBox(height: 10),
          const SectionGroup(
            children: [
              LineSettingTile(
                title: '버전 정보',
                subtitle: '1.0.0',
                showDivider: false,
              ),
            ],
          ),
        ],
      );
    });
  }
}

class _AccountFallbackCard extends StatelessWidget {
  final VoidCallback onTap;

  const _AccountFallbackCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(15, 14, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: MyStoreBody._kBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: MyStoreBody._kPrimarySoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.login_rounded,
                  size: 20,
                  color: MyStoreBody._kPrimary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '계정 로그인',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: MyStoreBody._kTextStrong,
                        letterSpacing: -0.25,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      '본인인증과 사업자 인증을 연결하려면\n로그인이 필요합니다.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: MyStoreBody._kTextSoft,
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
    );
  }
}

enum _VerificationStatusKind {
  none,
  verified,
  pending,
  failed,
  locked,
  required,
  loading,
}

class _VerificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusText;
  final _VerificationStatusKind statusKind;
  final VoidCallback? onTap;
  final bool isBusy;
  final bool showDivider;

  const _VerificationTile({
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusKind,
    this.onTap,
    this.isBusy = false,
    this.showDivider = true,
  });

  Color get _statusColor {
    switch (statusKind) {
      case _VerificationStatusKind.verified:
        return const Color(0xFFA56E5F);
      case _VerificationStatusKind.pending:
        return const Color(0xFF2563EB);
      case _VerificationStatusKind.failed:
      case _VerificationStatusKind.locked:
        return const Color(0xFFE11D48);
      case _VerificationStatusKind.required:
      case _VerificationStatusKind.loading:
      case _VerificationStatusKind.none:
        return const Color(0xFF6B7280);
    }
  }

  Color get _statusBackground {
    switch (statusKind) {
      case _VerificationStatusKind.verified:
        return const Color(0xFFF6EEEA);
      case _VerificationStatusKind.pending:
        return const Color(0xFFEFF6FF);
      case _VerificationStatusKind.failed:
      case _VerificationStatusKind.locked:
        return const Color(0xFFFFF1F2);
      case _VerificationStatusKind.required:
      case _VerificationStatusKind.loading:
      case _VerificationStatusKind.none:
        return const Color(0xFFF3F4F6);
    }
  }

  bool get _showActionButton {
    return onTap != null &&
        statusKind != _VerificationStatusKind.verified &&
        statusKind != _VerificationStatusKind.loading;
  }

  String get _actionLabel {
    if (statusKind == _VerificationStatusKind.required) {
      return '로그인';
    }

    if (statusKind == _VerificationStatusKind.failed) {
      return '다시 시도';
    }

    return '인증하기';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF111111),
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _statusBackground,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w900,
                              color: _statusColor,
                              height: 1.1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF6B7280),
                        height: 1.4,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (_showActionButton) ...[
                const SizedBox(width: 12),
                SizedBox(
                  height: 34,
                  child: TextButton(
                    onPressed: isBusy ? null : onTap,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFA56E5F),
                      backgroundColor: const Color(0xFFF6EEEA),
                      disabledForegroundColor: const Color(0xFF9CA3AF),
                      disabledBackgroundColor: const Color(0xFFF3F4F6),
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: isBusy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _actionLabel,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.1,
                            ),
                          ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (showDivider) const Divider(height: 1, color: Color(0xFFF1F3F5)),
      ],
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/view/widgets/my_store_common_widgets.dart';

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
          const SizedBox(height: 24),
          const SectionHeader(title: '인증 상태'),
          const SizedBox(height: 10),
          SectionGroup(
            children: [
              LineSettingTile(
                title: '본인 인증',
                subtitle: profile.isIdentityVerified ? '완료' : '미완료',
                emphasis: profile.isIdentityVerified,
              ),
              LineSettingTile(
                title: '사업자 인증',
                subtitle: profile.isOwnerVerified ? '완료' : '미완료',
                emphasis: profile.isOwnerVerified,
                showDivider: false,
              ),
            ],
          ),
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
                  subtitle: current.notificationsEnabled ? '알림 받기 켜짐' : '알림 받기 꺼짐',
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
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/view/widgets/my_store_common_widgets.dart';
import 'package:yupgagae/routes/app_routes.dart';

class NotificationsBottomSheet extends StatelessWidget {
  final MyStoreController controller;

  const NotificationsBottomSheet({
    super.key,
    required this.controller,
  });

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _titleLabel(AppNotificationItem item) {
    switch (item.type.trim()) {
      case 'comment_post':
        return '댓글 알림';
      case 'reply_comment':
        return '답글 알림';
      case 'like_post':
        return '게시글 좋아요';
      case 'like_comment':
        return '댓글 좋아요';
      default:
        return '알림';
    }
  }

  Future<void> _openNotification(
    BuildContext context,
    AppNotificationItem item,
  ) async {
    await controller.markNotificationRead(item.id);

    final postId = item.targetPostId?.trim();
    if (postId == null || postId.isEmpty) {
      return;
    }

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    await Get.toNamed(
      AppRoutes.postDetail,
      arguments: {'postId': postId},
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '알림함',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: controller.notifications.isEmpty
                        ? null
                        : controller.markAllNotificationsRead,
                    style: TextButton.styleFrom(
                      foregroundColor: kMyStoreAccentDark,
                    ),
                    child: const Text(
                      '모두 읽음',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F3F5)),
            Expanded(
              child: Obx(() {
                final items = controller.notifications;
                if (items.isEmpty) {
                  return const SheetEmptyState(
                    icon: Icons.notifications_none_rounded,
                    title: '알림이 없습니다',
                    subtitle: '새로운 활동 알림이 생기면 이곳에 표시됩니다.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F3F5)),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return InkWell(
                      onTap: () => _openNotification(context, item),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: BoxDecoration(
                                color: item.isRead
                                    ? const Color(0xFFE5E7EB)
                                    : kMyStoreAccentDark,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _titleLabel(item),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF111111),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.message,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: Color(0xFF4B5563),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _timeLabel(item.createdAt),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF9CA3AF),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFFB0B8C1),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

class BlockedUsersBottomSheet extends StatelessWidget {
  final MyStoreController controller;

  const BlockedUsersBottomSheet({
    super.key,
    required this.controller,
  });

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _displayText(String? value, String fallback) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 5,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '차단 사용자 관리',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF111111),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF1F3F5)),
            Expanded(
              child: Obx(() {
                final items = controller.blockedUsers;
                if (items.isEmpty) {
                  return const SheetEmptyState(
                    icon: Icons.block_outlined,
                    title: '차단한 사용자가 없습니다',
                    subtitle: '차단한 사용자는 여기에 표시됩니다.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: Color(0xFFF1F3F5)),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: kMyStoreSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.block,
                              color: kMyStoreAccentDark,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.nickname,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF111111),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_displayText(item.region, '지역 미상')} · ${_displayText(item.industry, '업종 미상')}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '차단 시점 ${_timeLabel(item.blockedAt)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF9CA3AF),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: () async {
                              await controller.unblockUser(item.userId);
                              AppToast.show(
                                '${item.nickname} 차단을 해제했습니다.',
                                title: '완료',
                              );
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFE5484D),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: const Text(
                              '해제',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/admin/controller/admin_notice_write_controller.dart';

class AdminNoticeWriteScreen extends StatelessWidget {
  const AdminNoticeWriteScreen({super.key});

  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kPrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  AuthController? _findAuthControllerOrNull() {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>();
  }

  AdminNoticeWriteController _findOrPutController() {
    if (Get.isRegistered<AdminNoticeWriteController>()) {
      return Get.find<AdminNoticeWriteController>();
    }

    return Get.put(AdminNoticeWriteController());
  }

  Future<void> _submit(AdminNoticeWriteController c) async {
    try {
      await c.submit();

      FocusManager.instance.primaryFocus?.unfocus();
      AppToast.show('공지가 등록되었습니다.', title: '완료');

      Get.back();
    } catch (e) {
      AppToast.show('$e', title: '저장 실패', isError: true);
    }
  }

  void _handleBack(AdminNoticeWriteController c) {
    if (c.isSaving.value) return;

    FocusManager.instance.primaryFocus?.unfocus();
    Get.back();
  }

  @override
  Widget build(BuildContext context) {
    final auth = _findAuthControllerOrNull();

    if (auth == null) {
      return const _AdminNoticeAccessDeniedScreen(
        message: '계정 정보를 확인할 수 없습니다.',
      );
    }

    final c = _findOrPutController();

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
        return const _AdminNoticeAccessDeniedScreen(
          message: '관리자 권한이 있는 계정만 공지를 작성할 수 있습니다.',
        );
      }

      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          _handleBack(c);
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 0,
            centerTitle: true,
            title: const Text(
              '공지 작성',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: _kTextStrong,
                letterSpacing: -0.3,
              ),
            ),
            leading: IconButton(
              onPressed: c.isSaving.value ? null : () => _handleBack(c),
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 19,
                color: _kTextStrong,
              ),
            ),
            actions: [
              Obx(() {
                final isSaving = c.isSaving.value;
                c.formTick.value;
                final canSubmit = c.canSubmit;

                return TextButton(
                  onPressed: isSaving ? null : () => _submit(c),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        canSubmit ? _kPrimary : const Color(0xFF9CA3AF),
                    disabledForegroundColor: const Color(0xFFB0B8C1),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '등록',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                );
              }),
              const SizedBox(width: 6),
            ],
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                        Icons.campaign_rounded,
                        size: 22,
                        color: _kPrimary,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '홈 공지바에는 제목만 표시됩니다.\n공지바를 누르면 작성한 내용 전체를 확인할 수 있습니다.',
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
                const SizedBox(height: 24),
                const _AdminNoticeSectionHeader(title: '공지 내용'),
                const SizedBox(height: 10),
                GetBuilder<AdminNoticeWriteController>(
                  id: 'noticeForm',
                  builder: (_) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AdminNoticeTextField(
                          controller: c.titleController,
                          hintText: '공지 제목을 입력하세요',
                          maxLength: 60,
                          minLines: 1,
                          maxLines: 1,
                        ),
                        const SizedBox(height: 12),
                        _AdminNoticeTextField(
                          controller: c.bodyController,
                          hintText: '공지 내용을 입력하세요',
                          maxLength: 2000,
                          minLines: 8,
                          maxLines: 16,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                Obx(() {
                  final error = c.error.value;

                  if (error == null || error.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return Text(
                    error,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: Color(0xFFE11D48),
                      letterSpacing: -0.1,
                    ),
                  );
                }),
                const SizedBox(height: 28),
                Obx(() {
                  final isSaving = c.isSaving.value;
                  c.formTick.value;
                  final canSubmit = c.canSubmit;

                  return SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isSaving ? null : () => _submit(c),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            canSubmit ? _kPrimary : const Color(0xFFD1D5DB),
                        disabledBackgroundColor: const Color(0xFFE5E7EB),
                        foregroundColor: Colors.white,
                        disabledForegroundColor: const Color(0xFF9CA3AF),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              '공지 등록하기',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                    ),
                  );
                }),
                const SizedBox(height: 10),
                const Text(
                  '등록한 공지는 즉시 홈 상단 공지바에 반영됩니다.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _kTextSoft,
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _AdminNoticeTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final int maxLength;
  final int minLines;
  final int maxLines;

  const _AdminNoticeTextField({
    required this.controller,
    required this.hintText,
    required this.maxLength,
    required this.minLines,
    required this.maxLines,
  });

  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kBorder = Color(0xFFEDE7E3);

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: maxLength,
      minLines: minLines,
      maxLines: maxLines,
      cursorColor: const Color(0xFFA56E5F),
      textInputAction:
          maxLines == 1 ? TextInputAction.next : TextInputAction.newline,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        height: 1.45,
        color: _kTextStrong,
        letterSpacing: -0.2,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Color(0xFFB0B8C1),
          letterSpacing: -0.15,
        ),
        counterStyle: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: _kTextNormal,
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: _kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(
            color: Color(0xFFA56E5F),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}

class _AdminNoticeSectionHeader extends StatelessWidget {
  final String title;

  const _AdminNoticeSectionHeader({
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

class _AdminNoticeAccessDeniedScreen extends StatelessWidget {
  final String message;

  const _AdminNoticeAccessDeniedScreen({
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
          '공지 작성',
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

// END_OF_FILE: lib/features/admin/view/admin_notice_write_screen.dart
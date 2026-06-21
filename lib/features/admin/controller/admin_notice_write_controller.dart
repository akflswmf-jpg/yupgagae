import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/admin/domain/admin_notice_repository.dart';

class AdminNoticeWriteController extends GetxController {
  AdminNoticeWriteController({
    AdminNoticeRepository? repo,
  }) : repo = repo ?? FirebaseAdminNoticeRepository();

  final AdminNoticeRepository repo;

  final titleController = TextEditingController();
  final bodyController = TextEditingController();

  final isSaving = false.obs;
  final error = RxnString();

  final formTick = 0.obs;

  String get title => titleController.text.trim();
  String get body => bodyController.text.trim();

  bool get canSubmit {
    return title.isNotEmpty &&
        title.length <= 60 &&
        body.isNotEmpty &&
        body.length <= 2000 &&
        !isSaving.value;
  }

  @override
  void onInit() {
    super.onInit();
    titleController.addListener(_onTextChanged);
    bodyController.addListener(_onTextChanged);
  }

  @override
  void onClose() {
    titleController
      ..removeListener(_onTextChanged)
      ..dispose();

    bodyController
      ..removeListener(_onTextChanged)
      ..dispose();

    super.onClose();
  }

  void _onTextChanged() {
    formTick.value++;
    error.value = null;
    update(['noticeForm']);
  }

  String? validateForSubmit() {
    final normalizedTitle = title;
    final normalizedBody = body;

    if (normalizedTitle.isEmpty) {
      return '공지 제목을 입력해주세요.';
    }

    if (normalizedTitle.length > 60) {
      return '공지 제목은 60자 이하로 입력해주세요.';
    }

    if (normalizedBody.isEmpty) {
      return '공지 내용을 입력해주세요.';
    }

    if (normalizedBody.length > 2000) {
      return '공지 내용은 2000자 이하로 입력해주세요.';
    }

    return null;
  }

  Future<void> submit() async {
    if (isSaving.value) return;

    final validationMessage = validateForSubmit();
    if (validationMessage != null) {
      error.value = validationMessage;
      throw Exception(validationMessage);
    }

    try {
      isSaving.value = true;
      error.value = null;

      await repo
          .createNotice(
            title: title,
            body: body,
          )
          .timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('공지 저장 요청이 지연되고 있습니다.');
        },
      );
    } catch (e) {
      error.value = e.toString();
      rethrow;
    } finally {
      isSaving.value = false;
    }
  }
}

// END_OF_FILE: lib/features/admin/controller/admin_notice_write_controller.dart
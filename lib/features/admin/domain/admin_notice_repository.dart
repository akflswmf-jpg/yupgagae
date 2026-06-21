import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/features/admin/domain/admin_notice.dart';

abstract class AdminNoticeRepository {
  Future<AdminNotice> createNotice({
    required String title,
    required String body,
  });

  Stream<AdminNotice?> watchLatestVisibleNotice();
}

class FirebaseAdminNoticeRepository implements AdminNoticeRepository {
  FirebaseAdminNoticeRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _noticesRef {
    return _firestore.collection('notices');
  }

  @override
  Future<AdminNotice> createNotice({
    required String title,
    required String body,
  }) async {
    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();

    if (normalizedTitle.isEmpty) {
      throw Exception('공지 제목을 입력해주세요.');
    }

    if (normalizedTitle.length > 60) {
      throw Exception('공지 제목은 60자 이하로 입력해주세요.');
    }

    if (normalizedBody.isEmpty) {
      throw Exception('공지 내용을 입력해주세요.');
    }

    if (normalizedBody.length > 2000) {
      throw Exception('공지 내용은 2000자 이하로 입력해주세요.');
    }

    final auth = _requireAuthController();
    final user = auth.currentUser.value;

    if (!PermissionPolicy.canAccessAdmin(user)) {
      throw Exception('관리자 권한이 필요합니다.');
    }

    final adminUserId = user?.userId.trim() ?? '';

    if (adminUserId.isEmpty) {
      throw Exception('관리자 계정 정보를 확인할 수 없습니다.');
    }

    final docRef = _noticesRef.doc();

    final notice = AdminNotice(
      noticeId: docRef.id,
      title: normalizedTitle,
      body: normalizedBody,
      isVisible: true,
      isPinned: false,
      createdByUserId: adminUserId,
      createdAt: null,
      updatedAt: null,
    );

    await docRef.set(notice.toCreateMap());

    final saved = await docRef.get();
    return AdminNotice.fromFirestore(saved);
  }

  @override
  Stream<AdminNotice?> watchLatestVisibleNotice() {
    return _noticesRef
        .where('isVisible', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }

      return AdminNotice.fromFirestore(snapshot.docs.first);
    });
  }

  AuthController _requireAuthController() {
    if (!Get.isRegistered<AuthController>()) {
      throw Exception('로그인이 필요합니다.');
    }

    return Get.find<AuthController>();
  }
}

// END_OF_FILE: lib/features/admin/domain/admin_notice_repository.dart
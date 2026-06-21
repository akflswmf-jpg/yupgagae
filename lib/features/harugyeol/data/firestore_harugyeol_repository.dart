import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_comment.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_day_summary.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_entry.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_enums.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_repository.dart';

class FirestoreHarugyeolRepository implements HarugyeolRepository {
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;

  FirestoreHarugyeolRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : firestore = firestore ?? FirebaseFirestore.instance,
        functions = functions ??
            FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  CollectionReference<Map<String, dynamic>> get _daysCol {
    return firestore.collection('harugyeolDays');
  }

  AuthController? get _authOrNull {
    if (!Get.isRegistered<AuthController>()) {
      return null;
    }

    return Get.find<AuthController>();
  }

  String get _currentUserId {
    final userId = _authOrNull?.currentUser.value?.userId.trim();
    if (userId == null || userId.isEmpty) return '';
    return userId;
  }

  @override
  Stream<HarugyeolDaySummary> watchDaySummary(String dateKey) {
    final safeDateKey = dateKey.trim();

    if (safeDateKey.isEmpty) {
      return Stream.value(HarugyeolDaySummary.empty(dateKey));
    }

    return _daysCol.doc(safeDateKey).snapshots().map((doc) {
      return HarugyeolDaySummary.fromJson(
        safeDateKey,
        doc.data(),
      );
    });
  }

  @override
  Stream<List<HarugyeolEntry>> watchMyEntries(String dateKey) {
    final safeDateKey = dateKey.trim();
    final userId = _currentUserId;

    if (safeDateKey.isEmpty || userId.isEmpty) {
      return Stream.value(const <HarugyeolEntry>[]);
    }

    return _daysCol
        .doc(safeDateKey)
        .collection('entries')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) {
        return HarugyeolEntry.fromJson({
          ...doc.data(),
          'id': (doc.data()['id'] ?? doc.id).toString(),
        });
      }).toList();

      list.sort((a, b) => a.slot.key.compareTo(b.slot.key));
      return list;
    });
  }

  @override
  Stream<List<HarugyeolComment>> watchComments(String dateKey) {
    final safeDateKey = dateKey.trim();
    final userId = _currentUserId;

    if (safeDateKey.isEmpty) {
      return Stream.value(const <HarugyeolComment>[]);
    }

    return _daysCol
        .doc(safeDateKey)
        .collection('comments')
        .where('status', isEqualTo: 'active')
        .limit(50)
        .snapshots()
        .map((snap) {
      final list = snap.docs.map((doc) {
        return HarugyeolComment.fromJson(
          {
            ...doc.data(),
            'id': (doc.data()['id'] ?? doc.id).toString(),
          },
          currentUserId: userId,
        );
      }).where((comment) {
        return comment.text.trim().isNotEmpty;
      }).toList();

      list.sort((a, b) {
        final likeCompare = b.likeCount.compareTo(a.likeCount);
        if (likeCompare != 0) return likeCompare;

        return b.createdAt.compareTo(a.createdAt);
      });

      return list;
    });
  }

  @override
  Future<void> submitEntry(HarugyeolSubmitInput input) async {
    final user = _authOrNull?.currentUser.value;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (user.needsProfileSetup) {
      throw Exception('가입 설정을 먼저 완료해주세요.');
    }

    if (user.isWithdrawn || user.isSuspended) {
      throw Exception('현재 계정 상태에서는 이용할 수 없습니다.');
    }

    final callable = functions.httpsCallable('submitHarugyeolEntry');

    await callable.call({
      'dateKey': input.dateKey,
      'slot': input.slot.key,
      'mood': input.mood.key,
      'score': input.mood.score,
      'reasons': input.reasons.map((e) => e.key).toList(),
      'oneLineText': input.oneLineText.trim(),
      'clientUser': {
        'userId': user.userId,
        'authorLabel': user.nickname?.trim().isNotEmpty == true
            ? user.nickname!.trim()
            : '익명',
        'industryId': user.industry,
        'locationLabel': user.region,
        'isOwnerVerified': user.isBusinessVerified,
      },
    });
  }

  @override
  Future<void> toggleCommentLike({
    required String dateKey,
    required String commentId,
  }) async {
    final user = _authOrNull?.currentUser.value;

    if (user == null) {
      throw Exception('로그인이 필요합니다.');
    }

    if (user.needsProfileSetup) {
      throw Exception('가입 설정을 먼저 완료해주세요.');
    }

    final callable = functions.httpsCallable('toggleHarugyeolCommentLike');

    await callable.call({
      'dateKey': dateKey.trim(),
      'commentId': commentId.trim(),
    });
  }
}
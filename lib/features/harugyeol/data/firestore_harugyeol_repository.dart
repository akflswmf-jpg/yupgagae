import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/app_user.dart';
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

  AppUser? get _currentUser {
    return _authOrNull?.currentUser.value;
  }

  List<String> get _currentUserLookupIds {
    final user = _currentUser;
    if (user == null) {
      return const <String>[];
    }

    final ids = <String>[
      user.userId.trim(),
      user.firebaseUid.trim(),
    ].where((value) {
      return value.isNotEmpty;
    }).toSet().toList(growable: false);

    return ids;
  }

  String get _primaryCurrentUserId {
    final ids = _currentUserLookupIds;
    if (ids.isEmpty) return '';
    return ids.first;
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
    final lookupIds = _currentUserLookupIds;

    if (safeDateKey.isEmpty || lookupIds.isEmpty) {
      return Stream.value(const <HarugyeolEntry>[]);
    }

    final entriesCol = _daysCol.doc(safeDateKey).collection('entries');

    final docIds = <String>{
      for (final userId in lookupIds)
        for (final slot in HarugyeolSlot.values) '${userId}_${slot.key}',
    }.where((value) => value.trim().isNotEmpty).toList(growable: false);

    if (docIds.isEmpty) {
      return Stream.value(const <HarugyeolEntry>[]);
    }

    final controller = StreamController<List<HarugyeolEntry>>();
    final snapshotsByDocId = <String, DocumentSnapshot<Map<String, dynamic>>>{};
    final subscriptions = <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];

    void emit() {
      final bySlot = <HarugyeolSlot, HarugyeolEntry>{};

      for (final snapshot in snapshotsByDocId.values) {
        if (!snapshot.exists) continue;

        final data = snapshot.data();
        if (data == null) continue;

        final entry = HarugyeolEntry.fromJson({
          ...data,
          'id': (data['id'] ?? snapshot.id).toString(),
        });

        final previous = bySlot[entry.slot];

        if (previous == null || entry.updatedAt.isAfter(previous.updatedAt)) {
          bySlot[entry.slot] = entry;
        }
      }

      final list = bySlot.values.toList(growable: false);

      list.sort((a, b) {
        final slotCompare = a.slot.index.compareTo(b.slot.index);
        if (slotCompare != 0) return slotCompare;

        final dateCompare = a.createdAt.compareTo(b.createdAt);
        if (dateCompare != 0) return dateCompare;

        return a.id.compareTo(b.id);
      });

      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    for (final docId in docIds) {
      final sub = entriesCol.doc(docId).snapshots().listen(
        (snapshot) {
          snapshotsByDocId[docId] = snapshot;
          emit();
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!controller.isClosed) {
            controller.addError(error, stackTrace);
          }
        },
      );

      subscriptions.add(sub);
    }

    controller.onCancel = () async {
      for (final sub in subscriptions) {
        await sub.cancel();
      }
    };

    return controller.stream;
  }

  @override
  Stream<List<HarugyeolComment>> watchComments(String dateKey) {
    final safeDateKey = dateKey.trim();
    final userId = _primaryCurrentUserId;

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
        final data = doc.data();

        return HarugyeolComment.fromJson(
          {
            ...data,
            'id': (data['id'] ?? doc.id).toString(),
          },
          currentUserId: userId,
        );
      }).where((comment) {
        return comment.text.trim().isNotEmpty;
      }).toList();

      list.sort((a, b) {
        final likeCompare = b.likeCount.compareTo(a.likeCount);
        if (likeCompare != 0) return likeCompare;

        final dateCompare = b.createdAt.compareTo(a.createdAt);
        if (dateCompare != 0) return dateCompare;

        return a.id.compareTo(b.id);
      });

      return list;
    });
  }

  @override
  Future<void> submitEntry(HarugyeolSubmitInput input) async {
    final user = _currentUser;

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
      'dateKey': input.dateKey.trim(),
      'slot': input.slot.key,
      'mood': input.mood.key,
      'score': input.mood.score,
      'reasons': input.reasons.map((e) => e.key).toList(growable: false),
      'oneLineText': input.oneLineText.trim(),
      'clientUser': {
        'userId': user.userId.trim(),
        'firebaseUid': user.firebaseUid.trim(),
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
    final user = _currentUser;

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
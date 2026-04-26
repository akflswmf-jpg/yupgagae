import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class OwnerBoardController extends PostListController {
  final StoreProfileRepository storeProfileRepo;

  OwnerBoardController({
    required PostRepository repo,
    required AuthSessionService auth,
    required this.storeProfileRepo,
  }) : super(
          repo: repo,
          auth: auth,
          boardType: BoardType.owner,
        );

  final isOwnerVerified = false.obs;
  final isAccessLoading = false.obs;
  final accessError = RxnString();

  bool _prewarmStarted = false;
  Future<void>? _accessFuture;

  int _accessGeneration = 0;

  Future<void> prewarm() async {
    if (_prewarmStarted) return;
    _prewarmStarted = true;

    await ensureFeedInitialized();

    unawaited(refreshOwnerVerification());
  }

  Future<void> refreshOwnerVerification() {
    _accessFuture ??= _refreshOwnerVerificationInternal().whenComplete(() {
      _accessFuture = null;
    });

    return _accessFuture!;
  }

  Future<void> _refreshOwnerVerificationInternal() async {
    final generation = ++_accessGeneration;

    isAccessLoading.value = true;
    accessError.value = null;

    try {
      final profile = await storeProfileRepo.fetchProfile();

      if (!_isCurrentAccessRequest(generation)) {
        return;
      }

      isOwnerVerified.value = profile.isOwnerVerified;
    } catch (e) {
      if (!_isCurrentAccessRequest(generation)) {
        return;
      }

      isOwnerVerified.value = false;
      accessError.value = e.toString();
    } finally {
      if (_isCurrentAccessRequest(generation)) {
        isAccessLoading.value = false;
      }
    }
  }

  Future<bool> canWriteOwnerPost() async {
    try {
      await refreshOwnerVerification();
      return isOwnerVerified.value;
    } catch (_) {
      isOwnerVerified.value = false;
      return false;
    }
  }

  bool _isCurrentAccessRequest(int generation) {
    return _accessGeneration == generation;
  }
}
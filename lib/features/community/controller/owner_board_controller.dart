import 'package:get/get.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class OwnerBoardController extends PostListController {
  final AuthController authController;

  OwnerBoardController({
    required PostRepository repo,
    required AuthSessionService auth,
    required StoreProfileRepository storeProfileRepo,
    required this.authController,
  }) : super(
          repo: repo,
          auth: auth,
          storeProfileRepo: storeProfileRepo,
          boardType: BoardType.owner,
        );

  final isOwnerVerified = false.obs;
  final isAccessLoading = false.obs;
  final accessError = RxnString();

  bool _prewarmStarted = false;

  late final Worker _ownerVerificationWorker;

  AppUser? get _currentUser {
    return authController.currentUser.value;
  }

  bool get canWriteOwnerBoard {
    return PermissionPolicy.canWriteOwnerBoard(_currentUser);
  }

  String get ownerBoardBlockedMessage {
    return PermissionPolicy.ownerBoardWriteBlockedMessage(_currentUser);
  }

  Future<void> prewarm() async {
    if (_prewarmStarted) return;
    _prewarmStarted = true;

    await ensureFeedInitialized();
    await refreshOwnerVerification();
  }

  @override
  void onInit() {
    super.onInit();

    refreshOwnerVerification();

    _ownerVerificationWorker = ever(
      authController.currentUser,
      (_) => refreshOwnerVerification(),
    );
  }

  @override
  void onClose() {
    _ownerVerificationWorker.dispose();
    super.onClose();
  }

  Future<void> refreshOwnerVerification() async {
    isAccessLoading.value = true;
    accessError.value = null;

    try {
      final user = _currentUser;

      isOwnerVerified.value = PermissionPolicy.canWriteOwnerBoard(user);
    } catch (e) {
      isOwnerVerified.value = false;
      accessError.value = e.toString();
    } finally {
      isAccessLoading.value = false;
    }
  }

  Future<bool> canWriteOwnerPost() async {
    await refreshOwnerVerification();
    return isOwnerVerified.value;
  }
}
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';

class OwnerBoardController extends PostListController {
  final AuthController authController;

  OwnerBoardController({
    required PostRepository repo,
    required AuthSessionService auth,
    required this.authController,
  }) : super(
          repo: repo,
          auth: auth,
          boardType: BoardType.owner,
        );

  final isOwnerVerified = false.obs;
  final isAccessLoading = false.obs;
  final accessError = RxnString();

  bool _prewarmStarted = false;

  late final Worker _ownerVerificationWorker;

  Future<void> prewarm() async {
    if (_prewarmStarted) return;
    _prewarmStarted = true;

    await ensureFeedInitialized();
    refreshOwnerVerification();
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
      isOwnerVerified.value =
          authController.currentUser.value?.isBusinessVerified ?? false;
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
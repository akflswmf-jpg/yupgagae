import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class OwnerBoardController extends PostListController {
  final StoreProfileRepository storeProfileRepo;

  OwnerBoardController({
    required PostRepository repo,
    required AnonSessionService session,
    required this.storeProfileRepo,
  }) : super(
          repo: repo,
          session: session,
          boardType: BoardType.owner,
        );

  final isOwnerVerified = false.obs;
  final isAccessLoading = false.obs;
  final accessError = RxnString();

  bool _prewarmStarted = false;

  @override
  void onInit() {
    super.onInit();
  }

  Future<void> prewarm() async {
    if (_prewarmStarted) return;
    _prewarmStarted = true;

    await ensureFeedInitialized();

    Future<void>.delayed(const Duration(milliseconds: 16), () {
      refreshOwnerVerification();
    });
  }

  Future<void> refreshOwnerVerification() async {
    if (isAccessLoading.value) return;

    isAccessLoading.value = true;
    accessError.value = null;

    try {
      final profile = await storeProfileRepo.fetchProfile();
      isOwnerVerified.value = profile.isOwnerVerified;
    } catch (e) {
      isOwnerVerified.value = false;
      accessError.value = e.toString();
    } finally {
      isAccessLoading.value = false;
    }
  }

  Future<bool> canWriteOwnerPost() async {
    try {
      final profile = await storeProfileRepo.fetchProfile();
      isOwnerVerified.value = profile.isOwnerVerified;
      return profile.isOwnerVerified;
    } catch (_) {
      isOwnerVerified.value = false;
      return false;
    }
  }
}
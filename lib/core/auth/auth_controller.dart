import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/app_user.dart';
import 'package:yupgagae/core/auth/auth_repository.dart';

class AuthController extends GetxController {
  final AuthRepository repository;

  AuthController({
    required this.repository,
  });

  final Rxn<AppUser> currentUser = Rxn<AppUser>();
  final RxBool isInitialized = false.obs;
  final RxBool isSigningIn = false.obs;
  final RxBool isSigningOut = false.obs;
  final RxBool isMockVerifyingIdentity = false.obs;
  final RxBool isMockVerifyingBusiness = false.obs;
  final RxnString errorMessage = RxnString();

  StreamSubscription<AppUser?>? _userSubscription;

  bool get isLoggedIn => currentUser.value != null;

  bool get isOwnerVerified => currentUser.value?.isBusinessVerified ?? false;

  bool get isIdentityVerified => currentUser.value?.isIdentityVerified ?? false;

  String? get userId => currentUser.value?.userId;

  @override
  void onInit() {
    super.onInit();
    _bindUserStream();
  }

  @override
  void onClose() {
    _userSubscription?.cancel();
    super.onClose();
  }

  Future<void> signInWithGoogle() async {
    if (isSigningIn.value) return;

    isSigningIn.value = true;
    errorMessage.value = null;

    try {
      final user = await repository.signInWithGoogle();
      currentUser.value = user;
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isSigningIn.value = false;
    }
  }

  Future<void> signOut() async {
    if (isSigningOut.value) return;

    isSigningOut.value = true;
    errorMessage.value = null;

    try {
      await repository.signOut();
      currentUser.value = null;
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isSigningOut.value = false;
    }
  }

  Future<void> mockVerifyIdentity() async {
    if (isMockVerifyingIdentity.value) return;

    isMockVerifyingIdentity.value = true;
    errorMessage.value = null;

    try {
      await repository.mockVerifyIdentity();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isMockVerifyingIdentity.value = false;
    }
  }

  Future<void> mockVerifyBusiness() async {
    if (isMockVerifyingBusiness.value) return;

    isMockVerifyingBusiness.value = true;
    errorMessage.value = null;

    try {
      await repository.mockVerifyBusiness();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isMockVerifyingBusiness.value = false;
    }
  }

  void clearError() {
    errorMessage.value = null;
  }

  void _bindUserStream() {
    _userSubscription?.cancel();

    _userSubscription = repository.watchCurrentUser().listen(
      (user) {
        currentUser.value = user;
        isInitialized.value = true;
      },
      onError: (Object error) {
        errorMessage.value = _friendlyError(error);
        isInitialized.value = true;
      },
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();

    if (raw.contains('permission-denied')) {
      return '권한이 없습니다. Firestore 규칙을 확인해주세요.';
    }

    if (raw.contains('network')) {
      return '네트워크 상태를 확인해주세요.';
    }

    if (raw.contains('canceled') || raw.contains('cancelled')) {
      return '로그인이 취소되었습니다.';
    }

    if (raw.contains('popup_closed')) {
      return '로그인 창이 닫혔습니다.';
    }

    if (raw.contains('idToken')) {
      return '구글 로그인 토큰을 확인하지 못했습니다.';
    }

    if (raw.contains('로그인이 필요합니다')) {
      return '로그인이 필요합니다.';
    }

    return '처리 중 문제가 발생했습니다.';
  }
}
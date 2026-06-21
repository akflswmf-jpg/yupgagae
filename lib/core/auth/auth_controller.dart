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
  final RxBool isDeletingAccount = false.obs;
  final RxBool isAcknowledgingWarning = false.obs;
  final RxBool isCompletingProfileSetup = false.obs;
  final RxBool isUpdatingMyStoreProfile = false.obs;
  final RxBool isRestoringCurrentUser = false.obs;
  final RxBool isRefreshingCurrentUser = false.obs;
  final RxBool isVerifyingBusiness = false.obs;
  final RxnString errorMessage = RxnString();
  final RxnString noticeMessage = RxnString();

  StreamSubscription<AppUser?>? _userSubscription;

  bool _isExpectedSignedOut = false;

  bool get isLoggedIn => currentUser.value != null;

  bool get isOwnerVerified => currentUser.value?.isBusinessVerified ?? false;

  bool get isIdentityVerified => currentUser.value?.isIdentityVerified ?? false;

  bool get needsProfileSetup {
    final user = currentUser.value;
    if (user == null) return false;
    return user.needsProfileSetup;
  }

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

  Future<bool> waitUntilInitialized({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (isInitialized.value) {
      return true;
    }

    final completer = Completer<bool>();
    Worker? worker;
    Timer? timer;

    void completeOnce(bool value) {
      if (completer.isCompleted) return;

      timer?.cancel();
      worker?.dispose();
      completer.complete(value);
    }

    worker = ever<bool>(
      isInitialized,
      (initialized) {
        if (initialized) {
          completeOnce(true);
        }
      },
    );

    timer = Timer(
      timeout,
      () => completeOnce(isInitialized.value),
    );

    return completer.future;
  }

  Future<AppUser?> restoreCurrentUserForStartup() async {
    if (isRestoringCurrentUser.value) {
      return currentUser.value;
    }

    isRestoringCurrentUser.value = true;
    errorMessage.value = null;

    try {
      final user = await repository.currentUser();
      currentUser.value = user;
      isInitialized.value = true;

      if (user != null) {
        _isExpectedSignedOut = false;
      }

      return user;
    } catch (e) {
      if (_isExpectedSignedOut) {
        currentUser.value = null;
        errorMessage.value = null;
        noticeMessage.value = null;
        isInitialized.value = true;
        return null;
      }

      errorMessage.value = _friendlyError(e);
      isInitialized.value = true;
      rethrow;
    } finally {
      isRestoringCurrentUser.value = false;
    }
  }

  Future<void> signInWithGoogle({
    bool forceAccountSelection = false,
  }) async {
    if (isSigningIn.value) return;

    _isExpectedSignedOut = false;
    isSigningIn.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      final user = await repository.signInWithGoogle(
        forceAccountSelection: forceAccountSelection,
      );
      currentUser.value = user;
      isInitialized.value = true;
      noticeMessage.value = 'Google 로그인이 완료되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isSigningIn.value = false;
    }
  }

  Future<void> signInWithApple() async {
    if (isSigningIn.value) return;

    _isExpectedSignedOut = false;
    isSigningIn.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      final user = await repository.signInWithApple();
      currentUser.value = user;
      isInitialized.value = true;
      noticeMessage.value = 'Apple 로그인이 완료되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isSigningIn.value = false;
    }
  }

  Future<void> signInWithKakao() async {
    if (isSigningIn.value) return;

    _isExpectedSignedOut = false;
    isSigningIn.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      final user = await repository.signInWithKakao();
      currentUser.value = user;
      isInitialized.value = true;
      noticeMessage.value = '카카오 로그인이 완료되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
    } finally {
      isSigningIn.value = false;
    }
  }

  Future<void> completeProfileSetup({
    required bool termsAgreed,
    required String termsVersion,
    required bool pushAgreed,
    required String nickname,
    required String industry,
    required String region,
  }) async {
    if (isCompletingProfileSetup.value) return;

    isCompletingProfileSetup.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      final user = await repository.completeProfileSetup(
        termsAgreed: termsAgreed,
        termsVersion: termsVersion,
        pushAgreed: pushAgreed,
        nickname: nickname,
        industry: industry,
        region: region,
      );

      _isExpectedSignedOut = false;
      currentUser.value = user;
      isInitialized.value = true;
      noticeMessage.value = '가입 설정이 완료되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isCompletingProfileSetup.value = false;
    }
  }

  Future<void> updateMyStoreProfile({
    required String nickname,
    required String industry,
    required String region,
  }) async {
    if (isUpdatingMyStoreProfile.value) return;

    isUpdatingMyStoreProfile.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      final user = await repository.updateMyStoreProfile(
        nickname: nickname,
        industry: industry,
        region: region,
      );

      _isExpectedSignedOut = false;
      currentUser.value = user;
      isInitialized.value = true;
      noticeMessage.value = '내가게 정보가 수정되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isUpdatingMyStoreProfile.value = false;
    }
  }

  Future<void> acknowledgeLatestWarning() async {
    if (isAcknowledgingWarning.value) return;

    isAcknowledgingWarning.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      final user = await repository.acknowledgeLatestWarning();

      _isExpectedSignedOut = false;
      currentUser.value = user;
      isInitialized.value = true;
      noticeMessage.value = '확인되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isAcknowledgingWarning.value = false;
    }
  }

  Future<AppUser?> refreshCurrentUser() async {
    if (isRefreshingCurrentUser.value) {
      return currentUser.value;
    }

    isRefreshingCurrentUser.value = true;
    errorMessage.value = null;

    try {
      final user = await repository.refreshCurrentUser();

      currentUser.value = user;
      isInitialized.value = true;

      if (user != null) {
        _isExpectedSignedOut = false;
      }

      return user;
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isRefreshingCurrentUser.value = false;
    }
  }

  Future<void> verifyBusiness({
    required String businessNumber,
    required String representativeName,
    required String openedAt,
  }) async {
    if (isVerifyingBusiness.value) return;

    isVerifyingBusiness.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      final user = await repository.verifyBusiness(
        businessNumber: businessNumber,
        representativeName: representativeName,
        openedAt: openedAt,
      );

      _isExpectedSignedOut = false;
      currentUser.value = user;
      isInitialized.value = true;
      noticeMessage.value = '사업자 인증이 완료되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isVerifyingBusiness.value = false;
    }
  }

  Future<void> deleteAccount() async {
    if (isDeletingAccount.value) return;

    isDeletingAccount.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      await repository.deleteAccount();

      _isExpectedSignedOut = true;
      currentUser.value = null;
      isInitialized.value = true;
      noticeMessage.value = '계정이 삭제되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isDeletingAccount.value = false;
    }
  }

  Future<void> signOut() async {
    if (isSigningOut.value) return;

    isSigningOut.value = true;
    errorMessage.value = null;
    noticeMessage.value = null;

    try {
      await repository.signOut();

      _isExpectedSignedOut = true;
      currentUser.value = null;
      isInitialized.value = true;
      noticeMessage.value = '로그아웃되었습니다.';
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isSigningOut.value = false;
    }
  }

  void clearError() {
    errorMessage.value = null;
  }

  void clearNotice() {
    noticeMessage.value = null;
  }

  void _bindUserStream() {
    _userSubscription?.cancel();

    _userSubscription = repository.watchCurrentUser().listen(
      (user) {
        if (_isExpectedSignedOut && user != null) {
          return;
        }

        currentUser.value = user;
        isInitialized.value = true;

        if (user != null) {
          _isExpectedSignedOut = false;
        }
      },
      onError: (Object error) {
        if (_isExpectedSignedOut) {
          currentUser.value = null;
          errorMessage.value = null;
          noticeMessage.value = null;
          isInitialized.value = true;
          return;
        }

        errorMessage.value = _friendlyError(error);
        isInitialized.value = true;
      },
    );
  }

  String _friendlyError(Object error) {
    final raw = error.toString();

    if (raw.contains('account-exists-with-different-credential')) {
      return '이미 다른 로그인 방식으로 가입된 계정입니다.';
    }

    if (raw.contains('network-request-failed') ||
        raw.contains('network error') ||
        raw.contains('SocketException')) {
      return '네트워크 연결을 확인해주세요.';
    }

    if (raw.contains('popup-closed-by-user') ||
        raw.contains('sign_in_canceled') ||
        raw.contains('canceled') ||
        raw.contains('cancelled')) {
      return '로그인이 취소되었습니다.';
    }

    if (raw.contains('user-disabled')) {
      return '이용이 제한된 계정입니다.';
    }

    if (raw.contains('로그인이 필요합니다')) {
      return '로그인이 필요합니다.';
    }

    if (raw.contains('Apple login is only available')) {
      return 'Apple 로그인은 지원되는 Apple 기기에서만 사용할 수 있습니다.';
    }

    if (raw.contains('Kakao access token is empty') ||
        raw.contains('Kakao custom token is empty')) {
      return '카카오 로그인 정보를 확인하지 못했습니다.';
    }

    if (raw.contains('Google idToken is empty')) {
      return 'Google 로그인 정보를 확인하지 못했습니다.';
    }

    if (raw.contains('Firebase user is null')) {
      return '로그인 정보를 확인하지 못했습니다.';
    }

    if (raw.contains('Business verification service') ||
        raw.contains('unavailable') ||
        raw.contains('UNAVAILABLE')) {
      return '사업자 인증 서버가 불안정합니다.\n잠시 후 다시 시도해주세요.';
    }

    if (raw.contains('Business information does not match')) {
      return '입력한 정보와 사업자등록 정보가 일치하지 않습니다.';
    }

    if (raw.contains('NTS service key is not configured')) {
      return '사업자 인증 설정이 완료되지 않았습니다.';
    }

    if (raw.contains('permission-denied') ||
        raw.contains('PERMISSION_DENIED')) {
      return '권한이 없습니다.';
    }

    if (raw.contains('not-found') || raw.contains('NOT_FOUND')) {
      return '요청한 정보를 찾지 못했습니다.';
    }

    if (raw.contains('already-exists') || raw.contains('ALREADY_EXISTS')) {
      return '이미 처리된 요청입니다.';
    }

    if (raw.contains('invalid-argument') ||
        raw.contains('INVALID_ARGUMENT')) {
      return '입력한 정보를 다시 확인해주세요.';
    }

    if (raw.contains('failed-precondition') ||
        raw.contains('FAILED_PRECONDITION')) {
      return '현재 상태에서는 처리할 수 없습니다.';
    }

    if (raw.contains('deadline-exceeded') ||
        raw.contains('DEADLINE_EXCEEDED') ||
        raw.contains('timeout')) {
      return '요청 시간이 초과되었습니다.\n잠시 후 다시 시도해주세요.';
    }

    return '처리 중 문제가 발생했습니다.';
  }
}
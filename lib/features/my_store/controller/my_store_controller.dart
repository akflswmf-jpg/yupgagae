import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/my_store/domain/app_notification_item.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';
import 'package:yupgagae/features/my_store/domain/store_profile.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class MyStoreController extends GetxController {
  final StoreProfileRepository repo;
  final PostRepository postRepo;
  final AuthSessionService auth;

  MyStoreController({
    required this.repo,
    required this.postRepo,
    required this.auth,
  });

  static const int _nicknameMinLength = 2;
  static const int _nicknameMaxLength = 10;

  final isLoading = false.obs;
  final isSavingNickname = false.obs;
  final isSavingNotification = false.obs;
  final isSavingIndustry = false.obs;
  final isSavingRegion = false.obs;
  final isDeletingAccount = false.obs;

  final isLoadingMyPosts = false.obs;
  final isLoadingMyComments = false.obs;

  final error = RxnString();
  final myActivityError = RxnString();

  final profile = Rxn<StoreProfile>();

  final notifications = <AppNotificationItem>[].obs;
  final blockedUsers = <BlockedUserItem>[].obs;

  final myPosts = <Post>[].obs;
  final myComments = <Comment>[].obs;

  bool _didLoadMyPosts = false;
  bool _didLoadMyComments = false;

  Worker? _authUserWorker;
  String? _lastBoundUserId;
  int _loadSeq = 0;

  String get currentUserId {
    final userId = _extractCurrentAuthUserId();
    if (userId != null && userId.isNotEmpty) {
      return userId;
    }

    return '';
  }

  int get unreadNotificationCount {
    return notifications.where((e) => !e.isRead).length;
  }

  bool get isIdentityVerified {
    return profile.value?.isIdentityVerified ?? false;
  }

  bool get isOwnerVerified {
    return profile.value?.isOwnerVerified ?? false;
  }

  bool get hasLoadedMyPosts {
    return _didLoadMyPosts;
  }

  bool get hasLoadedMyComments {
    return _didLoadMyComments;
  }

  @override
  void onInit() {
    super.onInit();
    _bindAuthUserWatcher();
    load(force: true);
  }

  @override
  void onClose() {
    _authUserWorker?.dispose();
    _authUserWorker = null;
    super.onClose();
  }

  Future<void> load({bool force = false}) async {
    if (isLoading.value && !force) return;

    final seq = ++_loadSeq;

    try {
      isLoading.value = true;
      error.value = null;

      final authReady = await _waitForAuthInitialized();

      if (!_isLatestLoadSeq(seq)) return;

      if (!authReady) {
        error.value = '계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.';
        return;
      }

      final requestedUserId = _extractCurrentAuthUserId();

      // 중요:
      // 로그아웃/비로그인 상태는 에러가 아니다.
      // 이 상태에서 repo.fetchProfile()을 호출하면
      // "계정 정보를 불러오지 못했습니다" 같은 전역 빨간 박스가 뜰 수 있다.
      if (requestedUserId == null || requestedUserId.trim().isEmpty) {
        _resetAccountScopedState(clearProfile: true);
        return;
      }

      final localProfile = await repo.fetchProfile();

      if (!_isLatestProfileLoad(seq, requestedUserId)) return;

      final mergedProfile = _mergeAuthProfile(localProfile);

      if (!_isLatestProfileLoad(seq, requestedUserId)) return;

      _applyProfile(mergedProfile);
    } catch (_) {
      if (_isLatestLoadSeq(seq)) {
        error.value = '내가게 정보를 불러오지 못했습니다.';
      }
    } finally {
      if (_isLatestLoadSeq(seq)) {
        isLoading.value = false;
      }
    }
  }

  Future<void> refreshProfile() async {
    await load(force: true);
  }

  Future<void> loadMyPosts({bool force = false}) async {
    if (isLoadingMyPosts.value) return;
    if (!force && _didLoadMyPosts) return;

    final requestedUserId = _extractCurrentAuthUserId();

    if (requestedUserId == null || requestedUserId.trim().isEmpty) {
      myActivityError.value = null;
      myPosts.clear();
      _didLoadMyPosts = false;
      return;
    }

    try {
      isLoadingMyPosts.value = true;
      myActivityError.value = null;

      final authReady = await _waitForAuthInitialized();

      if (requestedUserId != _extractCurrentAuthUserId()) return;

      if (!authReady) {
        myActivityError.value = '계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.';
        return;
      }

      final result = await postRepo.fetchMyPosts();

      if (requestedUserId != _extractCurrentAuthUserId()) return;

      myPosts.assignAll(result);
      _didLoadMyPosts = true;
    } catch (e) {
      if (requestedUserId == _extractCurrentAuthUserId()) {
        myActivityError.value = e.toString();
      }
    } finally {
      if (requestedUserId == _extractCurrentAuthUserId()) {
        isLoadingMyPosts.value = false;
      }
    }
  }

  Future<void> loadMyComments({bool force = false}) async {
    if (isLoadingMyComments.value) return;
    if (!force && _didLoadMyComments) return;

    final requestedUserId = _extractCurrentAuthUserId();

    if (requestedUserId == null || requestedUserId.trim().isEmpty) {
      myActivityError.value = null;
      myComments.clear();
      _didLoadMyComments = false;
      return;
    }

    try {
      isLoadingMyComments.value = true;
      myActivityError.value = null;

      final authReady = await _waitForAuthInitialized();

      if (requestedUserId != _extractCurrentAuthUserId()) return;

      if (!authReady) {
        myActivityError.value = '계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.';
        return;
      }

      final result = await postRepo.fetchMyComments();

      if (requestedUserId != _extractCurrentAuthUserId()) return;

      myComments.assignAll(result);
      _didLoadMyComments = true;
    } catch (e) {
      if (requestedUserId == _extractCurrentAuthUserId()) {
        myActivityError.value = e.toString();
      }
    } finally {
      if (requestedUserId == _extractCurrentAuthUserId()) {
        isLoadingMyComments.value = false;
      }
    }
  }

  Future<void> refreshMyPosts() async {
    await loadMyPosts(force: true);
  }

  Future<void> refreshMyComments() async {
    await loadMyComments(force: true);
  }

  Future<void> changeNickname(String nickname) async {
    final normalized = _normalizeNickname(nickname);

    final validationMessage = _validateNickname(normalized);
    if (validationMessage != null) {
      throw Exception(validationMessage);
    }

    if (isSavingNickname.value) {
      throw Exception('닉네임을 저장하는 중입니다. 잠시만 기다려주세요.');
    }

    try {
      isSavingNickname.value = true;

      // 닉네임 변경 진입 시 기존 내가게 전역 에러만 정리한다.
      // 저장 실패 메시지를 error.value에 다시 넣으면
      // 닉네임 화면을 닫았을 때 내가게 화면 전체가 에러 화면으로 바뀐다.
      error.value = null;

      final authReady = await _waitForAuthInitialized();

      if (!authReady) {
        throw Exception('계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.');
      }

      final userId = _extractCurrentAuthUserId();
      if (userId == null || userId.trim().isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final base = await _currentProfileBase();

      final nextIndustry = base.industry.trim();
      final nextRegion = base.region.trim();

      if (nextIndustry.isEmpty) {
        throw Exception('업종을 먼저 선택해주세요.');
      }

      if (nextRegion.isEmpty) {
        throw Exception('지역을 먼저 선택해주세요.');
      }

      final authController = _requireAuthController();

      await authController.updateMyStoreProfile(
        nickname: normalized,
        industry: nextIndustry,
        region: nextRegion,
      );

      StoreProfile localUpdated = base.copyWith(
        nickname: normalized,
      );

      try {
        localUpdated = await repo.updateNickname(normalized);
      } catch (_) {
        // 서버 저장이 성공했다면 로컬 fallback 저장 실패가 화면 흐름을 막으면 안 된다.
      }

      _applyProfile(_mergeAuthProfile(localUpdated));
      _invalidateCurrentAuthorSnapshot();
    } catch (e) {
      final message = _friendlyNicknameError(e);

      // 중요:
      // AuthController.updateMyStoreProfile() 실패 시 AuthController.errorMessage에도
      // 같은 에러가 남을 수 있다.
      // 닉네임 중복/금칙어/형식 오류는 입력 화면 내부 에러이므로
      // 전역 빨간 박스에는 남기지 않는다.
      _clearAuthControllerError();

      // 중요:
      // 닉네임 변경 실패는 NicknameEditScreen 내부 입력칸 아래에서만 보여준다.
      // 여기서 error.value = message를 넣으면 MyStoreBody가 전역 에러 화면으로 전환된다.
      throw Exception(message);
    } finally {
      isSavingNickname.value = false;
    }
  }

  Future<void> changeIndustry(String industry) async {
    final normalized = industry.trim();

    if (normalized.isEmpty) {
      throw Exception('업종을 선택하세요.');
    }

    if (isSavingIndustry.value) return;

    try {
      isSavingIndustry.value = true;
      error.value = null;

      final authReady = await _waitForAuthInitialized();

      if (!authReady) {
        throw Exception('계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.');
      }

      final userId = _extractCurrentAuthUserId();
      if (userId == null || userId.trim().isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final base = await _currentProfileBase();

      final nextNickname = _normalizeNickname(base.nickname);
      final nextRegion = base.region.trim();

      if (nextNickname.isEmpty) {
        throw Exception('닉네임을 먼저 입력해주세요.');
      }

      if (nextRegion.isEmpty) {
        throw Exception('지역을 먼저 선택해주세요.');
      }

      final authController = _requireAuthController();

      await authController.updateMyStoreProfile(
        nickname: nextNickname,
        industry: normalized,
        region: nextRegion,
      );

      StoreProfile localUpdated = base.copyWith(
        industry: normalized,
      );

      try {
        localUpdated = await repo.updateIndustry(normalized);
      } catch (_) {
        // 서버 저장이 성공했다면 로컬 fallback 저장 실패가 화면 흐름을 막으면 안 된다.
      }

      _applyProfile(_mergeAuthProfile(localUpdated));
      _invalidateCurrentAuthorSnapshot();
    } finally {
      isSavingIndustry.value = false;
    }
  }

  Future<void> changeRegion(String region) async {
    final normalized = region.trim();

    if (normalized.isEmpty) {
      throw Exception('지역을 선택하세요.');
    }

    if (isSavingRegion.value) return;

    try {
      isSavingRegion.value = true;
      error.value = null;

      final authReady = await _waitForAuthInitialized();

      if (!authReady) {
        throw Exception('계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.');
      }

      final userId = _extractCurrentAuthUserId();
      if (userId == null || userId.trim().isEmpty) {
        throw Exception('로그인이 필요합니다.');
      }

      final base = await _currentProfileBase();

      final nextNickname = _normalizeNickname(base.nickname);
      final nextIndustry = base.industry.trim();

      if (nextNickname.isEmpty) {
        throw Exception('닉네임을 먼저 입력해주세요.');
      }

      if (nextIndustry.isEmpty) {
        throw Exception('업종을 먼저 선택해주세요.');
      }

      final authController = _requireAuthController();

      await authController.updateMyStoreProfile(
        nickname: nextNickname,
        industry: nextIndustry,
        region: normalized,
      );

      StoreProfile localUpdated = base.copyWith(
        region: normalized,
      );

      try {
        localUpdated = await repo.updateRegion(normalized);
      } catch (_) {
        // 서버 저장이 성공했다면 로컬 fallback 저장 실패가 화면 흐름을 막으면 안 된다.
      }

      _applyProfile(_mergeAuthProfile(localUpdated));
      _invalidateCurrentAuthorSnapshot();
    } finally {
      isSavingRegion.value = false;
    }
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    try {
      isSavingNotification.value = true;
      error.value = null;

      final updated = await repo.updateNotificationsEnabled(enabled);
      _applyProfile(_mergeAuthProfile(updated));
    } finally {
      isSavingNotification.value = false;
    }
  }

  Future<void> updateNotificationEnabled(bool enabled) async {
    await setNotificationsEnabled(enabled);
  }

  Future<void> deleteAccount() async {
    if (isDeletingAccount.value) return;

    try {
      isDeletingAccount.value = true;
      error.value = null;

      final authReady = await _waitForAuthInitialized();

      if (!authReady) {
        throw Exception('계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.');
      }

      final authController = _requireAuthController();
      await authController.deleteAccount();

      _resetAccountScopedState(clearProfile: true);
    } finally {
      isDeletingAccount.value = false;
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;

    final updated = await repo.markAsRead(id);
    _applyProfile(_mergeAuthProfile(updated));
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    await markNotificationRead(notificationId);
  }

  Future<void> markAllNotificationsRead() async {
    final updated = await repo.markAllRead();
    _applyProfile(_mergeAuthProfile(updated));
  }

  Future<void> markAllNotificationsAsRead() async {
    await markAllNotificationsRead();
  }

  Future<void> addNotification(AppNotificationItem item) async {
    final updated = await repo.addNotification(item);
    _applyProfile(_mergeAuthProfile(updated));
  }

  Future<void> removeNotification(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;

    final p = profile.value;
    if (p == null) return;

    final nextNotifications =
        p.notifications.where((e) => e.id != id).toList(growable: false);

    final updated = p.copyWith(
      notifications: nextNotifications,
    );

    profile.value = updated;
    notifications.assignAll(updated.notifications);
  }

  Future<void> clearNotifications() async {
    final updated = await repo.clearNotifications();
    _applyProfile(_mergeAuthProfile(updated));
  }

  Future<void> blockUser(BlockedUserItem user) async {
    final targetId = user.userId.trim();
    if (targetId.isEmpty) return;

    final updated = await repo.blockUser(user);
    _applyProfile(_mergeAuthProfile(updated));
  }

  Future<void> blockUserByInfo({
    required String userId,
    required String nickname,
    String? industry,
    String? region,
    String? reason,
  }) async {
    final targetId = userId.trim();
    if (targetId.isEmpty) return;

    await blockUser(
      BlockedUserItem(
        userId: targetId,
        nickname: nickname.trim().isEmpty ? '익명' : nickname.trim(),
        industry: industry,
        region: region,
        blockedAt: DateTime.now(),
      ),
    );
  }

  Future<void> unblockUser(String userId) async {
    final targetId = userId.trim();
    if (targetId.isEmpty) return;

    final updated = await repo.unblockUser(targetId);
    _applyProfile(_mergeAuthProfile(updated));
  }

  void applyDeletedPost(String postId) {
    final id = postId.trim();
    if (id.isEmpty) return;

    myPosts.removeWhere((e) => e.id == id);
  }

  void applyUpdatedPost(Post updated) {
    final index = myPosts.indexWhere((e) => e.id == updated.id);
    if (index == -1) return;

    final next = List<Post>.from(myPosts);
    next[index] = updated;
    myPosts.assignAll(next);
  }

  void _bindAuthUserWatcher() {
    if (!Get.isRegistered<AuthController>()) return;

    final authController = Get.find<AuthController>();
    _lastBoundUserId = _extractCurrentAuthUserId();

    _authUserWorker?.dispose();
    _authUserWorker = ever(
      authController.currentUser,
      (_) => _handleAuthUserChanged(),
    );
  }

  void _handleAuthUserChanged() {
    final nextUserId = _extractCurrentAuthUserId();

    if (nextUserId == _lastBoundUserId) {
      return;
    }

    _lastBoundUserId = nextUserId;
    _resetAccountScopedState(clearProfile: true);
    _invalidateCurrentAuthorSnapshot();

    // 중요:
    // 로그아웃은 정상 상태 전환이다.
    // 로그아웃 직후 load(force: true)를 호출하면
    // 비로그인 상태에서 프로필을 불러오려다가 전역 에러 박스가 뜰 수 있다.
    if (nextUserId == null || nextUserId.trim().isEmpty) {
      return;
    }

    load(force: true);
  }

  String? _extractCurrentAuthUserId() {
    if (Get.isRegistered<AuthController>()) {
      final authController = Get.find<AuthController>();

      // 중요:
      // AuthController가 초기화된 뒤 currentUser가 null이면 명확한 로그아웃/비로그인 상태다.
      // 이때 AuthSessionService의 과거 currentUserId fallback을 쓰면
      // 로그아웃 후에도 이전 userId로 profile fetch를 시도할 수 있다.
      if (authController.isInitialized.value) {
        final userId = authController.currentUser.value?.userId.trim();
        if (userId == null || userId.isEmpty) {
          return null;
        }

        return userId;
      }

      final userId = authController.currentUser.value?.userId.trim();
      if (userId != null && userId.isNotEmpty) {
        return userId;
      }
    }

    final fallback = auth.currentUserId.trim();
    if (fallback.isEmpty) return null;

    return fallback;
  }

  Future<bool> _waitForAuthInitialized() async {
    if (!Get.isRegistered<AuthController>()) {
      return true;
    }

    final authController = Get.find<AuthController>();

    if (authController.isInitialized.value) {
      return true;
    }

    return authController.waitUntilInitialized();
  }

  bool _isLatestLoadSeq(int seq) {
    return seq == _loadSeq;
  }

  bool _isLatestProfileLoad(int seq, String? requestedUserId) {
    return seq == _loadSeq && requestedUserId == _extractCurrentAuthUserId();
  }

  void _resetAccountScopedState({required bool clearProfile}) {
    _loadSeq++;

    error.value = null;
    myActivityError.value = null;

    if (clearProfile) {
      profile.value = null;
    }

    notifications.clear();
    blockedUsers.clear();

    myPosts.clear();
    myComments.clear();

    _didLoadMyPosts = false;
    _didLoadMyComments = false;

    isLoadingMyPosts.value = false;
    isLoadingMyComments.value = false;
  }

  AuthController _requireAuthController() {
    if (!Get.isRegistered<AuthController>()) {
      throw Exception('로그인이 필요합니다.');
    }

    final authController = Get.find<AuthController>();

    if (!authController.isInitialized.value) {
      throw Exception('계정 정보를 확인하는 중입니다. 잠시 후 다시 시도해주세요.');
    }

    if (authController.currentUser.value == null) {
      throw Exception('로그인이 필요합니다.');
    }

    return authController;
  }

  Future<StoreProfile> _currentProfileBase() async {
    final current = profile.value;

    if (current != null) {
      return _mergeAuthProfile(current);
    }

    final authReady = await _waitForAuthInitialized();

    if (!authReady) {
      throw Exception('계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.');
    }

    final userId = _extractCurrentAuthUserId();
    if (userId == null || userId.trim().isEmpty) {
      throw Exception('로그인이 필요합니다.');
    }

    final local = await repo.fetchProfile();
    return _mergeAuthProfile(local);
  }

  StoreProfile _mergeAuthProfile(StoreProfile base) {
    if (!Get.isRegistered<AuthController>()) {
      return base;
    }

    final authController = Get.find<AuthController>();

    if (!authController.isInitialized.value) {
      return base;
    }

    final user = authController.currentUser.value;

    if (user == null) {
      return base;
    }

    final nickname = user.nickname?.trim();
    final industry = user.industry?.trim();
    final region = user.region?.trim();

    return base.copyWith(
      nickname: nickname == null || nickname.isEmpty ? base.nickname : nickname,
      industry: industry == null || industry.isEmpty ? base.industry : industry,
      region: region == null || region.isEmpty ? base.region : region,
      isIdentityVerified: user.isIdentityVerified,
      isOwnerVerified: user.isBusinessVerified,
    );
  }

  void _applyProfile(StoreProfile updated) {
    profile.value = updated;
    notifications.assignAll(updated.notifications);
    blockedUsers.assignAll(updated.blockedUsers);
  }

  String _normalizeNickname(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), '');
  }

  String? _validateNickname(String value) {
    if (value.isEmpty) {
      return '닉네임을 입력해주세요.';
    }

    if (value.length < _nicknameMinLength) {
      return '닉네임은 $_nicknameMinLength자 이상으로 입력해주세요.';
    }

    if (value.length > _nicknameMaxLength) {
      return '닉네임은 $_nicknameMaxLength자 이하로 입력해주세요.';
    }

    if (!RegExp(r'^[가-힣a-zA-Z0-9_]+$').hasMatch(value)) {
      return '닉네임은 한글, 영문, 숫자, 밑줄(_)만 사용할 수 있어요.';
    }

    return null;
  }

  String _friendlyNicknameError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('이미 사용 중인 닉네임') ||
        raw.contains('already-exists') ||
        raw.contains('nickname already exists') ||
        raw.contains('already exists') ||
        raw.contains('duplicate')) {
      return '이미 사용 중인 닉네임입니다.';
    }

    if (raw.contains('사용할 수 없는 닉네임') ||
        raw.contains('nickname is reserved') ||
        raw.contains('reserved')) {
      return '사용할 수 없는 닉네임입니다.';
    }

    if (raw.contains('사용할 수 없는 표현') ||
        raw.contains('blocked words') ||
        raw.contains('contains blocked') ||
        raw.contains('blocked')) {
      return '사용할 수 없는 표현이 포함된 닉네임입니다.';
    }

    if (raw.contains('nickname format is invalid')) {
      return '닉네임은 한글, 영문, 숫자, 밑줄(_)만 사용할 수 있어요.';
    }

    if (raw.contains('nickname is required')) {
      return '닉네임을 입력해주세요.';
    }

    if (raw.contains('nickname must be at least')) {
      return '닉네임은 $_nicknameMinLength자 이상으로 입력해주세요.';
    }

    if (raw.contains('nickname must be $_nicknameMaxLength') ||
        raw.contains(
          'nickname must be $_nicknameMaxLength characters or less',
        )) {
      return '닉네임은 $_nicknameMaxLength자 이하로 입력해주세요.';
    }

    if (raw.contains('로그인이 필요')) {
      return '로그인이 필요합니다.';
    }

    if (raw.contains('unauthenticated')) {
      return '로그인 인증이 만료되었습니다. 다시 로그인해주세요.';
    }

    if (raw.contains('permission-denied')) {
      return '계정 정보를 확인하지 못했습니다. 잠시 후 다시 시도해주세요.';
    }

    if (raw.contains('unavailable') ||
        raw.contains('deadline-exceeded') ||
        raw.contains('timeout') ||
        raw.contains('network')) {
      return '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
    }

    if (raw.contains('profile setup must be completed first')) {
      return '가입 설정을 먼저 완료해주세요.';
    }

    if (raw.contains('account already withdrawn')) {
      return '이미 탈퇴 처리된 계정입니다.';
    }

    return '닉네임을 변경하지 못했습니다. 잠시 후 다시 시도해주세요.';
  }

  void _clearAuthControllerError() {
    if (!Get.isRegistered<AuthController>()) return;

    try {
      Get.find<AuthController>().clearError();
    } catch (_) {
      // AuthController가 이미 dispose되었거나 접근 불가한 경우 화면 흐름을 막지 않는다.
    }
  }

  void _invalidateCurrentAuthorSnapshot() {
    try {
      final dynamic repoDyn = postRepo;
      repoDyn.invalidateCurrentAuthorSnapshot();
    } catch (_) {
      // 서버 구현체 또는 다른 구현체에서는 해당 메서드가 없을 수 있다.
    }
  }
}
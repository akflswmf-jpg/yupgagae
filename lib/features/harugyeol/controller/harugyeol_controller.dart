import 'dart:async';

import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_comment.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_day_summary.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_entry.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_enums.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_repository.dart';

enum HarugyeolEntryGateMode {
  loading,
  beforeInputTime,
  loginRequired,
  writeRequired,
  partialResult,
  fullResult,
  pastLocked,
}

class HarugyeolController extends GetxController {
  final HarugyeolRepository repo;
  final AuthController authController;

  HarugyeolController({
    required this.repo,
    required this.authController,
  });

  final selectedDateOffset = 0.obs;

  final selectedMood = Rxn<HarugyeolMood>();
  final selectedReasons = <HarugyeolReason>{}.obs;
  final oneLineText = ''.obs;

  final middayMood = Rxn<HarugyeolMood>();
  final middayReasons = <HarugyeolReason>{}.obs;
  final middayOneLineText = ''.obs;

  final eveningMood = Rxn<HarugyeolMood>();
  final eveningReasons = <HarugyeolReason>{}.obs;
  final eveningOneLineText = ''.obs;

  final summary = Rxn<HarugyeolDaySummary>();
  final previousSummary = Rxn<HarugyeolDaySummary>();
  final myEntries = <HarugyeolEntry>[].obs;
  final comments = <HarugyeolComment>[].obs;
  final topComments = <HarugyeolComment>[].obs;
  final pendingLikeCommentIds = <String>{}.obs;

  final Map<HarugyeolSlot, HarugyeolEntry> _optimisticEntriesBySlot = {};

  final availableSlot = Rxn<HarugyeolSlot>();
  final availableInputSlots = <HarugyeolSlot>[].obs;
  final selectedInputSlot = Rxn<HarugyeolSlot>();
  final requiredContinuationInputSlot = Rxn<HarugyeolSlot>();
  final nowLabel = ''.obs;
  final submitSuccessMessage = '하루결을 남겼어요.'.obs;

  final isSubmitting = false.obs;
  final isSummaryLoading = true.obs;
  final isPreviousSummaryLoading = false.obs;
  final isMyEntriesLoading = true.obs;
  final isCommentsLoading = true.obs;
  final errorMessage = RxnString();

  StreamSubscription<HarugyeolDaySummary>? _summarySub;
  StreamSubscription<HarugyeolDaySummary>? _previousSummarySub;
  StreamSubscription<List<HarugyeolEntry>>? _myEntriesSub;
  StreamSubscription<List<HarugyeolComment>>? _commentsSub;

  late final Worker _authUserWorker;
  late final Worker _authInitializedWorker;
  late final Worker _authRestoringWorker;

  DateTime _now = DateTime.now();

  static const int maxOneLineLength = 40;

  String get selectedDateKey {
    return dateKeyForOffset(selectedDateOffset.value);
  }

  bool get isTodaySelected => selectedDateOffset.value == 0;

  bool get isLoggedIn {
    final user = authController.currentUser.value;
    if (user == null) return false;
    if (user.needsProfileSetup) return false;
    if (user.isWithdrawn || user.isSuspended) return false;
    return true;
  }

  bool get hasSelectedRequiredInput {
    return selectedMood.value != null && selectedReasons.isNotEmpty;
  }

  bool get isAnyLoading {
    return isSummaryLoading.value ||
        isMyEntriesLoading.value ||
        isCommentsLoading.value;
  }

  bool get hasSubmittedMidday {
    return hasSubmittedSlot(HarugyeolSlot.midday);
  }

  bool get hasSubmittedEvening {
    return hasSubmittedSlot(HarugyeolSlot.evening);
  }

  bool get hasSubmittedAnySlot {
    return hasSubmittedMidday || hasSubmittedEvening;
  }

  bool get hasSubmittedAllSlots {
    return hasSubmittedMidday && hasSubmittedEvening;
  }

  bool get hasAlreadySubmittedCurrentSlot {
    final slot = selectedInputSlot.value ?? availableSlot.value;
    if (slot == null) return false;

    return hasSubmittedSlot(slot);
  }

  bool get hasAnyViewableSlot {
    return viewableSlots.isNotEmpty;
  }

  bool get shouldStartMiddayThenEveningFlow {
    return isTodaySelected &&
        isLoggedIn &&
        availableInputSlots.contains(HarugyeolSlot.midday) &&
        availableInputSlots.contains(HarugyeolSlot.evening) &&
        !hasSubmittedMidday &&
        !hasSubmittedEvening;
  }

  bool get hasRequiredContinuationInput {
    final slot = requiredContinuationInputSlot.value;
    if (slot == null) return false;

    if (!canWriteSlot(slot)) {
      return false;
    }

    return true;
  }

  bool get isMiddayThenEveningFlowActive {
    return inputSlotsToShow.isNotEmpty ||
        shouldStartMiddayThenEveningFlow ||
        hasRequiredContinuationInput;
  }

  bool get shouldLockInputSlotChoice {
    return isMiddayThenEveningFlowActive;
  }

  bool get shouldPrioritizeInputBeforeResult {
    if (inputSlotsToShow.isNotEmpty) return true;
    if (hasRequiredContinuationInput) return true;
    if (shouldStartMiddayThenEveningFlow) return true;
    return false;
  }

  bool get shouldShowGateFirst {
    if (shouldPrioritizeInputBeforeResult) return true;
    if (entryGateMode == HarugyeolEntryGateMode.writeRequired) return true;
    if (entryGateMode == HarugyeolEntryGateMode.beforeInputTime) return true;
    if (entryGateMode == HarugyeolEntryGateMode.loginRequired) return true;
    if (entryGateMode == HarugyeolEntryGateMode.pastLocked) return true;
    return false;
  }

  bool get shouldShowResult {
    if (inputSlotsToShow.isNotEmpty) return false;
    if (hasRequiredContinuationInput) return false;
    if (shouldStartMiddayThenEveningFlow) return false;

    return entryGateMode == HarugyeolEntryGateMode.partialResult ||
        entryGateMode == HarugyeolEntryGateMode.fullResult;
  }

  HarugyeolEntryGateMode get entryGateMode {
    if (isSummaryLoading.value || isMyEntriesLoading.value) {
      return HarugyeolEntryGateMode.loading;
    }

    if (!isLoggedIn) {
      return HarugyeolEntryGateMode.loginRequired;
    }

    if (!isTodaySelected) {
      if (hasSubmittedAnySlot) {
        return hasSubmittedAllSlots
            ? HarugyeolEntryGateMode.fullResult
            : HarugyeolEntryGateMode.partialResult;
      }

      return HarugyeolEntryGateMode.pastLocked;
    }

    if (availableInputSlots.isEmpty) {
      if (hasSubmittedAnySlot) {
        return hasSubmittedAllSlots
            ? HarugyeolEntryGateMode.fullResult
            : HarugyeolEntryGateMode.partialResult;
      }

      return HarugyeolEntryGateMode.beforeInputTime;
    }

    if (inputSlotsToShow.isNotEmpty) {
      return HarugyeolEntryGateMode.writeRequired;
    }

    if (!hasSubmittedAnySlot) {
      return HarugyeolEntryGateMode.writeRequired;
    }

    if (hasRequiredContinuationInput) {
      return HarugyeolEntryGateMode.writeRequired;
    }

    if (hasSubmittedAllSlots) {
      return HarugyeolEntryGateMode.fullResult;
    }

    return HarugyeolEntryGateMode.partialResult;
  }

  List<HarugyeolSlot> get inputSlotsToShow {
    if (!isTodaySelected || !isLoggedIn) {
      return const <HarugyeolSlot>[];
    }

    if (availableInputSlots.isEmpty) {
      return const <HarugyeolSlot>[];
    }

    final canInputMidday = availableInputSlots.contains(HarugyeolSlot.midday);
    final canInputEvening = availableInputSlots.contains(HarugyeolSlot.evening);

    if (!canInputEvening) {
      if (canInputMidday && !hasSubmittedMidday) {
        return const <HarugyeolSlot>[HarugyeolSlot.midday];
      }

      return const <HarugyeolSlot>[];
    }

    if (!hasSubmittedMidday && !hasSubmittedEvening) {
      return const <HarugyeolSlot>[
        HarugyeolSlot.midday,
        HarugyeolSlot.evening,
      ];
    }

    if (hasSubmittedMidday && !hasSubmittedEvening) {
      return const <HarugyeolSlot>[HarugyeolSlot.evening];
    }

    if (!hasSubmittedMidday && hasSubmittedEvening) {
      return const <HarugyeolSlot>[HarugyeolSlot.midday];
    }

    return const <HarugyeolSlot>[];
  }

  List<HarugyeolSlot> get viewableSlots {
    final slots = <HarugyeolSlot>[];

    if (hasSubmittedMidday) {
      slots.add(HarugyeolSlot.midday);
    }

    if (hasSubmittedEvening) {
      slots.add(HarugyeolSlot.evening);
    }

    return slots;
  }

  List<HarugyeolSlot> get missingSlots {
    return HarugyeolSlot.values
        .where((slot) {
          return !hasSubmittedSlot(slot);
        })
        .toList(growable: false);
  }

  List<HarugyeolSlot> get writableMissingSlots {
    return inputSlotsToShow;
  }

  List<HarugyeolComment> get visibleComments {
    final slots = viewableSlots.toSet();

    if (slots.isEmpty) {
      return const <HarugyeolComment>[];
    }

    return comments
        .where((comment) {
          return slots.contains(comment.slot);
        })
        .toList(growable: false);
  }

  List<HarugyeolComment> get visibleTopComments {
    final list = visibleComments.toList();

    list.sort((a, b) {
      final likeCompare = b.likeCount.compareTo(a.likeCount);
      if (likeCompare != 0) return likeCompare;

      final dateCompare = b.createdAt.compareTo(a.createdAt);
      if (dateCompare != 0) return dateCompare;

      return a.id.compareTo(b.id);
    });

    return list.take(3).toList(growable: false);
  }

  HarugyeolDaySummary get visibleSummary {
    final source = summary.value ?? HarugyeolDaySummary.empty(selectedDateKey);

    return source.filteredBySlots(viewableSlots);
  }

  String get resultTitle {
    if (hasSubmittedAllSlots) {
      return '$selectedDateLabel 장사 체감지수';
    }

    if (hasSubmittedMidday && !hasSubmittedEvening) {
      return '$selectedDateLabel 낮 장사 체감지수';
    }

    if (!hasSubmittedMidday && hasSubmittedEvening) {
      return '$selectedDateLabel 저녁 장사 체감지수';
    }

    return '$selectedDateLabel 장사 체감지수';
  }

  String get reasonTitle {
    if (hasSubmittedAllSlots) {
      return '주요 이유';
    }

    if (hasSubmittedMidday && !hasSubmittedEvening) {
      return '낮 시간 주요 이유';
    }

    if (!hasSubmittedMidday && hasSubmittedEvening) {
      return '저녁 시간 주요 이유';
    }

    return '주요 이유';
  }

  String get reasonDescription {
    if (hasSubmittedAllSlots) {
      return '오늘의 장사 분위기를 만든 이유 순위입니다.';
    }

    if (hasSubmittedMidday && !hasSubmittedEvening) {
      return '낮 장사 분위기를 만든 이유 순위입니다.';
    }

    if (!hasSubmittedMidday && hasSubmittedEvening) {
      return '저녁 장사 분위기를 만든 이유 순위입니다.';
    }

    return '체감을 남기면 이유 순위를 볼 수 있어요.';
  }

  String get gateTitle {
    switch (entryGateMode) {
      case HarugyeolEntryGateMode.loading:
        return '하루결을 준비하고 있어요';
      case HarugyeolEntryGateMode.beforeInputTime:
        return '아직 입력 시간이 아니에요';
      case HarugyeolEntryGateMode.loginRequired:
        return '로그인이 필요해요';
      case HarugyeolEntryGateMode.writeRequired:
        return '오늘 장사체감을 먼저 남겨주세요';
      case HarugyeolEntryGateMode.partialResult:
      case HarugyeolEntryGateMode.fullResult:
        return '오늘 하루결';
      case HarugyeolEntryGateMode.pastLocked:
        return '지난 하루결은 참여자만 볼 수 있어요';
    }
  }

  String get gateDescription {
    switch (entryGateMode) {
      case HarugyeolEntryGateMode.loading:
        return '잠시만 기다려주세요.';
      case HarugyeolEntryGateMode.beforeInputTime:
        return '하루결은 오전 11시부터 자정까지 남길 수 있어요.';
      case HarugyeolEntryGateMode.loginRequired:
        return '장사체감을 남기고 다른 사장님들의 흐름을 확인하려면 로그인이 필요합니다.';
      case HarugyeolEntryGateMode.writeRequired:
        if (inputSlotsToShow.length >= 2) {
          return '낮 장사와 저녁 장사를 모두 남기면 오늘 하루결 결과를 볼 수 있어요.';
        }

        if (inputSlotsToShow.contains(HarugyeolSlot.evening)) {
          return '저녁 장사체감까지 남기면 오늘 하루결 결과를 볼 수 있어요.';
        }

        return '낮 장사체감을 남기면 낮 시간대 흐름을 볼 수 있어요.';
      case HarugyeolEntryGateMode.partialResult:
      case HarugyeolEntryGateMode.fullResult:
        return '입력한 시간대의 흐름만 볼 수 있어요.';
      case HarugyeolEntryGateMode.pastLocked:
        return '해당 날짜에 체감을 남긴 시간대의 결과만 확인할 수 있어요.';
    }
  }

  String get primaryGateButtonLabel {
    final slots = inputSlotsToShow;

    if (slots.length >= 2) {
      return '낮·저녁 체감 입력하기';
    }

    if (slots.length == 1) {
      if (slots.first == HarugyeolSlot.evening) {
        return '저녁 체감 입력하기';
      }

      return '낮 체감 입력하기';
    }

    if (!isLoggedIn) return '로그인 후 이용하기';
    return '입력 시간 기다리기';
  }

  HarugyeolSlot? get recommendedInputSlot {
    final writable = inputSlotsToShow;

    if (writable.isEmpty) {
      return null;
    }

    return writable.first;
  }

  bool get isInputEnabled {
    final slot = selectedInputSlot.value;

    if (!isTodaySelected) return false;
    if (!isLoggedIn) return false;
    if (slot == null) return false;
    if (!availableInputSlots.contains(slot)) return false;
    if (hasSubmittedSlot(slot)) return false;
    if (isSubmitting.value) return false;
    return true;
  }

  bool get canSubmit {
    final slots = inputSlotsToShow;

    if (slots.isNotEmpty) {
      return canSubmitVisibleInputs;
    }

    if (!isInputEnabled) return false;
    if (!hasSelectedRequiredInput) return false;
    return true;
  }

  String get inputLockedMessage {
    if (!isTodaySelected) {
      return '지난 하루결은 결과만 볼 수 있어요.';
    }

    if (!isLoggedIn) {
      return '로그인 후 하루결을 남길 수 있어요.';
    }

    final slot = selectedInputSlot.value;

    if (slot == null) {
      return '입력할 장사체감 시간을 선택해주세요.';
    }

    if (!availableInputSlots.contains(slot)) {
      return '${slot.label} 입력 가능 시간이 아니에요.';
    }

    if (hasSubmittedSlot(slot)) {
      if (slot == HarugyeolSlot.midday) {
        return '이미 낮 장사체감을 입력했습니다.';
      }

      if (slot == HarugyeolSlot.evening) {
        return '이미 저녁 장사체감을 입력했습니다.';
      }

      return '이미 현재 시간대 장사체감을 입력했습니다.';
    }

    if (isSubmitting.value) {
      return '하루결을 등록하고 있어요.';
    }

    return '';
  }

  String get submitBlockedMessage {
    if (!isTodaySelected) {
      return '오늘 하루결만 입력할 수 있어요.';
    }

    if (!isLoggedIn) {
      return '로그인 후 하루결을 남길 수 있어요.';
    }

    final slot = selectedInputSlot.value;

    if (slot == null) {
      return '입력할 장사체감 시간을 선택해주세요.';
    }

    if (!availableInputSlots.contains(slot)) {
      return '${slot.label} 입력 가능 시간이 아니에요.';
    }

    if (hasSubmittedSlot(slot)) {
      return inputLockedMessage;
    }

    if (selectedMood.value == null) {
      return '오늘 장사 체감을 선택해주세요.';
    }

    if (selectedReasons.isEmpty) {
      return '이유를 하나 이상 선택해주세요.';
    }

    return '잠시 후 다시 시도해주세요.';
  }

  String get inputTimeGuide {
    final slot = selectedInputSlot.value;

    if (!isTodaySelected) {
      return '지난 하루결은 결과만 볼 수 있어요.';
    }

    if (availableInputSlots.isEmpty) {
      return '입력 가능 시간: 오전 11시 ~ 자정';
    }

    if (slot == null) {
      return '낮 11:00~17:00 · 저녁 17:01~24:00';
    }

    return '${slot.label} 입력 가능 · ${slot.timeLabel}';
  }

  String get selectedDateLabel {
    switch (selectedDateOffset.value) {
      case 0:
        return '오늘';
      case -1:
        return '어제';
      case -2:
        return '그저께';
      default:
        return selectedDateKey;
    }
  }

  HarugyeolMood? moodForSlot(HarugyeolSlot slot) {
    switch (slot) {
      case HarugyeolSlot.midday:
        return middayMood.value;
      case HarugyeolSlot.evening:
        return eveningMood.value;
    }
  }

  RxSet<HarugyeolReason> reasonsForSlot(HarugyeolSlot slot) {
    switch (slot) {
      case HarugyeolSlot.midday:
        return middayReasons;
      case HarugyeolSlot.evening:
        return eveningReasons;
    }
  }

  String oneLineTextForSlot(HarugyeolSlot slot) {
    switch (slot) {
      case HarugyeolSlot.midday:
        return middayOneLineText.value;
      case HarugyeolSlot.evening:
        return eveningOneLineText.value;
    }
  }

  void selectMoodForSlot(HarugyeolSlot slot, HarugyeolMood mood) {
    if (!canWriteSlot(slot)) return;

    switch (slot) {
      case HarugyeolSlot.midday:
        middayMood.value = mood;
        break;
      case HarugyeolSlot.evening:
        eveningMood.value = mood;
        break;
    }

    errorMessage.value = null;
  }

  void toggleReasonForSlot(HarugyeolSlot slot, HarugyeolReason reason) {
    if (!canWriteSlot(slot)) return;

    final target = reasonsForSlot(slot);

    if (target.contains(reason)) {
      target.remove(reason);
    } else {
      target.add(reason);
    }

    errorMessage.value = null;
  }

  void changeOneLineTextForSlot(HarugyeolSlot slot, String value) {
    if (!canWriteSlot(slot)) return;

    final normalized = value.replaceAll('\n', ' ').trimLeft();
    final safeValue = normalized.length <= maxOneLineLength
        ? normalized
        : normalized.substring(0, maxOneLineLength);

    switch (slot) {
      case HarugyeolSlot.midday:
        middayOneLineText.value = safeValue;
        break;
      case HarugyeolSlot.evening:
        eveningOneLineText.value = safeValue;
        break;
    }
  }

  bool hasRequiredInputForSlot(HarugyeolSlot slot) {
    return moodForSlot(slot) != null && reasonsForSlot(slot).isNotEmpty;
  }

  bool canSubmitSlot(HarugyeolSlot slot) {
    if (!canWriteSlot(slot)) return false;
    return hasRequiredInputForSlot(slot);
  }

  bool get canSubmitVisibleInputs {
    final slots = inputSlotsToShow;

    if (slots.isEmpty) return false;

    for (final slot in slots) {
      if (!canSubmitSlot(slot)) {
        return false;
      }
    }

    return true;
  }

  String get visibleInputSubmitBlockedMessage {
    final slots = inputSlotsToShow;

    if (slots.isEmpty) {
      return submitBlockedMessage;
    }

    for (final slot in slots) {
      if (!canWriteSlot(slot)) {
        return '${slot.label} 입력 가능 시간이 아니에요.';
      }

      if (moodForSlot(slot) == null) {
        return '${slot.shortLabel} 장사 체감을 선택해주세요.';
      }

      if (reasonsForSlot(slot).isEmpty) {
        return '${slot.shortLabel} 장사 이유를 하나 이상 선택해주세요.';
      }
    }

    return '잠시 후 다시 시도해주세요.';
  }

  String get visibleInputSubmitButtonText {
    final slots = inputSlotsToShow;

    if (slots.length >= 2) {
      return '낮·저녁 장사 등록하기';
    }

    if (slots.length == 1) {
      final slot = slots.first;

      if (slot == HarugyeolSlot.midday) {
        return '낮 장사 등록하기';
      }

      return '저녁 장사 등록하기';
    }

    return '등록하기';
  }

  void clearInputForSlot(HarugyeolSlot slot) {
    switch (slot) {
      case HarugyeolSlot.midday:
        middayMood.value = null;
        middayReasons.clear();
        middayOneLineText.value = '';
        break;
      case HarugyeolSlot.evening:
        eveningMood.value = null;
        eveningReasons.clear();
        eveningOneLineText.value = '';
        break;
    }
  }

  Future<void> submitVisibleInputs() async {
    if (isSubmitting.value) return;

    final slots = inputSlotsToShow;

    if (slots.isEmpty || !canSubmitVisibleInputs) {
      errorMessage.value = visibleInputSubmitBlockedMessage;
      throw Exception(errorMessage.value);
    }

    final submitDateKey = selectedDateKey;

    isSubmitting.value = true;
    errorMessage.value = null;

    try {
      for (final slot in slots) {
        final mood = moodForSlot(slot);
        final reasons = reasonsForSlot(slot).toList(growable: false);
        final text = oneLineTextForSlot(slot).trim();

        if (mood == null || reasons.isEmpty) {
          errorMessage.value = visibleInputSubmitBlockedMessage;
          throw Exception(errorMessage.value);
        }

        await repo.submitEntry(
          HarugyeolSubmitInput(
            dateKey: submitDateKey,
            slot: slot,
            mood: mood,
            reasons: reasons,
            oneLineText: text,
          ),
        );

        _applySubmittedEntryLocally(
          dateKey: submitDateKey,
          slot: slot,
          mood: mood,
          reasons: reasons,
          oneLineText: text,
        );

        clearInputForSlot(slot);
      }

      requiredContinuationInputSlot.value = null;
      selectedInputSlot.value = null;
      submitSuccessMessage.value = slots.length >= 2
          ? '낮·저녁 장사체감을 남겼어요.'
          : '하루결을 남겼어요.';

      _ensureSelectedInputSlot();
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();

    _refreshNowState();
    _holdLoadingUntilAuthReady();

    _authUserWorker = ever(authController.currentUser, (_) {
      _handleAuthStateChanged();
    });

    _authInitializedWorker = ever(authController.isInitialized, (_) {
      _handleAuthStateChanged();
    });

    _authRestoringWorker = ever(authController.isRestoringCurrentUser, (_) {
      _handleAuthStateChanged();
    });

    _handleAuthStateChanged();
  }

  @override
  void onClose() {
    _summarySub?.cancel();
    _previousSummarySub?.cancel();
    _myEntriesSub?.cancel();
    _commentsSub?.cancel();
    _authUserWorker.dispose();
    _authInitializedWorker.dispose();
    _authRestoringWorker.dispose();
    super.onClose();
  }

  void selectDateOffset(int offset) {
    if (selectedDateOffset.value == offset) return;

    selectedDateOffset.value = offset;
    errorMessage.value = null;
    selectedMood.value = null;
    selectedReasons.clear();
    oneLineText.value = '';
    selectedInputSlot.value = null;
    requiredContinuationInputSlot.value = null;
    submitSuccessMessage.value = '하루결을 남겼어요.';

    middayMood.value = null;
    middayReasons.clear();
    middayOneLineText.value = '';

    eveningMood.value = null;
    eveningReasons.clear();
    eveningOneLineText.value = '';

    _optimisticEntriesBySlot.clear();

    _refreshNowState();
    _bindStreamsWhenAuthReady();
  }

  void selectInputSlot(HarugyeolSlot slot) {
    if (!availableInputSlots.contains(slot)) return;
    if (hasSubmittedSlot(slot)) return;

    selectedInputSlot.value = slot;
    selectedMood.value = null;
    selectedReasons.clear();
    oneLineText.value = '';
    errorMessage.value = null;
  }

  void selectRecommendedInputSlot() {
    final slot = recommendedInputSlot;
    if (slot == null) return;

    selectInputSlot(slot);
  }

  void selectMood(HarugyeolMood mood) {
    if (!isInputEnabled) return;

    selectedMood.value = mood;
    errorMessage.value = null;
  }

  void toggleReason(HarugyeolReason reason) {
    if (!isInputEnabled) return;

    if (selectedReasons.contains(reason)) {
      selectedReasons.remove(reason);
    } else {
      selectedReasons.add(reason);
    }

    errorMessage.value = null;
  }

  void changeOneLineText(String value) {
    if (!isInputEnabled) return;

    final normalized = value.replaceAll('\n', ' ').trimLeft();

    if (normalized.length <= maxOneLineLength) {
      oneLineText.value = normalized;
      return;
    }

    oneLineText.value = normalized.substring(0, maxOneLineLength);
  }

  @override
  Future<void> refresh() async {
    _refreshNowState();
    _bindStreamsWhenAuthReady();
  }

  Future<void> submit() async {
    if (isSubmitting.value) return;

    final slots = inputSlotsToShow;

    if (slots.isNotEmpty) {
      await submitVisibleInputs();
      return;
    }

    final slot = selectedInputSlot.value;

    if (slot == null) {
      errorMessage.value = submitBlockedMessage;
      throw Exception(errorMessage.value);
    }

    final mood = selectedMood.value;

    if (mood == null || selectedReasons.isEmpty) {
      errorMessage.value = submitBlockedMessage;
      throw Exception(errorMessage.value);
    }

    selectMoodForSlot(slot, mood);

    for (final reason in selectedReasons) {
      if (!reasonsForSlot(slot).contains(reason)) {
        reasonsForSlot(slot).add(reason);
      }
    }

    changeOneLineTextForSlot(slot, oneLineText.value);

    await submitVisibleInputs();
  }

  void _applySubmittedEntryLocally({
    required String dateKey,
    required HarugyeolSlot slot,
    required HarugyeolMood mood,
    required List<HarugyeolReason> reasons,
    required String oneLineText,
  }) {
    if (dateKey != selectedDateKey) return;

    final now = DateTime.now();

    final optimisticEntry = HarugyeolEntry(
      id: 'local_${dateKey}_${slot.key}',
      dateKey: dateKey,
      userId: '',
      authorLabel: '나',
      industryId: null,
      locationLabel: null,
      isOwnerVerified: false,
      slot: slot,
      mood: mood,
      score: mood.score,
      reasons: reasons,
      oneLineText: oneLineText,
      createdAt: now,
      updatedAt: now,
    );

    _optimisticEntriesBySlot[slot] = optimisticEntry;

    final merged = _mergeEntriesWithOptimistic(myEntries.toList());
    myEntries.assignAll(merged);
  }

  bool hasSubmittedSlot(HarugyeolSlot slot) {
    return myEntries.any((entry) => entry.slot == slot);
  }

  bool canWriteSlot(HarugyeolSlot slot) {
    if (!isTodaySelected) return false;
    if (!isLoggedIn) return false;
    if (!availableInputSlots.contains(slot)) return false;
    if (hasSubmittedSlot(slot)) return false;
    if (isSubmitting.value) return false;
    return true;
  }

  bool isCommentLikePending(String commentId) {
    final safeCommentId = commentId.trim();
    if (safeCommentId.isEmpty) return false;
    return pendingLikeCommentIds.contains(safeCommentId);
  }

  Future<void> toggleCommentLike(HarugyeolComment comment) async {
    final commentId = comment.id.trim();

    if (commentId.isEmpty) {
      errorMessage.value = '한마디 정보를 확인하지 못했습니다.';
      throw Exception(errorMessage.value);
    }

    if (pendingLikeCommentIds.contains(commentId)) {
      errorMessage.value = '좋아요를 처리하고 있어요.';
      throw Exception(errorMessage.value);
    }

    if (!isLoggedIn) {
      errorMessage.value = '로그인 후 좋아요를 누를 수 있어요.';
      throw Exception(errorMessage.value);
    }

    if (!viewableSlots.contains(comment.slot)) {
      errorMessage.value = '체감을 남긴 시간대의 한마디만 좋아요를 누를 수 있어요.';
      throw Exception(errorMessage.value);
    }

    pendingLikeCommentIds.add(commentId);
    errorMessage.value = null;

    try {
      await repo.toggleCommentLike(
        dateKey: selectedDateKey,
        commentId: commentId,
      );
    } catch (e) {
      errorMessage.value = _friendlyError(e);
      rethrow;
    } finally {
      pendingLikeCommentIds.remove(commentId);
    }
  }

  String flowInsightText(HarugyeolDaySummary value) {
    if (!hasSubmittedAllSlots) return '';
    if (!value.hasData) return '';

    final midday = value.slotStats[HarugyeolSlot.midday]?.averageScore ?? 0;
    final evening = value.slotStats[HarugyeolSlot.evening]?.averageScore ?? 0;

    if (midday <= 0 || evening <= 0) {
      return '';
    }

    final diff = evening - midday;

    if (diff >= 15) {
      return '낮보다 저녁 장사체감이 확실히 좋아졌어요.';
    }

    if (diff >= 6) {
      return '낮보다 저녁 장사체감이 조금 나아졌어요.';
    }

    if (diff <= -15) {
      return '낮보다 저녁 장사체감이 확실히 약해졌어요.';
    }

    if (diff <= -6) {
      return '낮보다 저녁 장사체감이 조금 낮아졌어요.';
    }

    return '낮과 저녁 체감이 비슷하게 이어지고 있어요.';
  }

  String scoreBadgeText(HarugyeolDaySummary? current) {
    if (selectedDateOffset.value != 0) {
      return selectedDateLabel;
    }

    if (current == null || !current.hasData) {
      return '집계 전';
    }

    if (hasSubmittedAllSlots) {
      return '전체';
    }

    if (hasSubmittedMidday) {
      return '낮';
    }

    if (hasSubmittedEvening) {
      return '저녁';
    }

    return '잠금';
  }

  String todayCompareText(HarugyeolDaySummary? current) {
    if (selectedDateOffset.value != 0) {
      return '';
    }

    if (current == null || !current.hasData) {
      return '';
    }

    final previous = previousSummary.value;
    if (previous == null || !previous.hasData) {
      return '';
    }

    if (viewableSlots.isEmpty) {
      return '';
    }

    final currentVisible = current.filteredBySlots(viewableSlots);
    final previousVisible = previous.filteredBySlots(viewableSlots);

    if (!currentVisible.hasData || !previousVisible.hasData) {
      return '';
    }

    final currentScore = currentVisible.averageScore.round();
    final previousScore = previousVisible.averageScore.round();
    final diff = currentScore - previousScore;

    if (diff > 0) {
      return '어제보다 ${diff.abs()}점 높아요';
    }

    if (diff < 0) {
      return '어제보다 ${diff.abs()}점 낮아요';
    }

    return '어제와 같아요';
  }

  List<MapEntry<HarugyeolReason, int>> reasonDistributionEntries(
    HarugyeolDaySummary value,
  ) {
    final entries = HarugyeolReason.values.map((reason) {
      return MapEntry(reason, value.reasonCounts[reason] ?? 0);
    }).toList();

    entries.sort((a, b) {
      final countCompare = b.value.compareTo(a.value);
      if (countCompare != 0) return countCompare;

      return HarugyeolReason.values
          .indexOf(a.key)
          .compareTo(HarugyeolReason.values.indexOf(b.key));
    });

    return entries;
  }

  List<MapEntry<HarugyeolReason, int>> visibleReasonRankEntries(
    HarugyeolDaySummary value,
  ) {
    return reasonDistributionEntries(value);
  }

  String lockedSlotTitle(HarugyeolSlot slot) {
    if (slot == HarugyeolSlot.midday) {
      return '낮 장사 흐름은 잠겨 있어요';
    }

    return '저녁 장사 흐름은 잠겨 있어요';
  }

  String lockedSlotDescription(HarugyeolSlot slot) {
    if (!isTodaySelected) {
      return '해당 날짜에 ${slot.shortLabel} 체감을 남기지 않아 결과를 볼 수 없어요.';
    }

    if (canWriteSlot(slot)) {
      return '${slot.shortLabel} 체감을 남기면 ${slot.shortLabel} 시간대 흐름을 볼 수 있어요.';
    }

    if (slot == HarugyeolSlot.evening) {
      return '저녁 체감은 오후 5시 1분부터 남길 수 있어요.';
    }

    return '낮 체감은 오전 11시부터 자정까지 남길 수 있어요.';
  }

  String dateKeyForOffset(int offset) {
    final date = DateTime.now().add(Duration(days: offset));
    return _dateKey(date);
  }

  void _refreshNowState() {
    _now = DateTime.now();
    availableSlot.value = currentHarugyeolSlot(_now);
    availableInputSlots.assignAll(availableHarugyeolInputSlots(_now));
    nowLabel.value = _formatNowLabel(_now);
    _normalizeContinuationInputSlot();
    _ensureSelectedInputSlot();
  }

  void _ensureSelectedInputSlot() {
    _normalizeContinuationInputSlot();

    final inputSlots = inputSlotsToShow;
    if (inputSlots.isNotEmpty) {
      selectedInputSlot.value = inputSlots.first;
      return;
    }

    final requiredSlot = requiredContinuationInputSlot.value;
    if (requiredSlot != null && canWriteSlot(requiredSlot)) {
      selectedInputSlot.value = requiredSlot;
      return;
    }

    final currentSelected = selectedInputSlot.value;

    if (currentSelected != null && canWriteSlot(currentSelected)) {
      return;
    }

    final recommended = recommendedInputSlot;

    if (recommended == null) {
      selectedInputSlot.value = null;
      return;
    }

    selectedInputSlot.value = recommended;
  }

  void _normalizeContinuationInputSlot() {
    final requiredSlot = requiredContinuationInputSlot.value;
    if (requiredSlot == null) return;

    if (!canWriteSlot(requiredSlot)) {
      requiredContinuationInputSlot.value = null;
    }
  }

  bool get _isAuthReadyForData {
    if (!authController.isInitialized.value) return false;
    if (authController.isRestoringCurrentUser.value) return false;
    return true;
  }

  void _handleAuthStateChanged() {
    _refreshNowState();
    _bindStreamsWhenAuthReady();
  }

  void _holdLoadingUntilAuthReady() {
    _summarySub?.cancel();
    _previousSummarySub?.cancel();
    _myEntriesSub?.cancel();
    _commentsSub?.cancel();

    summary.value = null;
    previousSummary.value = null;
    myEntries.clear();
    comments.clear();
    topComments.clear();

    isSummaryLoading.value = true;
    isPreviousSummaryLoading.value = false;
    isMyEntriesLoading.value = true;
    isCommentsLoading.value = true;
  }

  void _bindStreamsWhenAuthReady() {
    if (!_isAuthReadyForData) {
      _holdLoadingUntilAuthReady();
      return;
    }

    _bindStreams();
  }

  void _bindStreams() {
    final dateKey = selectedDateKey;

    isSummaryLoading.value = true;
    isMyEntriesLoading.value = true;
    isCommentsLoading.value = true;

    _summarySub?.cancel();
    _summarySub = repo.watchDaySummary(dateKey).listen(
      (value) {
        summary.value = value;
        isSummaryLoading.value = false;
      },
      onError: (e) {
        summary.value = HarugyeolDaySummary.empty(dateKey);
        isSummaryLoading.value = false;
        errorMessage.value = _friendlyError(e);
      },
    );

    _bindPreviousSummaryIfNeeded();

    _myEntriesSub?.cancel();
    _myEntriesSub = repo.watchMyEntries(dateKey).listen(
      (items) {
        final serverSlots = items.map((entry) => entry.slot).toSet();

        _optimisticEntriesBySlot.removeWhere((slot, _) {
          return serverSlots.contains(slot);
        });

        myEntries.assignAll(_mergeEntriesWithOptimistic(items));
        isMyEntriesLoading.value = false;
        _ensureSelectedInputSlot();
      },
      onError: (e) {
        final merged = _mergeEntriesWithOptimistic(const <HarugyeolEntry>[]);

        myEntries.assignAll(merged);
        isMyEntriesLoading.value = false;
        _ensureSelectedInputSlot();
        errorMessage.value = _friendlyError(e);
      },
    );

    _commentsSub?.cancel();
    _commentsSub = repo.watchComments(dateKey).listen(
      (items) {
        final sorted = _sortCommentsByLike(items);
        comments.assignAll(sorted);
        topComments.assignAll(sorted.take(3));
        isCommentsLoading.value = false;
      },
      onError: (e) {
        comments.clear();
        topComments.clear();
        isCommentsLoading.value = false;
        errorMessage.value = _friendlyError(e);
      },
    );
  }

  void _bindPreviousSummaryIfNeeded() {
    _previousSummarySub?.cancel();
    previousSummary.value = null;
    isPreviousSummaryLoading.value = false;

    if (!isTodaySelected) {
      return;
    }

    isPreviousSummaryLoading.value = true;
    final previousDateKey = dateKeyForOffset(-1);

    _previousSummarySub = repo.watchDaySummary(previousDateKey).listen(
      (value) {
        previousSummary.value = value;
        isPreviousSummaryLoading.value = false;
      },
      onError: (_) {
        previousSummary.value = HarugyeolDaySummary.empty(previousDateKey);
        isPreviousSummaryLoading.value = false;
      },
    );
  }

  List<HarugyeolEntry> _mergeEntriesWithOptimistic(
    List<HarugyeolEntry> serverItems,
  ) {
    final mergedBySlot = <HarugyeolSlot, HarugyeolEntry>{};

    for (final item in serverItems) {
      mergedBySlot[item.slot] = item;
    }

    for (final entry in _optimisticEntriesBySlot.values) {
      mergedBySlot.putIfAbsent(entry.slot, () => entry);
    }

    final merged = mergedBySlot.values.toList(growable: false);

    merged.sort((a, b) {
      return a.slot.index.compareTo(b.slot.index);
    });

    return merged;
  }

  List<HarugyeolComment> _sortCommentsByLike(List<HarugyeolComment> source) {
    final list = source.toList();

    list.sort((a, b) {
      final likeCompare = b.likeCount.compareTo(a.likeCount);
      if (likeCompare != 0) return likeCompare;

      final dateCompare = b.createdAt.compareTo(a.createdAt);
      if (dateCompare != 0) return dateCompare;

      return a.id.compareTo(b.id);
    });

    return list;
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatNowLabel(DateTime value) {
    final hour = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final period = hour >= 12 ? '오후' : '오전';
    final displayHour = hour == 0
        ? 12
        : hour > 12
            ? hour - 12
            : hour;

    return '$period $displayHour:$minute';
  }

  String _friendlyError(Object error) {
    final raw = error.toString().toLowerCase();

    if (raw.contains('not-found') || raw.contains('function')) {
      return '하루결 서버 기능이 아직 연결되지 않았습니다.';
    }

    if (raw.contains('permission-denied')) {
      return '하루결 권한을 확인하지 못했습니다.';
    }

    if (raw.contains('unauthenticated') || raw.contains('로그인')) {
      return '로그인이 필요합니다.';
    }

    if (raw.contains('already') || raw.contains('duplicate')) {
      return '현재 시간대 하루결은 이미 남겼어요.';
    }

    if (raw.contains('not-found') || raw.contains('comment not found')) {
      return '한마디 정보를 찾지 못했습니다.';
    }

    if (raw.contains('inactive account')) {
      return '현재 계정 상태에서는 이용할 수 없습니다.';
    }

    if (raw.contains('inactive harugyeol comment')) {
      return '현재 좋아요를 누를 수 없는 한마디입니다.';
    }

    if (raw.contains('invalid slot')) {
      return '입력 가능한 시간대가 아닙니다.';
    }

    if (raw.contains('deadline-exceeded') || raw.contains('timeout')) {
      return '요청 시간이 초과되었습니다. 잠시 후 다시 시도해주세요.';
    }

    if (raw.contains('unavailable') || raw.contains('network')) {
      return '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
    }

    return '하루결 처리 중 문제가 발생했습니다.';
  }
}
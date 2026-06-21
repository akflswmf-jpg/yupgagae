class AppUser {
  final String userId;
  final String firebaseUid;
  final String provider;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  /// 앱 전체 권한 역할.
  ///
  /// 현재 기본값:
  /// - user: 일반 사용자
  /// - owner: 사업자 인증 사용자
  /// - admin: 관리자
  /// - banned: 영구정지 사용자
  ///
  /// 사업자 인증 여부는 role 단독이 아니라 businessStatus도 함께 판단한다.
  final String role;

  /// 계정 상태.
  ///
  /// - active: 정상
  /// - suspended: 계정 정지
  /// - withdrawn: 탈퇴
  final String accountStatus;

  /// 운영 제재 상태.
  ///
  /// - normal: 제재 없음
  /// - none: 제재 없음 구버전 호환
  /// - warned: 경고
  /// - suspended: 기간 정지
  /// - permanent_banned: 영구정지
  final String sanctionStatus;

  /// 운영 제재 사유.
  final String? sanctionReason;

  /// 정지 만료 시각.
  ///
  /// warned / permanent_banned 상태에서는 null일 수 있다.
  final DateTime? sanctionUntil;

  /// 마지막 제재 갱신 시각.
  final DateTime? sanctionUpdatedAt;

  /// 제재를 처리한 관리자 userId.
  final String? sanctionUpdatedBy;

  /// 마지막 제재 이력 문서 id.
  final String? lastSanctionId;

  /// 경고 확인 시각.
  ///
  /// warned 상태에서 sanctionUpdatedAt보다 오래된 값이면 다시 안내한다.
  final DateTime? lastWarningAcknowledgedAt;

  /// 본인 인증 상태.
  ///
  /// - none
  /// - verified
  final String identityStatus;

  /// 사업자 인증 상태.
  ///
  /// - none
  /// - pending
  /// - verified
  /// - rejected
  final String businessStatus;

  /// 운영팀/공식 계정 여부.
  ///
  /// 관리자 권한과 공식 계정 표시는 분리한다.
  /// 예: 운영팀 정보글 작성 계정은 공식 계정일 수 있지만,
  /// 반드시 관리자 화면 접근 권한을 가져야 하는 것은 아니다.
  final bool isOfficial;

  // 가입 세팅 상태
  final bool profileSetupCompleted;
  final bool termsAgreed;
  final String? nickname;
  final String? industry;
  final String? region;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastLoginAt;

  const AppUser({
    required this.userId,
    required this.firebaseUid,
    required this.provider,
    required this.email,
    required this.displayName,
    required this.photoUrl,
    required this.role,
    required this.accountStatus,
    required this.sanctionStatus,
    required this.sanctionReason,
    required this.sanctionUntil,
    required this.sanctionUpdatedAt,
    required this.sanctionUpdatedBy,
    required this.lastSanctionId,
    required this.lastWarningAcknowledgedAt,
    required this.identityStatus,
    required this.businessStatus,
    required this.isOfficial,
    required this.profileSetupCompleted,
    required this.termsAgreed,
    required this.nickname,
    required this.industry,
    required this.region,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
  });

  bool get isLoggedIn => firebaseUid.isNotEmpty;

  bool get isActive => accountStatus == 'active';

  bool get isAccountSuspended => accountStatus == 'suspended';

  bool get isWithdrawn => accountStatus == 'withdrawn';

  bool get isIdentityVerified => identityStatus == 'verified';

  bool get isBusinessVerified => businessStatus == 'verified';

  bool get isOwner => isBusinessVerified || isAdmin;

  bool get isAdmin => role == 'admin';

  bool get isRoleBanned => role == 'banned';

  bool get needsProfileSetup => !profileSetupCompleted;

  bool get hasWarning => sanctionStatus == 'warned';

  bool get hasNoSanction {
    return sanctionStatus == 'normal' ||
        sanctionStatus == 'none' ||
        sanctionStatus.trim().isEmpty;
  }

  bool get isPermanentlyBanned {
    return isRoleBanned || sanctionStatus == 'permanent_banned';
  }

  bool get isCurrentlySuspendedBySanction {
    if (sanctionStatus != 'suspended') return false;

    final until = sanctionUntil;
    if (until == null) return true;

    return until.isAfter(DateTime.now());
  }

  bool get isSanctionExpired {
    if (sanctionStatus != 'suspended') return false;

    final until = sanctionUntil;
    if (until == null) return false;

    return !until.isAfter(DateTime.now());
  }

  bool get isSuspended {
    return isAccountSuspended || isCurrentlySuspendedBySanction;
  }

  bool get isCommunityRestricted {
    if (isPermanentlyBanned) return true;
    if (isCurrentlySuspendedBySanction) return true;
    return false;
  }

  bool get shouldShowWarningNotice {
    if (!hasWarning) return false;

    final updated = sanctionUpdatedAt;
    if (updated == null) return lastWarningAcknowledgedAt == null;

    final acknowledged = lastWarningAcknowledgedAt;
    if (acknowledged == null) return true;

    return acknowledged.isBefore(updated);
  }

  String get sanctionDisplayReason {
    final reason = sanctionReason?.trim();
    if (reason != null && reason.isNotEmpty) return reason;

    if (isPermanentlyBanned) return '운영정책 위반';
    if (isCurrentlySuspendedBySanction) return '운영정책 위반';
    if (hasWarning) return '운영정책 위반';

    return '제재 사유 없음';
  }

  String get sanctionUntilLabel {
    final until = sanctionUntil;
    if (until == null) return '해제 시각 없음';

    final y = until.year.toString().padLeft(4, '0');
    final m = until.month.toString().padLeft(2, '0');
    final d = until.day.toString().padLeft(2, '0');
    final h = until.hour.toString().padLeft(2, '0');
    final min = until.minute.toString().padLeft(2, '0');

    return '$y.$m.$d $h:$min';
  }

  bool get canParticipate {
    if (!isLoggedIn) return false;
    if (!isActive) return false;
    if (isCommunityRestricted) return false;
    if (needsProfileSetup) return false;
    return true;
  }

  bool get hasStoreProfile {
    return nickname != null &&
        nickname!.trim().isNotEmpty &&
        industry != null &&
        industry!.trim().isNotEmpty &&
        region != null &&
        region!.trim().isNotEmpty;
  }

  AppUser copyWith({
    String? userId,
    String? firebaseUid,
    String? provider,
    String? email,
    String? displayName,
    String? photoUrl,
    String? role,
    String? accountStatus,
    String? sanctionStatus,
    String? sanctionReason,
    DateTime? sanctionUntil,
    DateTime? sanctionUpdatedAt,
    String? sanctionUpdatedBy,
    String? lastSanctionId,
    DateTime? lastWarningAcknowledgedAt,
    String? identityStatus,
    String? businessStatus,
    bool? isOfficial,
    bool? profileSetupCompleted,
    bool? termsAgreed,
    String? nickname,
    String? industry,
    String? region,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastLoginAt,
  }) {
    return AppUser(
      userId: userId ?? this.userId,
      firebaseUid: firebaseUid ?? this.firebaseUid,
      provider: provider ?? this.provider,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      sanctionStatus: sanctionStatus ?? this.sanctionStatus,
      sanctionReason: sanctionReason ?? this.sanctionReason,
      sanctionUntil: sanctionUntil ?? this.sanctionUntil,
      sanctionUpdatedAt: sanctionUpdatedAt ?? this.sanctionUpdatedAt,
      sanctionUpdatedBy: sanctionUpdatedBy ?? this.sanctionUpdatedBy,
      lastSanctionId: lastSanctionId ?? this.lastSanctionId,
      lastWarningAcknowledgedAt:
          lastWarningAcknowledgedAt ?? this.lastWarningAcknowledgedAt,
      identityStatus: identityStatus ?? this.identityStatus,
      businessStatus: businessStatus ?? this.businessStatus,
      isOfficial: isOfficial ?? this.isOfficial,
      profileSetupCompleted:
          profileSetupCompleted ?? this.profileSetupCompleted,
      termsAgreed: termsAgreed ?? this.termsAgreed,
      nickname: nickname ?? this.nickname,
      industry: industry ?? this.industry,
      region: region ?? this.region,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }
}
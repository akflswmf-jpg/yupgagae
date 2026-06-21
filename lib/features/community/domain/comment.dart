enum CommentStatus {
  active,
  hiddenByReport,
  hiddenByAdmin,
  deletedByAuthor,
  removedByAdmin,
}

extension CommentStatusX on CommentStatus {
  String get key {
    switch (this) {
      case CommentStatus.active:
        return 'active';
      case CommentStatus.hiddenByReport:
        return 'hiddenByReport';
      case CommentStatus.hiddenByAdmin:
        return 'hiddenByAdmin';
      case CommentStatus.deletedByAuthor:
        return 'deletedByAuthor';
      case CommentStatus.removedByAdmin:
        return 'removedByAdmin';
    }
  }
}

CommentStatus commentStatusFromKey(String? value) {
  switch ((value ?? '').trim()) {
    case 'hiddenByReport':
      return CommentStatus.hiddenByReport;
    case 'hiddenByAdmin':
      return CommentStatus.hiddenByAdmin;
    case 'deletedByAuthor':
      return CommentStatus.deletedByAuthor;
    case 'removedByAdmin':
      return CommentStatus.removedByAdmin;
    case 'active':
      return CommentStatus.active;
    default:
      return CommentStatus.hiddenByAdmin;
  }
}

class Comment {
  static const String defaultHiddenReason = '운영 정책 위반 가능성';
  static const String defaultRemovedReason = '관리자 제거 처리';

  final String id;
  final String postId;

  final String authorId;
  final String authorLabel;
  final bool isOwnerVerified;
  final String? industryId;
  final String? locationLabel;

  final String text;

  /// null이면 원댓글, 값이 있으면 대댓글.
  /// yupgagae 정책상 대댓글은 모두 root 원댓글 id를 parentId로 유지한다.
  final String? parentId;

  final int likeCount;
  final Set<String> likedUserIds;

  final int reportCount;
  final Set<String> reportedUserIds;

  /// 기존 호환용:
  /// 이후 서버/로컬 데이터에서 신고 사유 원본 리스트가 필요할 수 있어서 유지한다.
  final List<String> reportReasons;

  /// 관리자 화면 표시용:
  /// 예: {'욕설/비방': 2, '광고/홍보': 1}
  final Map<String, int> reportReasonCounts;

  /// 신고 누적 기준으로 시스템이 임시 블라인드한 상태.
  final bool isReportThresholdReached;

  /// 관리자가 직접 판단해서 숨긴 상태.
  ///
  /// 자동 블라인드와 별개다.
  /// 예:
  /// - isReportThresholdReached == false
  /// - isHiddenByAdmin == true
  /// 이면 관리자가 직접 숨긴 댓글이라 일반 유저에게는 가려진다.
  final bool isHiddenByAdmin;

  /// 관리자가 숨김 처리한 사유.
  ///
  /// 정책:
  /// 관리자가 직접 입력하지 않는다.
  /// 신고 사유 집계에서 가장 많이 접수된 대표 사유를 자동 저장한다.
  final String? adminHiddenReason;

  /// 관리자가 숨김 처리한 시각.
  final DateTime? adminHiddenAt;

  /// 관리자가 심각 위반/개인정보/분쟁 대응 사유로 제거 처리한 시각.
  ///
  /// 실제 문서 삭제가 아니라 보존형 제거 상태다.
  final DateTime? adminRemovedAt;

  /// 관리자 제거 처리 사유.
  ///
  /// 초기에는 관리자가 직접 입력하지 않고 대표 신고 사유 또는 기본 문구를 사용한다.
  final String? adminRemovedReason;

  final bool isDeleted;
  final CommentStatus status;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Comment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorLabel,
    this.isOwnerVerified = false,
    this.industryId,
    this.locationLabel,
    required this.text,
    this.parentId,
    this.likeCount = 0,
    Set<String>? likedUserIds,
    this.reportCount = 0,
    Set<String>? reportedUserIds,
    List<String>? reportReasons,
    Map<String, int>? reportReasonCounts,
    this.isReportThresholdReached = false,
    this.isHiddenByAdmin = false,
    this.adminHiddenReason,
    this.adminHiddenAt,
    this.adminRemovedAt,
    this.adminRemovedReason,
    this.isDeleted = false,
    CommentStatus? status,
    required this.createdAt,
    DateTime? updatedAt,
    this.deletedAt,
  })  : likedUserIds = likedUserIds ?? <String>{},
        reportedUserIds = reportedUserIds ?? <String>{},
        reportReasons = reportReasons ?? const <String>[],
        reportReasonCounts = reportReasonCounts ?? const <String, int>{},
        updatedAt = updatedAt ?? createdAt,
        status = status ??
            _deriveStatus(
              isDeleted: isDeleted,
              isReportThresholdReached: isReportThresholdReached,
              isHiddenByAdmin: isHiddenByAdmin,
              deletedAt: deletedAt,
              adminRemovedAt: adminRemovedAt,
            );

  String? get parentCommentId => parentId;
  bool get isReply => parentId != null && parentId!.trim().isNotEmpty;
  bool get isRoot => !isReply;

  bool get isRemovedByAdmin {
    return status == CommentStatus.removedByAdmin || adminRemovedAt != null;
  }

  bool get isHiddenFromPublic {
    return status == CommentStatus.hiddenByReport ||
        status == CommentStatus.hiddenByAdmin ||
        status == CommentStatus.deletedByAuthor ||
        status == CommentStatus.removedByAdmin ||
        isReportThresholdReached ||
        isHiddenByAdmin ||
        isDeleted ||
        deletedAt != null ||
        adminRemovedAt != null;
  }

  /// 가장 많이 접수된 신고 사유.
  ///
  /// 동률이면 문자열 오름차순으로 고정해서 화면 결과가 흔들리지 않게 한다.
  String? get primaryReportReason {
    final normalizedCounts = <String, int>{};

    if (reportReasonCounts.isNotEmpty) {
      reportReasonCounts.forEach((rawReason, rawCount) {
        final reason = rawReason.trim();
        if (reason.isEmpty || rawCount <= 0) return;

        normalizedCounts[reason] = (normalizedCounts[reason] ?? 0) + rawCount;
      });
    }

    if (normalizedCounts.isEmpty && reportReasons.isNotEmpty) {
      for (final rawReason in reportReasons) {
        final reason = rawReason.trim();
        if (reason.isEmpty) continue;

        normalizedCounts[reason] = (normalizedCounts[reason] ?? 0) + 1;
      }
    }

    if (normalizedCounts.isEmpty) return null;

    final entries = normalizedCounts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;

        return a.key.compareTo(b.key);
      });

    return entries.first.key;
  }

  /// 작성자/관리자 화면에서 대표 사유가 없을 때 쓰는 기본 문구.
  String get displayHiddenReason {
    final adminReason = adminHiddenReason?.trim();
    if (adminReason != null && adminReason.isNotEmpty) {
      return adminReason;
    }

    final primaryReason = primaryReportReason?.trim();
    if (primaryReason != null && primaryReason.isNotEmpty) {
      return primaryReason;
    }

    return defaultHiddenReason;
  }

  String get displayRemovedReason {
    final removedReason = adminRemovedReason?.trim();
    if (removedReason != null && removedReason.isNotEmpty) {
      return removedReason;
    }

    final primaryReason = primaryReportReason?.trim();
    if (primaryReason != null && primaryReason.isNotEmpty) {
      return primaryReason;
    }

    return defaultRemovedReason;
  }

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorLabel,
    bool? isOwnerVerified,
    String? industryId,
    bool clearIndustryId = false,
    String? locationLabel,
    bool clearLocationLabel = false,
    String? text,
    Object? parentId = _sentinel,
    int? likeCount,
    Set<String>? likedUserIds,
    int? reportCount,
    Set<String>? reportedUserIds,
    List<String>? reportReasons,
    Map<String, int>? reportReasonCounts,
    bool? isReportThresholdReached,
    bool? isHiddenByAdmin,
    String? adminHiddenReason,
    bool clearAdminHiddenReason = false,
    DateTime? adminHiddenAt,
    bool clearAdminHiddenAt = false,
    DateTime? adminRemovedAt,
    bool clearAdminRemovedAt = false,
    String? adminRemovedReason,
    bool clearAdminRemovedReason = false,
    bool? isDeleted,
    CommentStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) {
    final nextCreatedAt = createdAt ?? this.createdAt;
    final nextUpdatedAt = updatedAt ?? this.updatedAt;
    final nextDeletedAt = clearDeletedAt ? null : deletedAt ?? this.deletedAt;
    final nextAdminRemovedAt =
        clearAdminRemovedAt ? null : adminRemovedAt ?? this.adminRemovedAt;
    final nextIsDeleted = isDeleted ?? this.isDeleted;
    final nextIsReportThresholdReached =
        isReportThresholdReached ?? this.isReportThresholdReached;
    final nextIsHiddenByAdmin = isHiddenByAdmin ?? this.isHiddenByAdmin;

    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorLabel: authorLabel ?? this.authorLabel,
      isOwnerVerified: isOwnerVerified ?? this.isOwnerVerified,
      industryId: clearIndustryId ? null : industryId ?? this.industryId,
      locationLabel:
          clearLocationLabel ? null : locationLabel ?? this.locationLabel,
      text: text ?? this.text,
      parentId:
          identical(parentId, _sentinel) ? this.parentId : parentId as String?,
      likeCount: likeCount ?? this.likeCount,
      likedUserIds: likedUserIds ?? Set<String>.from(this.likedUserIds),
      reportCount: reportCount ?? this.reportCount,
      reportedUserIds:
          reportedUserIds ?? Set<String>.from(this.reportedUserIds),
      reportReasons: reportReasons ?? List<String>.from(this.reportReasons),
      reportReasonCounts:
          reportReasonCounts ?? Map<String, int>.from(this.reportReasonCounts),
      isReportThresholdReached: nextIsReportThresholdReached,
      isHiddenByAdmin: nextIsHiddenByAdmin,
      adminHiddenReason: clearAdminHiddenReason
          ? null
          : adminHiddenReason ?? this.adminHiddenReason,
      adminHiddenAt:
          clearAdminHiddenAt ? null : adminHiddenAt ?? this.adminHiddenAt,
      adminRemovedAt: nextAdminRemovedAt,
      adminRemovedReason: clearAdminRemovedReason
          ? null
          : adminRemovedReason ?? this.adminRemovedReason,
      isDeleted: nextIsDeleted,
      status: status ??
          _deriveStatus(
            isDeleted: nextIsDeleted,
            isReportThresholdReached: nextIsReportThresholdReached,
            isHiddenByAdmin: nextIsHiddenByAdmin,
            deletedAt: nextDeletedAt,
            adminRemovedAt: nextAdminRemovedAt,
          ),
      createdAt: nextCreatedAt,
      updatedAt: nextUpdatedAt,
      deletedAt: nextDeletedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'postId': postId,
      'authorId': authorId,
      'authorLabel': authorLabel,
      'isOwnerVerified': isOwnerVerified,
      'industryId': industryId,
      'locationLabel': locationLabel,
      'text': text,
      'parentId': parentId,
      'likeCount': likeCount,
      'likedUserIds': likedUserIds.toList(),
      'reportCount': reportCount,
      'reportedUserIds': reportedUserIds.toList(),
      'reportReasons': List<String>.from(reportReasons),
      'reportReasonCounts': Map<String, int>.from(reportReasonCounts),
      'isReportThresholdReached': isReportThresholdReached,
      'isHiddenByAdmin': isHiddenByAdmin,
      'adminHiddenReason': adminHiddenReason,
      'adminHiddenAt': adminHiddenAt?.toIso8601String(),
      'adminRemovedAt': adminRemovedAt?.toIso8601String(),
      'adminRemovedReason': adminRemovedReason,
      'isDeleted': isDeleted,
      'status': status.key,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
    final loadedReasons = ((json['reportReasons'] as List?) ?? const [])
        .map((e) => e.toString())
        .where((e) => e.trim().isNotEmpty)
        .toList();

    final loadedReasonCounts = _parseReasonCounts(
      json['reportReasonCounts'],
    );

    final mergedReasonCounts = loadedReasonCounts.isNotEmpty
        ? loadedReasonCounts
        : _buildReasonCountsFromReasons(loadedReasons);

    final createdAt = _parseDateTime(json['createdAt']) ?? DateTime.now();
    final updatedAt = _parseDateTime(json['updatedAt']) ?? createdAt;
    final deletedAt = _parseDateTime(json['deletedAt']);
    final adminRemovedAt = _parseDateTime(json['adminRemovedAt']);

    final isDeleted = (json['isDeleted'] as bool?) ?? false;
    final isReportThresholdReached =
        (json['isReportThresholdReached'] as bool?) ?? false;
    final isHiddenByAdmin = (json['isHiddenByAdmin'] as bool?) ?? false;

    final status = _statusFromJson(
      json['status'],
      isDeleted: isDeleted,
      isReportThresholdReached: isReportThresholdReached,
      isHiddenByAdmin: isHiddenByAdmin,
      deletedAt: deletedAt,
      adminRemovedAt: adminRemovedAt,
    );

    return Comment(
      id: (json['id'] ?? '').toString(),
      postId: (json['postId'] ?? '').toString(),
      authorId: (json['authorId'] ?? '').toString(),
      authorLabel: (json['authorLabel'] ?? '').toString(),
      isOwnerVerified: (json['isOwnerVerified'] as bool?) ?? false,
      industryId: json['industryId']?.toString(),
      locationLabel: json['locationLabel']?.toString(),
      text: (json['text'] ?? '').toString(),
      parentId: json['parentId']?.toString(),
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      likedUserIds: (((json['likedUserIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet()),
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      reportedUserIds: (((json['reportedUserIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet()),
      reportReasons: loadedReasons,
      reportReasonCounts: mergedReasonCounts,
      isReportThresholdReached: isReportThresholdReached,
      isHiddenByAdmin: isHiddenByAdmin,
      adminHiddenReason: _nullableTrimmedString(json['adminHiddenReason']),
      adminHiddenAt: _parseDateTime(json['adminHiddenAt']),
      adminRemovedAt: adminRemovedAt,
      adminRemovedReason: _nullableTrimmedString(json['adminRemovedReason']),
      isDeleted: isDeleted,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
    );
  }

  static CommentStatus _deriveStatus({
    required bool isDeleted,
    required bool isReportThresholdReached,
    required bool isHiddenByAdmin,
    required DateTime? deletedAt,
    required DateTime? adminRemovedAt,
  }) {
    if (adminRemovedAt != null) {
      return CommentStatus.removedByAdmin;
    }

    if (isDeleted || deletedAt != null) {
      return CommentStatus.deletedByAuthor;
    }

    if (isHiddenByAdmin) {
      return CommentStatus.hiddenByAdmin;
    }

    if (isReportThresholdReached) {
      return CommentStatus.hiddenByReport;
    }

    return CommentStatus.active;
  }

  static CommentStatus _statusFromJson(
    dynamic rawValue, {
    required bool isDeleted,
    required bool isReportThresholdReached,
    required bool isHiddenByAdmin,
    required DateTime? deletedAt,
    required DateTime? adminRemovedAt,
  }) {
    final text = rawValue?.toString().trim();

    if (text != null && text.isNotEmpty) {
      return commentStatusFromKey(text);
    }

    return _deriveStatus(
      isDeleted: isDeleted,
      isReportThresholdReached: isReportThresholdReached,
      isHiddenByAdmin: isHiddenByAdmin,
      deletedAt: deletedAt,
      adminRemovedAt: adminRemovedAt,
    );
  }

  static String? _nullableTrimmedString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static DateTime? _parseDateTime(dynamic value) {
    final raw = value?.toString().trim();
    if (raw == null || raw.isEmpty) return null;

    return DateTime.tryParse(raw);
  }

  static Map<String, int> _parseReasonCounts(dynamic value) {
    if (value is! Map) return <String, int>{};

    final result = <String, int>{};

    value.forEach((key, rawCount) {
      final reason = key.toString().trim();
      if (reason.isEmpty) return;

      final count = (rawCount as num?)?.toInt() ?? 0;
      if (count <= 0) return;

      result[reason] = count;
    });

    return result;
  }

  static Map<String, int> _buildReasonCountsFromReasons(
    List<String> reasons,
  ) {
    final result = <String, int>{};

    for (final raw in reasons) {
      final reason = raw.trim();
      if (reason.isEmpty) continue;

      result[reason] = (result[reason] ?? 0) + 1;
    }

    return result;
  }
}

const Object _sentinel = Object();
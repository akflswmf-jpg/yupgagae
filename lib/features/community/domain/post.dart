enum BoardType { free, owner, used }

extension BoardTypeX on BoardType {
  String get key {
    switch (this) {
      case BoardType.free:
        return 'free';
      case BoardType.owner:
        return 'owner';
      case BoardType.used:
        return 'used';
    }
  }
}

BoardType boardTypeFromKey(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'owner':
      return BoardType.owner;
    case 'used':
      return BoardType.used;
    case 'free':
    default:
      return BoardType.free;
  }
}

enum UsedPostType {
  store,
  item,
}

extension UsedPostTypeX on UsedPostType {
  String get key {
    switch (this) {
      case UsedPostType.store:
        return 'store';
      case UsedPostType.item:
        return 'item';
    }
  }
}

UsedPostType? usedPostTypeFromKey(String? value) {
  switch ((value ?? '').trim().toLowerCase()) {
    case 'store':
      return UsedPostType.store;
    case 'item':
      return UsedPostType.item;
    default:
      return null;
  }
}

enum PostStatus {
  active,
  hiddenByReport,
  hiddenByAdmin,
  deletedByAuthor,
  removedByAdmin,
}

extension PostStatusX on PostStatus {
  String get key {
    switch (this) {
      case PostStatus.active:
        return 'active';
      case PostStatus.hiddenByReport:
        return 'hiddenByReport';
      case PostStatus.hiddenByAdmin:
        return 'hiddenByAdmin';
      case PostStatus.deletedByAuthor:
        return 'deletedByAuthor';
      case PostStatus.removedByAdmin:
        return 'removedByAdmin';
    }
  }
}

PostStatus postStatusFromKey(String? value) {
  switch ((value ?? '').trim()) {
    case 'hiddenByReport':
      return PostStatus.hiddenByReport;
    case 'hiddenByAdmin':
      return PostStatus.hiddenByAdmin;
    case 'deletedByAuthor':
      return PostStatus.deletedByAuthor;
    case 'removedByAdmin':
      return PostStatus.removedByAdmin;
    case 'active':
      return PostStatus.active;
    default:
      return PostStatus.hiddenByAdmin;
  }
}

class Post {
  static const String defaultHiddenReason = '운영 정책 위반 가능성';
  static const String defaultRemovedReason = '관리자 제거 처리';

  final String id;
  final String authorId;
  final String authorLabel;
  final bool isOwnerVerified;

  final String title;
  final String body;

  final BoardType boardType;
  final UsedPostType? usedType;

  final bool isSold;

  final String? industryId;
  final String? locationLabel;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  final PostStatus status;

  final int commentCount;
  final int likeCount;
  final int viewCount;

  final int reportCount;
  final Set<String> reportedUserIds;

  /// 기존 호환용:
  /// 이전 로컬 데이터에 reportReasons만 남아 있을 수 있어서 유지한다.
  final List<String> reportReasons;

  /// 관리자 화면 표시용:
  /// 예: {'욕설/비방': 2, '광고/홍보': 1}
  final Map<String, int> reportReasonCounts;

  /// 신고 누적 기준으로 시스템이 임시 블라인드한 상태.
  ///
  /// 관리자 숨김과 분리한다.
  /// - true: 신고 임계치 도달로 일반 피드/상세에서 가림
  /// - false: 신고 기록은 남아 있어도 자동 블라인드는 해제된 상태
  final bool isReportThresholdReached;

  /// 관리자가 직접 판단해서 숨긴 상태.
  ///
  /// 자동 블라인드와 별개다.
  /// 예:
  /// - isReportThresholdReached == false
  /// - isHiddenByAdmin == true
  /// 이면 관리자가 직접 숨긴 글이라 일반 유저에게는 가려진다.
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

  /// 서버 저장 이미지 URL.
  ///
  /// 신규 기준은 imageUrls다.
  /// 작성 중 로컬 파일 경로는 Controller에서만 들고 있고,
  /// Firestore에는 Storage download URL만 저장한다.
  final List<String> imageUrls;

  final Set<String> likedUserIds;

  Post({
    required this.id,
    required this.authorId,
    required this.authorLabel,
    this.isOwnerVerified = false,
    required this.title,
    required this.body,
    required this.createdAt,
    DateTime? updatedAt,
    this.deletedAt,
    PostStatus? status,
    this.boardType = BoardType.free,
    this.usedType,
    this.isSold = false,
    this.industryId,
    this.locationLabel,
    this.commentCount = 0,
    this.likeCount = 0,
    this.viewCount = 0,
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
    List<String>? imageUrls,
    List<String>? imagePaths,
    Set<String>? likedUserIds,
  })  : updatedAt = updatedAt ?? createdAt,
        status = status ??
            _deriveStatus(
              isReportThresholdReached: isReportThresholdReached,
              isHiddenByAdmin: isHiddenByAdmin,
              deletedAt: deletedAt,
              adminRemovedAt: adminRemovedAt,
            ),
        reportedUserIds = reportedUserIds ?? <String>{},
        reportReasons = reportReasons ?? const <String>[],
        reportReasonCounts = reportReasonCounts ?? const <String, int>{},
        imageUrls = imageUrls ?? imagePaths ?? const <String>[],
        likedUserIds = likedUserIds ?? <String>{};

  /// 기존 UI/Controller 호환용.
  ///
  /// 다음 단계에서 화면/Controller 쪽도 imageUrls로 정리하면
  /// 이 getter는 제거할 수 있다.
  List<String> get imagePaths {
    return imageUrls;
  }

  bool get isDeleted {
    return status == PostStatus.deletedByAuthor || deletedAt != null;
  }

  bool get isRemovedByAdmin {
    return status == PostStatus.removedByAdmin || adminRemovedAt != null;
  }

  bool get isHiddenFromPublic {
    return status == PostStatus.hiddenByReport ||
        status == PostStatus.hiddenByAdmin ||
        status == PostStatus.deletedByAuthor ||
        status == PostStatus.removedByAdmin ||
        isReportThresholdReached ||
        isHiddenByAdmin ||
        deletedAt != null ||
        adminRemovedAt != null;
  }

  /// 가장 많이 접수된 신고 사유.
  ///
  /// 동률이면 문자열 오름차순으로 고정해서 화면/저장 결과가 흔들리지 않게 한다.
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

  Post copyWith({
    String? id,
    String? authorId,
    String? authorLabel,
    bool? isOwnerVerified,
    String? title,
    String? body,
    BoardType? boardType,
    Object? usedType = _sentinel,
    bool? isSold,
    String? industryId,
    bool clearIndustryId = false,
    String? locationLabel,
    bool clearLocationLabel = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
    PostStatus? status,
    int? commentCount,
    int? likeCount,
    int? viewCount,
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
    List<String>? imageUrls,
    List<String>? imagePaths,
    Set<String>? likedUserIds,
  }) {
    final nextCreatedAt = createdAt ?? this.createdAt;
    final nextUpdatedAt = updatedAt ?? this.updatedAt;
    final nextDeletedAt = clearDeletedAt ? null : deletedAt ?? this.deletedAt;
    final nextAdminRemovedAt =
        clearAdminRemovedAt ? null : adminRemovedAt ?? this.adminRemovedAt;
    final nextIsReportThresholdReached =
        isReportThresholdReached ?? this.isReportThresholdReached;
    final nextIsHiddenByAdmin = isHiddenByAdmin ?? this.isHiddenByAdmin;

    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorLabel: authorLabel ?? this.authorLabel,
      isOwnerVerified: isOwnerVerified ?? this.isOwnerVerified,
      title: title ?? this.title,
      body: body ?? this.body,
      boardType: boardType ?? this.boardType,
      usedType: identical(usedType, _sentinel)
          ? this.usedType
          : usedType as UsedPostType?,
      isSold: isSold ?? this.isSold,
      industryId: clearIndustryId ? null : industryId ?? this.industryId,
      locationLabel:
          clearLocationLabel ? null : locationLabel ?? this.locationLabel,
      createdAt: nextCreatedAt,
      updatedAt: nextUpdatedAt,
      deletedAt: nextDeletedAt,
      status: status ??
          _deriveStatus(
            isReportThresholdReached: nextIsReportThresholdReached,
            isHiddenByAdmin: nextIsHiddenByAdmin,
            deletedAt: nextDeletedAt,
            adminRemovedAt: nextAdminRemovedAt,
          ),
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
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
      imageUrls: imageUrls ?? imagePaths ?? List<String>.from(this.imageUrls),
      likedUserIds: likedUserIds ?? Set<String>.from(this.likedUserIds),
    );
  }

  Map<String, dynamic> toJson() {
    final safeImageUrls = List<String>.from(imageUrls);

    return {
      'id': id,
      'authorId': authorId,
      'authorLabel': authorLabel,
      'isOwnerVerified': isOwnerVerified,
      'title': title,
      'body': body,
      'boardType': boardType.key,
      'usedType': usedType?.key,
      'isSold': isSold,
      'industryId': industryId,
      'locationLabel': locationLabel,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'deletedAt': deletedAt?.toIso8601String(),
      'status': status.key,
      'commentCount': commentCount,
      'likeCount': likeCount,
      'viewCount': viewCount,
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

      // 신규 기준
      'imageUrls': safeImageUrls,

      // 기존 rules/UI/마이그레이션 호환용.
      // 다음 rules 교체 후에도 당분간 유지하는 편이 안전하다.
      'imagePaths': safeImageUrls,

      'likedUserIds': likedUserIds.toList(),
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
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

    final isReportThresholdReached =
        (json['isReportThresholdReached'] as bool?) ?? false;
    final isHiddenByAdmin = (json['isHiddenByAdmin'] as bool?) ?? false;

    final status = _statusFromJson(
      json['status'],
      isReportThresholdReached: isReportThresholdReached,
      isHiddenByAdmin: isHiddenByAdmin,
      deletedAt: deletedAt,
      adminRemovedAt: adminRemovedAt,
    );

    final loadedImageUrls = _parseStringList(json['imageUrls']);
    final loadedLegacyImagePaths = _parseStringList(json['imagePaths']);

    return Post(
      id: (json['id'] ?? '').toString(),
      authorId: (json['authorId'] ?? '').toString(),
      authorLabel: (json['authorLabel'] ?? '익명').toString(),
      isOwnerVerified: (json['isOwnerVerified'] as bool?) ?? false,
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      boardType: boardTypeFromKey(json['boardType']?.toString()),
      usedType: usedPostTypeFromKey(json['usedType']?.toString()),
      isSold: (json['isSold'] as bool?) ?? false,
      industryId: json['industryId']?.toString(),
      locationLabel: json['locationLabel']?.toString(),
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      status: status,
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
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
      imageUrls:
          loadedImageUrls.isNotEmpty ? loadedImageUrls : loadedLegacyImagePaths,
      likedUserIds: (((json['likedUserIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet()),
    );
  }

  static PostStatus _deriveStatus({
    required bool isReportThresholdReached,
    required bool isHiddenByAdmin,
    required DateTime? deletedAt,
    required DateTime? adminRemovedAt,
  }) {
    if (adminRemovedAt != null) {
      return PostStatus.removedByAdmin;
    }

    if (deletedAt != null) {
      return PostStatus.deletedByAuthor;
    }

    if (isHiddenByAdmin) {
      return PostStatus.hiddenByAdmin;
    }

    if (isReportThresholdReached) {
      return PostStatus.hiddenByReport;
    }

    return PostStatus.active;
  }

  static PostStatus _statusFromJson(
    dynamic rawValue, {
    required bool isReportThresholdReached,
    required bool isHiddenByAdmin,
    required DateTime? deletedAt,
    required DateTime? adminRemovedAt,
  }) {
    final text = rawValue?.toString().trim();

    if (text != null && text.isNotEmpty) {
      return postStatusFromKey(text);
    }

    return _deriveStatus(
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

  static List<String> _parseStringList(dynamic value) {
    return ((value as List?) ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
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
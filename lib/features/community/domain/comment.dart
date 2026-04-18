class Comment {
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
  final bool isReportThresholdReached;

  final bool isDeleted;
  final DateTime createdAt;

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
    this.isReportThresholdReached = false,
    this.isDeleted = false,
    required this.createdAt,
  })  : likedUserIds = likedUserIds ?? <String>{},
        reportedUserIds = reportedUserIds ?? <String>{};

  String? get parentCommentId => parentId;
  bool get isReply => parentId != null && parentId!.trim().isNotEmpty;
  bool get isRoot => !isReply;

  Comment copyWith({
    String? id,
    String? postId,
    String? authorId,
    String? authorLabel,
    bool? isOwnerVerified,
    String? industryId,
    String? locationLabel,
    String? text,
    Object? parentId = _sentinel,
    int? likeCount,
    Set<String>? likedUserIds,
    int? reportCount,
    Set<String>? reportedUserIds,
    bool? isReportThresholdReached,
    bool? isDeleted,
    DateTime? createdAt,
  }) {
    return Comment(
      id: id ?? this.id,
      postId: postId ?? this.postId,
      authorId: authorId ?? this.authorId,
      authorLabel: authorLabel ?? this.authorLabel,
      isOwnerVerified: isOwnerVerified ?? this.isOwnerVerified,
      industryId: industryId ?? this.industryId,
      locationLabel: locationLabel ?? this.locationLabel,
      text: text ?? this.text,
      parentId: identical(parentId, _sentinel) ? this.parentId : parentId as String?,
      likeCount: likeCount ?? this.likeCount,
      likedUserIds: likedUserIds ?? Set<String>.from(this.likedUserIds),
      reportCount: reportCount ?? this.reportCount,
      reportedUserIds: reportedUserIds ?? Set<String>.from(this.reportedUserIds),
      isReportThresholdReached:
          isReportThresholdReached ?? this.isReportThresholdReached,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
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
      'isReportThresholdReached': isReportThresholdReached,
      'isDeleted': isDeleted,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Comment.fromJson(Map<String, dynamic> json) {
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
      isReportThresholdReached:
          (json['isReportThresholdReached'] as bool?) ?? false,
      isDeleted: (json['isDeleted'] as bool?) ?? false,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

const Object _sentinel = Object();
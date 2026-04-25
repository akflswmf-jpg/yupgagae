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

class Post {
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

  final int commentCount;
  final int likeCount;
  final int viewCount;

  final int reportCount;
  final Set<String> reportedUserIds;
  final bool isReportThresholdReached;

  final List<String> imagePaths;
  final Set<String> likedUserIds;

  Post({
    required this.id,
    required this.authorId,
    required this.authorLabel,
    this.isOwnerVerified = false,
    required this.title,
    required this.body,
    required this.createdAt,
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
    this.isReportThresholdReached = false,
    List<String>? imagePaths,
    Set<String>? likedUserIds,
  })  : reportedUserIds = reportedUserIds ?? <String>{},
        imagePaths = imagePaths ?? const [],
        likedUserIds = likedUserIds ?? <String>{};

  Post copyWith({
    String? id,
    String? authorId,
    String? authorLabel,
    bool? isOwnerVerified,
    String? title,
    String? body,
    BoardType? boardType,
    UsedPostType? usedType,
    bool? isSold,
    String? industryId,
    String? locationLabel,
    DateTime? createdAt,
    int? commentCount,
    int? likeCount,
    int? viewCount,
    int? reportCount,
    Set<String>? reportedUserIds,
    bool? isReportThresholdReached,
    List<String>? imagePaths,
    Set<String>? likedUserIds,
  }) {
    return Post(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorLabel: authorLabel ?? this.authorLabel,
      isOwnerVerified: isOwnerVerified ?? this.isOwnerVerified,
      title: title ?? this.title,
      body: body ?? this.body,
      boardType: boardType ?? this.boardType,
      usedType: usedType ?? this.usedType,
      isSold: isSold ?? this.isSold,
      industryId: industryId ?? this.industryId,
      locationLabel: locationLabel ?? this.locationLabel,
      createdAt: createdAt ?? this.createdAt,
      commentCount: commentCount ?? this.commentCount,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
      reportCount: reportCount ?? this.reportCount,
      reportedUserIds:
          reportedUserIds ?? Set<String>.from(this.reportedUserIds),
      isReportThresholdReached:
          isReportThresholdReached ?? this.isReportThresholdReached,
      imagePaths: imagePaths ?? List<String>.from(this.imagePaths),
      likedUserIds: likedUserIds ?? Set<String>.from(this.likedUserIds),
    );
  }

  Map<String, dynamic> toJson() {
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
      'commentCount': commentCount,
      'likeCount': likeCount,
      'viewCount': viewCount,
      'reportCount': reportCount,
      'reportedUserIds': reportedUserIds.toList(),
      'isReportThresholdReached': isReportThresholdReached,
      'imagePaths': List<String>.from(imagePaths),
      'likedUserIds': likedUserIds.toList(),
    };
  }

  factory Post.fromJson(Map<String, dynamic> json) {
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
      createdAt:
          DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
              DateTime.now(),
      commentCount: (json['commentCount'] as num?)?.toInt() ?? 0,
      likeCount: (json['likeCount'] as num?)?.toInt() ?? 0,
      viewCount: (json['viewCount'] as num?)?.toInt() ?? 0,
      reportCount: (json['reportCount'] as num?)?.toInt() ?? 0,
      reportedUserIds: (((json['reportedUserIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet()),
      isReportThresholdReached:
          (json['isReportThresholdReached'] as bool?) ?? false,
      imagePaths: ((json['imagePaths'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
      likedUserIds: (((json['likedUserIds'] as List?) ?? const [])
          .map((e) => e.toString())
          .toSet()),
    );
  }
}
class AppNotificationItem {
  final String id;
  final String type;
  final String message;
  final String? targetUserId;
  final String? targetPostId;
  final String? targetCommentId;
  final bool isRead;
  final DateTime createdAt;

  const AppNotificationItem({
    required this.id,
    required this.type,
    required this.message,
    this.targetUserId,
    this.targetPostId,
    this.targetCommentId,
    required this.isRead,
    required this.createdAt,
  });

  AppNotificationItem copyWith({
    String? id,
    String? type,
    String? message,
    String? targetUserId,
    String? targetPostId,
    String? targetCommentId,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotificationItem(
      id: id ?? this.id,
      type: type ?? this.type,
      message: message ?? this.message,
      targetUserId: targetUserId ?? this.targetUserId,
      targetPostId: targetPostId ?? this.targetPostId,
      targetCommentId: targetCommentId ?? this.targetCommentId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'message': message,
      'targetUserId': targetUserId,
      'targetPostId': targetPostId,
      'targetCommentId': targetCommentId,
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      message: (json['message'] ?? '').toString(),
      targetUserId: json['targetUserId']?.toString(),
      targetPostId: json['targetPostId']?.toString(),
      targetCommentId: json['targetCommentId']?.toString(),
      isRead: json['isRead'] == true,
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
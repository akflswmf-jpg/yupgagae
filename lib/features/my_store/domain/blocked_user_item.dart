class BlockedUserItem {
  final String userId;
  final String nickname;
  final String? industry;
  final String? region;
  final DateTime blockedAt;

  const BlockedUserItem({
    required this.userId,
    required this.nickname,
    this.industry,
    this.region,
    required this.blockedAt,
  });

  BlockedUserItem copyWith({
    String? userId,
    String? nickname,
    String? industry,
    String? region,
    DateTime? blockedAt,
  }) {
    return BlockedUserItem(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      industry: industry ?? this.industry,
      region: region ?? this.region,
      blockedAt: blockedAt ?? this.blockedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'nickname': nickname,
      'industry': industry,
      'region': region,
      'blockedAt': blockedAt.toIso8601String(),
    };
  }

  factory BlockedUserItem.fromJson(Map<String, dynamic> json) {
    return BlockedUserItem(
      userId: (json['userId'] ?? '').toString(),
      nickname: (json['nickname'] ?? '').toString(),
      industry: json['industry']?.toString(),
      region: json['region']?.toString(),
      blockedAt: DateTime.tryParse((json['blockedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
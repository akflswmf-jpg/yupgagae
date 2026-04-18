// lib/features/community/domain/moderation_policy.dart
import 'package:flutter/foundation.dart';

enum PostStatus { normal, hidden, removed }

@immutable
class ModerationPolicy {
  // ===== Reports =====
  static const int autoHideReportCount = 3;

  // (나중) 정지/가중치 관련: 지금은 값만 박제
  static const int tempBanReportCount = 5;
  static const double tempBanWeightThreshold = 10.0;

  // 정지 단계(누적): “박제”
  static const List<Duration> banStages = [
    Duration(days: 1),
    Duration(days: 3),
    Duration(days: 7),
  ];

  // ===== Hot score weights =====
  // 점수 공식은 “한 파일에서만” 유지
  static const double likeW = 3.0;
  static const double commentW = 4.0;
  static const double viewW = 0.2;
  static const double reportW = 6.0;

  static double hotScore({
    required int likeCount,
    required int commentCount,
    required int viewCount,
    required int reportCount,
  }) {
    return (likeCount * likeW) +
        (commentCount * commentW) +
        (viewCount * viewW) -
        (reportCount * reportW);
  }

  static PostStatus statusFromReports({
    required int reportCount,
    required PostStatus current,
  }) {
    if (current == PostStatus.removed) return current;
    if (reportCount >= autoHideReportCount) return PostStatus.hidden;
    return PostStatus.normal;
  }
}
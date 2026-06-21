class ModerationPolicy {
  /// 1단계: 신고 임계치 → 글 숨김(가시성 제한)
  static const int autoHideReportCount = 3;

  /// 2단계: 숨김 누적(작성자) → 글쓰기 쿨다운 증가
  static const int hiddenStrikeThreshold1 = 3;
  static const int hiddenStrikeThreshold2 = 6;

  static const int cooldownSecondsNormal = 45;
  static const int cooldownSecondsLevel1 = 180; // 3분
  static const int cooldownSecondsLevel2 = 600; // 10분

  /// 3단계: 수동 검토 플래그(자동 제재 아님)
  static const int manualReviewThreshold = 15;
}
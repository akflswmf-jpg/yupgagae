class PostPolicy {
  /// MVP 기준: 사진 최대 2장
  static const int maxImagesPerPost = 2;

  /// 글 연속 작성 제한
  static const int postCooldownSeconds = 45;

  /// 링크 제한
  static const int maxLinksPerPost = 1;

  /// 중복 작성 방지
  static const int duplicateWindowMinutes = 30;
}
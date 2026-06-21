class PostPolicy {
  // 사진은 MVP에서 4장이 가장 안전(UX/트래픽/스팸 균형)
  static const int maxImagesPerPost = 4;

  // 도배 방지(초반 필수 안전장치)
  static const int postCooldownSeconds = 45; // 연속 글쓰기 최소 간격
  static const int maxLinksPerPost = 1; // 링크는 1개까지만(초반 광고 방지)
  static const int duplicateWindowMinutes = 30; // 동일 내용 반복 작성 방지 윈도우
}
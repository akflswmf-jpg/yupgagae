class ModerationService {
  int cooldownSecondsForAuthor(String userId) {
    // MVP: 고정값. 추후 제재/등급/신고누적에 따라 가변 가능
    return 45;
  }

  void onReportPost({
    required String postId,
    required String reporterUserId,
    required String reason,
  }) {
    // MVP: 서버 없으면 로컬에서는 noop(추후 서버 연동)
  }

  void onReportComment({
    required String commentId,
    required String reporterUserId,
    required String reason,
  }) {
    // MVP: 서버 없으면 로컬에서는 noop(추후 서버 연동)
  }
}
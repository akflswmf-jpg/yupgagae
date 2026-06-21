import 'post.dart';
import 'comment.dart';
import 'post_page.dart';

enum PostSort { latest, hot, mostCommented }
enum PostSearchField { all, title, body }

enum AdminUserSanctionType {
  warned,
  suspend3d,
  suspend7d,
  permanentBanned,
}

extension AdminUserSanctionTypeX on AdminUserSanctionType {
  String get key {
    switch (this) {
      case AdminUserSanctionType.warned:
        return 'warned';
      case AdminUserSanctionType.suspend3d:
        return 'suspend_3d';
      case AdminUserSanctionType.suspend7d:
        return 'suspend_7d';
      case AdminUserSanctionType.permanentBanned:
        return 'permanent_banned';
    }
  }

  String get label {
    switch (this) {
      case AdminUserSanctionType.warned:
        return '경고';
      case AdminUserSanctionType.suspend3d:
        return '3일 정지';
      case AdminUserSanctionType.suspend7d:
        return '7일 정지';
      case AdminUserSanctionType.permanentBanned:
        return '영구정지';
    }
  }

  String get confirmTitle {
    switch (this) {
      case AdminUserSanctionType.warned:
        return '경고 처리';
      case AdminUserSanctionType.suspend3d:
        return '3일 정지';
      case AdminUserSanctionType.suspend7d:
        return '7일 정지';
      case AdminUserSanctionType.permanentBanned:
        return '영구정지';
    }
  }

  bool get isDestructive {
    switch (this) {
      case AdminUserSanctionType.warned:
        return false;
      case AdminUserSanctionType.suspend3d:
      case AdminUserSanctionType.suspend7d:
      case AdminUserSanctionType.permanentBanned:
        return true;
    }
  }
}

class ReportedCommentItem {
  final Post post;
  final Comment comment;

  const ReportedCommentItem({
    required this.post,
    required this.comment,
  });
}

abstract class PostRepository {
  Future<void> warmUp();

  Future<List<Post>> fetchHomeTopPosts({int limit = 100});

  Future<List<Post>> fetchPosts({
    PostSort sort = PostSort.latest,
    BoardType? boardType,
  });

  /// 관리자 전용 계약:
  /// 일반 피드에서 숨겨진 신고 임계치 게시글/관리자 숨김/관리자 제거 게시글도 포함해서 가져온다.
  Future<List<Post>> fetchReportedPosts();

  /// 관리자 전용 계약:
  /// 신고 접수된 댓글, 자동 블라인드된 댓글, 관리자 숨김 댓글, 관리자 제거 댓글을 가져온다.
  ///
  /// 일반 댓글 목록에서 가려진 댓글도 관리자 화면에서는 계속 보여야 한다.
  Future<List<ReportedCommentItem>> fetchReportedComments();

  Future<Post> getPostById(String postId);

  Future<Post> createPost({
    String? postId,
    required String title,
    required String body,
    required BoardType boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,

    /// 신규 기준:
    /// Firebase Storage download URL 목록.
    List<String>? imageUrls,

    /// 기존 Controller/UI 호환용.
    List<String>? imagePaths,
  });

  Future<Post> updatePost({
    required String postId,
    required String title,
    required String body,
    UsedPostType? usedType,

    /// 신규 기준:
    /// Firebase Storage download URL 목록.
    List<String>? imageUrls,

    /// 기존 Controller/UI 호환용.
    List<String>? imagePaths,
  });

  Future<Post> toggleLike({
    required String postId,
  });

  Future<Post> toggleSold({
    required String postId,
  });

  Future<void> incrementView(String postId);

  Future<PostPage> fetchLatestPage({
    String? cursor,
    int limit = 20,
    String? searchQuery,
    BoardType? boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    PostSearchField searchField = PostSearchField.all,
  });

  Future<PostPage> fetchHotPage({
    String? cursor,
    int limit = 20,
    BoardType? boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
  });

  Future<PostPage> fetchMostCommentedPage({
    String? cursor,
    int limit = 20,
    BoardType? boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
  });

  Future<bool> canDeletePost({
    required String postId,
  });

  Future<void> deletePost({
    required String postId,
  });

  Future<void> reportPost({
    required String postId,
    required String reason,
  });

  /// 관리자 전용:
  /// 관리자가 신고된 게시글을 직접 숨김 처리한다.
  ///
  /// 숨김 사유는 관리자가 직접 입력하지 않는다.
  /// 신고 사유 집계에서 가장 많이 접수된 대표 사유를 자동 저장한다.
  /// 대표 사유가 없으면 Post.defaultHiddenReason을 사용한다.
  Future<Post> hidePostByAdmin({
    required String postId,
  });

  /// 관리자 전용:
  /// 관리자가 직접 숨김 처리한 게시글 상태만 해제한다.
  ///
  /// 단, isReportThresholdReached == true 상태라면
  /// 관리자 숨김을 해제해도 일반 유저에게는 여전히 가려진다.
  Future<Post> unhidePostByAdmin({
    required String postId,
  });

  /// 관리자 전용:
  /// 신고 3회 이상으로 자동 블라인드된 게시글 상태만 해제한다.
  ///
  /// reportCount, reportedUserIds, reportReasons, reportReasonCounts는 유지한다.
  Future<Post> clearPostReportThresholdByAdmin({
    required String postId,
  });

  /// 관리자 전용:
  /// 명백한 위반/개인정보/분쟁 대응 필요 게시글을 제거 상태로 전환한다.
  ///
  /// 실제 Firestore 문서는 삭제하지 않는다.
  /// 일반 유저에게는 미노출되고, 관리자 검토/분쟁 대응용 데이터는 보존된다.
  Future<Post> removePostByAdmin({
    required String postId,
  });

  /// 관리자 전용:
  /// 유저에게 운영정책 경고/정지/영구정지를 부여한다.
  Future<void> sanctionUserByAdmin({
    required String userId,
    required AdminUserSanctionType sanctionType,
    required String reason,
  });

  /// 관리자 전용:
  /// 유저 제재를 해제한다.
  ///
  /// 초기 운영에서는 주로 Firebase Console 또는 추후 관리자 화면에서 사용한다.
  Future<void> clearUserSanctionByAdmin({
    required String userId,
    required String reason,
  });

  Future<List<Comment>> fetchComments(
    String postId, {
    String? cursor,
    int limit = 20,
  });

  Future<Comment> addComment({
    required String postId,
    required String text,
  });

  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String text,
  });

  Future<Comment> toggleCommentLike({
    required String postId,
    required String commentId,
  });

  Future<bool> canDeleteComment({
    required String postId,
    required String commentId,
  });

  Future<void> deleteComment({
    required String postId,
    required String commentId,
  });

  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reason,
  });

  /// 관리자 전용:
  /// 관리자가 신고된 댓글을 직접 숨김 처리한다.
  ///
  /// 숨김 사유는 관리자가 직접 입력하지 않는다.
  /// 신고 사유 집계에서 가장 많이 접수된 대표 사유를 자동 저장한다.
  /// 대표 사유가 없으면 Comment.defaultHiddenReason을 사용한다.
  Future<Comment> hideCommentByAdmin({
    required String postId,
    required String commentId,
  });

  /// 관리자 전용:
  /// 관리자가 직접 숨김 처리한 댓글 상태만 해제한다.
  ///
  /// 단, isReportThresholdReached == true 상태라면
  /// 관리자 숨김을 해제해도 일반 유저에게는 여전히 가려진다.
  Future<Comment> unhideCommentByAdmin({
    required String postId,
    required String commentId,
  });

  /// 관리자 전용:
  /// 신고 3회 이상으로 자동 블라인드된 댓글 상태만 해제한다.
  ///
  /// reportCount, reportedUserIds, reportReasons, reportReasonCounts는 유지한다.
  Future<Comment> clearCommentReportThresholdByAdmin({
    required String postId,
    required String commentId,
  });

  /// 관리자 전용:
  /// 명백한 위반/개인정보/분쟁 대응 필요 댓글을 제거 상태로 전환한다.
  ///
  /// 실제 Firestore 문서는 삭제하지 않는다.
  /// 일반 유저에게는 미노출되고, 관리자 검토/분쟁 대응용 데이터는 보존된다.
  Future<Comment> removeCommentByAdmin({
    required String postId,
    required String commentId,
  });

  Future<Comment> updateComment({
    required String postId,
    required String commentId,
    required String text,
  });

  Future<List<Post>> fetchMyPosts();

  Future<List<Comment>> fetchMyComments();
}

abstract class ModerationService {}
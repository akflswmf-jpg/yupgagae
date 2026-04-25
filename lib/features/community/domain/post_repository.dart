import 'post.dart';
import 'comment.dart';
import 'post_page.dart';

enum PostSort { latest, hot, mostCommented }
enum PostSearchField { all, title, body }

abstract class PostRepository {
  Future<void> warmUp();

  Future<List<Post>> fetchHomeTopPosts({int limit = 100});

  Future<List<Post>> fetchPosts({
    PostSort sort = PostSort.latest,
    BoardType? boardType,
  });

  Future<Post> getPostById(String postId);

  /// 서버형 계약:
  /// 작성자 id / 닉네임 / 인증 여부는 클라이언트가 넘기지 않는다.
  /// 서버 구현체에서는 Auth 토큰 + 사용자 프로필에서 결정한다.
  Future<Post> createPost({
    required String title,
    required String body,
    required BoardType boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    List<String>? imagePaths,
  });

  /// 서버형 계약:
  /// 수정 권한은 서버가 현재 로그인 유저 기준으로 판단한다.
  Future<Post> updatePost({
    required String postId,
    required String title,
    required String body,
    UsedPostType? usedType,
    List<String>? imagePaths,
  });

  /// 서버형 계약:
  /// 좋아요 누른 사람은 서버가 현재 로그인 유저 기준으로 판단한다.
  Future<Post> toggleLike({
    required String postId,
  });

  /// 서버형 계약:
  /// 판매완료 권한은 서버가 현재 로그인 유저 기준으로 판단한다.
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

  /// 서버형 계약:
  /// 삭제 가능 여부는 서버가 현재 로그인 유저 기준으로 판단한다.
  Future<bool> canDeletePost({
    required String postId,
  });

  Future<void> deletePost({
    required String postId,
  });

  /// 서버형 계약:
  /// 신고자는 서버가 현재 로그인 유저 기준으로 판단한다.
  Future<void> reportPost({
    required String postId,
    required String reason,
  });

  Future<List<Comment>> fetchComments(String postId);

  /// 서버형 계약:
  /// 댓글 작성자 정보는 서버가 현재 로그인 유저 프로필 기준으로 붙인다.
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

  Future<Comment> updateComment({
    required String postId,
    required String commentId,
    required String text,
  });

  /// 서버형 계약:
  /// 내 글/댓글은 현재 로그인 유저 기준이다.
  Future<List<Post>> fetchMyPosts();

  Future<List<Comment>> fetchMyComments();
}

abstract class ModerationService {}
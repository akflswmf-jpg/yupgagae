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

  Future<Post> createPost({
    required String authorId,
    required String authorLabel,
    required bool isOwnerVerified,
    required String title,
    required String body,
    required BoardType boardType,
    UsedPostType? usedType,
    String? industryId,
    String? locationLabel,
    List<String>? imagePaths,
  });

  Future<Post> updatePost({
    required String postId,
    required String userId,
    required String title,
    required String body,
    UsedPostType? usedType,
    List<String>? imagePaths,
  });

  Future<Post> toggleLike({required String postId, required String userId});

  Future<Post> toggleSold({
    required String postId,
    required String userId,
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

  Future<bool> canDeletePost({required String postId, required String userId});
  Future<void> deletePost({required String postId, required String userId});

  Future<void> reportPost({
    required String postId,
    required String reporterId,
    required String reason,
  });

  Future<List<Comment>> fetchComments(String postId);

  Future<Comment> addComment({
    required String postId,
    required String authorId,
    required String authorLabel,
    bool isOwnerVerified = false,
    String? industryId,
    String? locationLabel,
    required String text,
  });

  Future<Comment> addReply({
    required String postId,
    required String parentCommentId,
    required String authorId,
    required String authorLabel,
    bool isOwnerVerified = false,
    String? industryId,
    String? locationLabel,
    required String text,
  });

  Future<Comment> toggleCommentLike({
    required String postId,
    required String commentId,
    required String userId,
  });

  Future<bool> canDeleteComment({
    required String postId,
    required String commentId,
    required String userId,
  });

  Future<void> deleteComment({
    required String postId,
    required String commentId,
    required String userId,
  });

  Future<void> reportComment({
    required String postId,
    required String commentId,
    required String reporterId,
    required String reason,
  });

  Future<Comment> updateComment({
    required String postId,
    required String commentId,
    required String userId,
    required String text,
  });

  Future<List<Post>> fetchMyPosts(String userId);

  Future<List<Comment>> fetchMyComments(String userId);
}

abstract class ModerationService {}
import 'post.dart';

class PostPage {
  final List<Post> items;
  final String? nextCursor; // null이면 더 없음

  const PostPage({
    required this.items,
    required this.nextCursor,
  });
}
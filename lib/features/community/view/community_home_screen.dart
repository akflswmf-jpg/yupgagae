import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/view/open_post_detail.dart';

import '../controller/post_list_controller.dart';
import '../domain/post.dart';
import '../domain/post_repository.dart';

class CommunityHomeScreen extends StatefulWidget {
  const CommunityHomeScreen({super.key});

  @override
  State<CommunityHomeScreen> createState() => _CommunityHomeScreenState();
}

class _CommunityHomeScreenState extends State<CommunityHomeScreen> {
  late final PostListController c;

  @override
  void initState() {
    super.initState();
    c = Get.find<PostListController>();
    c.load(newSort: PostSort.latest);
  }

  Future<void> _openPostDetail(Post post) async {
    final result = await openPostDetail<bool>(post.id);

    if (result == true) {
      await c.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티'),
        actions: [
          PopupMenuButton<PostSort>(
            onSelected: (s) => c.load(newSort: s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: PostSort.latest, child: Text('최신')),
              PopupMenuItem(value: PostSort.hot, child: Text('인기')),
              PopupMenuItem(value: PostSort.mostCommented, child: Text('댓글많은순')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final repo = Get.find<PostRepository>();
          await repo.createPost(
            authorId: 'demoUser',
            authorLabel: '익명',
            isOwnerVerified: false,
            title: '새 글 ${DateTime.now().toIso8601String().substring(11, 19)}',
            body: '테스트 글입니다.',
            boardType: BoardType.free,
          );
          await c.load();
        },
        child: const Icon(Icons.add),
      ),
      body: Obx(() {
        if (c.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final list = c.posts;
        if (list.isEmpty) {
          return const Center(
            child: Text('글 없음'),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final p = list[i];
            return _PostCard(
              post: p,
              onTap: () => _openPostDetail(p),
            );
          },
        );
      }),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;

  const _PostCard({
    required this.post,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              post.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('👍 ${post.likeCount}'),
                const SizedBox(width: 10),
                Text('💬 ${post.commentCount}'),
                const SizedBox(width: 10),
                Text('👀 ${post.viewCount}'),
                const SizedBox(width: 10),
                Text('🚨 ${post.reportCount}'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
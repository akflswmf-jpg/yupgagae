import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/routes/app_routes.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';

class IndustryBoardScreen extends StatefulWidget {
  final String industryId;
  final String title;

  const IndustryBoardScreen({
    super.key,
    required this.industryId,
    required this.title,
  });

  @override
  State<IndustryBoardScreen> createState() => _IndustryBoardScreenState();
}

class _IndustryBoardScreenState extends State<IndustryBoardScreen> {
  late final PostListController c;

  @override
  void initState() {
    super.initState();
    c = Get.find<PostListController>();
    // ✅ 여기서 load() 호출 금지: 단일 진실은 CommunityShell
  }

  Future<void> _goWrite() async {
    try {
      final result = await Get.toNamed(AppRoutes.writePost);
      if (result == true) {
        await c.refreshList(); // 디바운스
      }
    } catch (e) {
      Get.snackbar('이동 실패', '글쓰기 화면 이동 중 오류: $e');
    }
  }

  Future<void> _goDetail(String postId) async {
    try {
      // ✅ postDetail은 쿼리 파라미터로 통일
      await Get.toNamed('${AppRoutes.postDetail}?postId=$postId');
      await c.refreshList(); // 디바운스
    } catch (e) {
      Get.snackbar('이동 실패', '상세 화면 이동 중 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _goWrite,
          ),
        ],
      ),
      body: Obx(() {
        // ✅ 업종 게시판: 업종 필터 적용
        final List<Post> posts = c.posts
            .where((p) => p.industryId == widget.industryId)
            .toList();

        if (c.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (posts.isEmpty) {
          return const Center(child: Text('게시글이 없습니다.'));
        }

        return RefreshIndicator(
          onRefresh: () => c.refreshList(),
          child: ListView.separated(
            itemCount: posts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final p = posts[index];
              return ListTile(
                title: Text(p.title),
                subtitle: Text(
                  p.body, // ✅ content 대신 body로 통일(모델 불일치 앵꼬 방지)
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _goDetail(p.id),
              );
            },
          ),
        );
      }),
      floatingActionButton: FloatingActionButton(
        onPressed: _goWrite,
        child: const Icon(Icons.add),
      ),
    );
  }
}
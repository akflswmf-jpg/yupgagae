import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/routes/app_routes.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';

import 'package:yupgagae/core/ui/empty_view.dart';
import 'package:yupgagae/core/ui/post_card.dart';
import 'package:yupgagae/core/ui/app_badge.dart';

class MyIndustryScreen extends StatefulWidget {
  final String myIndustryId;
  const MyIndustryScreen({super.key, required this.myIndustryId});

  @override
  State<MyIndustryScreen> createState() => _MyIndustryScreenState();
}

class _MyIndustryScreenState extends State<MyIndustryScreen>
    with AutomaticKeepAliveClientMixin {
  late final PostListController listC;

  @override
  void initState() {
    super.initState();
    listC = Get.find<PostListController>();
    // ✅ 여기서 load() 절대 호출하지 말 것
    // CommunityShell에서 1회 로드가 단일 진실
  }

  @override
  bool get wantKeepAlive => true;

  Future<void> _goWrite() async {
    try {
      final result = await Get.toNamed(AppRoutes.writePost);
      if (result == true) {
        await listC.refreshList(); // 디바운스
      }
    } catch (e) {
      Get.snackbar('이동 실패', '글쓰기 화면 이동 중 오류: $e');
    }
  }

  Future<void> _goDetail(String postId) async {
    try {
      // ✅ postDetail은 쿼리 파라미터로 통일: /post-detail?postId=xxx
      await Get.toNamed('${AppRoutes.postDetail}?postId=$postId');

      // ✅ 복귀 시 동기화(디바운스)
      await listC.refreshList();
    } catch (e) {
      Get.snackbar('이동 실패', '상세 화면 이동 중 오류: $e');
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${dt.month}/${dt.day}';
  }

  List<Post> _myIndustryPosts(List<Post> posts) {
    return posts.where((p) => p.industryId == widget.myIndustryId).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final industryName = IndustryCatalog.nameOf(widget.myIndustryId) ?? '내 업종';

    return Obx(() {
      if (listC.isLoading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final filtered = _myIndustryPosts(listC.posts);

      if (filtered.isEmpty) {
        return EmptyView(
          icon: Icons.storefront_outlined,
          title: '$industryName 글이 아직 없네요',
          subtitle: '첫 이야기를 올려보세요 🙂',
          actionLabel: '얘기 올리기',
          onAction: _goWrite,
        );
      }

      return RefreshIndicator(
        onRefresh: () => listC.refreshList(),
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const SizedBox(height: 6),
          itemBuilder: (_, i) {
            final p = filtered[i];

            const badge = UserAuthBadge.neighbor;
            final liked = p.likedUserIds.contains(listC.currentUserId);

            return PostCard(
              title: p.title,
              authBadge: badge,
              industryLabel: null,
              locationLabel: null,
              timeLabel: _timeAgo(p.createdAt),
              commentCount: p.commentCount,
              likeCount: p.likeCount,
              authorLabel: '이웃',
              viewCount: p.viewCount,
              imageCount: p.imagePaths.length,
              liked: liked,
              onLike: () async {
                // ✅ 목록/카드 좋아요는 무조건 이 메서드
                await listC.toggleLikeFromList(p.id);
              },
              onTap: () => _goDetail(p.id),
            );
          },
        ),
      );
    });
  }
}
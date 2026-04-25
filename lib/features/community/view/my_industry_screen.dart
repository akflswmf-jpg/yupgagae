import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/core/ui/app_badge.dart';
import 'package:yupgagae/core/ui/empty_view.dart';
import 'package:yupgagae/core/ui/post_card.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/industry_catalog.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/routes/app_routes.dart';

class MyIndustryScreen extends StatefulWidget {
  final String myIndustryId;

  const MyIndustryScreen({
    super.key,
    required this.myIndustryId,
  });

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

    if (listC.posts.isEmpty && !listC.isLoading.value) {
      Future.microtask(() async {
        await listC.initLoad();
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  String get _currentUserId {
    if (!Get.isRegistered<AnonSessionService>()) return '';
    return Get.find<AnonSessionService>().anonId;
  }

  Future<void> _goWrite() async {
    try {
      final result = await Get.toNamed(
        AppRoutes.writePost,
        arguments: {
          'industryId': widget.myIndustryId,
          'boardType': BoardType.free.key,
        },
      );

      if (result == true) {
        await listC.initLoad();
      }
    } catch (e) {
      Get.snackbar('이동 실패', '글쓰기 화면 이동 중 오류: $e');
    }
  }

  Future<void> _goDetail(String postId) async {
    try {
      await Get.toNamed(
        AppRoutes.postDetail,
        arguments: {
          'postId': postId,
        },
      );

      await listC.initLoad();
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
    return posts
        .where((p) => p.industryId == widget.myIndustryId)
        .toList(growable: false);
  }

  UserAuthBadge _authBadgeOf(Post post) {
    if (post.isOwnerVerified) return UserAuthBadge.owner;
    return UserAuthBadge.neighbor;
  }

  String? _industryLabelOf(String? industryId) {
    final id = industryId?.trim();
    if (id == null || id.isEmpty) return null;

    for (final item in IndustryCatalog.ordered()) {
      if (item.id == id) return item.name;
    }

    return id;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 업종 게시판'),
        actions: [
          IconButton(
            tooltip: '글쓰기',
            onPressed: _goWrite,
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Obx(() {
        final posts = _myIndustryPosts(listC.posts);

        if (listC.isLoading.value && posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (posts.isEmpty) {
          return EmptyView(
            icon: Icons.storefront_outlined,
            title: '아직 내 업종 게시글이 없어요.',
            subtitle: '같은 업종 사장님들과 먼저 이야기를 시작해보세요.',
            actionLabel: '글쓰기',
            onAction: _goWrite,
          );
        }

        return RefreshIndicator(
          onRefresh: listC.initLoad,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = posts[index];
              final liked = p.likedUserIds.contains(_currentUserId);

              return PostCard(
                title: p.title,
                authorLabel: p.authorLabel,
                authBadge: _authBadgeOf(p),
                locationLabel: p.locationLabel,
                industryLabel: _industryLabelOf(p.industryId),
                timeLabel: _timeAgo(p.createdAt),
                commentCount: p.commentCount,
                likeCount: p.likeCount,
                liked: liked,
                viewCount: p.viewCount,
                imageCount: p.imagePaths.length,
                imagePaths: p.imagePaths,
                onTap: () => _goDetail(p.id),
                onLike: () async {
                  await listC.toggleLikeOnList(p);
                },
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
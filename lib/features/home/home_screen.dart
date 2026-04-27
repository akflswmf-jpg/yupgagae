import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/home_feed_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/open_post_detail.dart';
import 'package:yupgagae/features/community/view/widgets/post_row.dart';
import 'package:yupgagae/features/home/widgets/home_top_bars.dart';

enum HomeTab { hot, latest, used, owner }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color _kYupgagaePrimary = Color(0xFFA56E5F);
  static const Color _kYupgagaePrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTabTrackColor = Color(0xFFF8F6F5);
  static const Color _kTabTrackBorder = Color(0xFFEFE8E4);

  late final HomeFeedController controller;
  late final ScrollController _scrollController;

  final Rx<HomeTab> tab = HomeTab.hot.obs;

  @override
  void initState() {
    super.initState();
    controller = Get.find<HomeFeedController>();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 320) return;

    switch (tab.value) {
      case HomeTab.hot:
      case HomeTab.latest:
        controller.loadMoreLatest();
        break;
      case HomeTab.used:
        controller.loadMoreUsedLatest();
        break;
      case HomeTab.owner:
        controller.loadMoreOwnerLatest();
        break;
    }
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  Future<void> _goToPost(String postId) async {
    final result = await openPostDetail<bool>(postId);
    if (result == true) {
      await controller.loadAll();
    }
  }

  Widget _buildPosts(List<Post> posts) {
    if (posts.isEmpty) {
      return const _EmptyBox(message: '아직 글이 없습니다.');
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PostRow(
              post: post,
              timeLabel: _timeLabel(post.createdAt),
              onTap: () => _goToPost(post.id),
              onLike: () => controller.toggleLike(post),
              liked: post.likedUserIds.contains(controller.currentUserId),
            ),
            if (i != posts.length - 1)
              const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFF1F3F5),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingMore({
    required bool show,
  }) {
    if (!show) return const SizedBox.shrink();

    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      ),
    );
  }

  Widget _longDivider(String text) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                letterSpacing: -0.1,
              ),
            ),
          ),
          const Expanded(
            child: Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE5E7EB),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMixedFeed() {
    final hot = controller.hot;
    final latest = controller.latest;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPosts(hot),
        if (hot.isNotEmpty) _longDivider('최신글'),
        _buildPosts(latest),
        _buildLoadingMore(show: controller.isLoadingMore.value),
      ],
    );
  }

  Widget _buildLatestOnlyFeed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPosts(controller.latest),
        _buildLoadingMore(show: controller.isLoadingMore.value),
      ],
    );
  }

  Widget _buildUsedFeed() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPosts(controller.usedLatest),
        _buildLoadingMore(show: controller.isLoadingMoreUsed.value),
      ],
    );
  }

  Widget _buildOwnerFeed() {
    if (!controller.isOwnerVerified.value) {
      return const _LockedOwnerNotice();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildPosts(controller.ownerHot),
        if (controller.ownerHot.isNotEmpty) _longDivider('최신글'),
        _buildPosts(controller.ownerLatest),
        _buildLoadingMore(show: controller.isLoadingMoreOwner.value),
      ],
    );
  }

  Widget _buildTabFeed() {
    switch (tab.value) {
      case HomeTab.hot:
        return _buildMixedFeed();
      case HomeTab.latest:
        return _buildLatestOnlyFeed();
      case HomeTab.used:
        return _buildUsedFeed();
      case HomeTab.owner:
        return _buildOwnerFeed();
    }
  }

  Widget _buildTabs() {
    return Obx(() {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        child: Container(
          height: 50,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: _kTabTrackColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kTabTrackBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: _MinimalTab(
                  label: '인기글',
                  selected: tab.value == HomeTab.hot,
                  onTap: () => tab.value = HomeTab.hot,
                  selectedColor: _kYupgagaePrimary,
                  selectedSoftColor: _kYupgagaePrimarySoft,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _MinimalTab(
                  label: '최신글',
                  selected: tab.value == HomeTab.latest,
                  onTap: () => tab.value = HomeTab.latest,
                  selectedColor: _kYupgagaePrimary,
                  selectedSoftColor: _kYupgagaePrimarySoft,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _MinimalTab(
                  label: '거래글',
                  selected: tab.value == HomeTab.used,
                  onTap: () => tab.value = HomeTab.used,
                  selectedColor: _kYupgagaePrimary,
                  selectedSoftColor: _kYupgagaePrimarySoft,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _MinimalTab(
                  label: '사장님',
                  selected: tab.value == HomeTab.owner,
                  onTap: () => tab.value = HomeTab.owner,
                  selectedColor: _kYupgagaePrimary,
                  selectedSoftColor: _kYupgagaePrimarySoft,
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildTopBars() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: HomeTopNoticeBar(
        text: '새 기능과 개선사항은 곧 반영됩니다.',
      ),
    );
  }

  Widget _buildFeedSection() {
    return Obx(() {
      final hotPosts = controller.hot;
      final latestPosts = controller.latest;
      final usedLatestPosts = controller.usedLatest;
      final ownerHotPosts = controller.ownerHot;
      final ownerLatestPosts = controller.ownerLatest;

      final showTopLoading = controller.isLoadingTop.value &&
          hotPosts.isEmpty &&
          ownerHotPosts.isEmpty;
      final showLatestLoading =
          controller.isLoadingLatest.value && latestPosts.isEmpty;
      final showUsedLatestLoading =
          controller.isLoadingUsedLatest.value && usedLatestPosts.isEmpty;
      final showOwnerLatestLoading =
          controller.isLoadingOwnerLatest.value && ownerLatestPosts.isEmpty;

      final showError = controller.error.value != null &&
          hotPosts.isEmpty &&
          latestPosts.isEmpty &&
          usedLatestPosts.isEmpty &&
          ownerHotPosts.isEmpty &&
          ownerLatestPosts.isEmpty;

      if (showError) {
        return const Padding(
          padding: EdgeInsets.only(top: 12),
          child: _MessageBox(
            icon: Icons.error_outline_rounded,
            message: '홈 글을 불러오지 못했습니다. 잠시 후 다시 시도해주세요.',
          ),
        );
      }

      if (tab.value == HomeTab.hot && showTopLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (tab.value == HomeTab.latest && showLatestLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (tab.value == HomeTab.used && showUsedLatestLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      if (tab.value == HomeTab.owner &&
          controller.isOwnerVerified.value &&
          showTopLoading &&
          showOwnerLatestLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      return _buildTabFeed();
    });
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: controller.loadAll,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: ClampingScrollPhysics(),
        ),
        children: [
          _buildTopBars(),
          _buildTabs(),
          _buildFeedSection(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        toolbarHeight: 0,
        elevation: 0,
        backgroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }
}

class _MinimalTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color selectedColor;
  final Color selectedSoftColor;

  const _MinimalTab({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.selectedColor,
    required this.selectedSoftColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? selectedColor : const Color(0xFF7D7772);
    final backgroundColor = selected ? selectedSoftColor : Colors.transparent;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
              color: textColor,
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyBox extends StatelessWidget {
  final String message;

  const _EmptyBox({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }
}

class _MessageBox extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageBox({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: const Color(0xFF9CA3AF),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LockedOwnerNotice extends StatelessWidget {
  const _LockedOwnerNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Icon(
              Icons.lock_outline_rounded,
              size: 16,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              '사업자 인증 사용자만 열람 가능합니다.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
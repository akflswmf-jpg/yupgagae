import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/owner_board_controller.dart';
import 'package:yupgagae/features/community/controller/post_list_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/view/free_board_feed_screen.dart';
import 'package:yupgagae/features/community/view/owner_board_screen.dart';

const Color kCommunityAccent = Color(0xFFA56E5F);

class CommunityShell extends StatefulWidget {
  const CommunityShell({super.key});

  @override
  State<CommunityShell> createState() => _CommunityShellState();
}

class _CommunityShellState extends State<CommunityShell>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  OwnerBoardController? _ownerBoardController;
  PostListController? _freeBoardController;
  PostListController? _usedBoardController;

  Timer? _prewarmTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _freeBoardController = Get.find<PostListController>();

    if (Get.isRegistered<PostListController>(tag: 'used_board')) {
      _usedBoardController = Get.find<PostListController>(tag: 'used_board');
    } else {
      _usedBoardController = Get.put<PostListController>(
        PostListController(
          repo: Get.find<PostRepository>(),
          auth: Get.find<AuthSessionService>(),
          boardType: BoardType.used,
        ),
        tag: 'used_board',
      );
    }

    if (Get.isRegistered<OwnerBoardController>()) {
      _ownerBoardController = Get.find<OwnerBoardController>();

      _prewarmTimer = Timer(const Duration(milliseconds: 420), () {
        if (!mounted) return;
        _ownerBoardController?.prewarm();
      });
    }
  }

  @override
  void dispose() {
    _prewarmTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              alignment: Alignment.centerLeft,
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                border: Border(
                  bottom: BorderSide(
                    color: theme.dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: theme.colorScheme.onSurface,
                unselectedLabelColor:
                    theme.colorScheme.onSurface.withOpacity(0.55),
                indicatorColor: kCommunityAccent,
                indicatorWeight: 2,
                dividerColor: Colors.transparent,
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                labelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                tabs: const [
                  Tab(text: '자유게시판'),
                  Tab(text: '사장님게시판'),
                  Tab(text: '거래게시판'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const BouncingScrollPhysics(),
                children: [
                  _KeepAliveTab(
                    child: FreeBoardFeedScreen(
                      controller: _freeBoardController,
                    ),
                  ),
                  const _KeepAliveTab(
                    child: OwnerBoardScreen(),
                  ),
                  _KeepAliveTab(
                    child: FreeBoardFeedScreen(
                      controller: _usedBoardController,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepAliveTab extends StatefulWidget {
  final Widget child;

  const _KeepAliveTab({
    required this.child,
  });

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return RepaintBoundary(
      child: widget.child,
    );
  }
}
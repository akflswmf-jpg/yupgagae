import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_routes.dart';

// ❌ 스플래시 제거

// 루트
import 'package:yupgagae/root_shell.dart';

// 홈
import 'package:yupgagae/features/home/home_screen.dart';
import 'package:yupgagae/features/home/home_binding.dart';

// 커뮤니티 검색
import 'package:yupgagae/features/community/view/community_search_screen.dart';
import 'package:yupgagae/features/community/bindings/community_search_binding.dart';

// 글쓰기
import 'package:yupgagae/features/community/view/write_post_screen.dart';
import 'package:yupgagae/features/community/bindings/write_post_binding.dart';

// 게시글 상세
import 'package:yupgagae/features/community/view/post_detail_screen.dart';
import 'package:yupgagae/features/community/bindings/post_detail_binding.dart';

// 답글 스레드
import 'package:yupgagae/features/community/view/community_thread_screen.dart';
import 'package:yupgagae/features/community/bindings/comment_thread_binding.dart';

class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.root,
      page: () => const RootShell(),
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
    ),
    GetPage(
      name: AppRoutes.communitySearch,
      page: () => const CommunitySearchScreen(),
      binding: CommunitySearchBinding(),
    ),
    GetPage(
      name: AppRoutes.writePost,
      page: () => const WritePostScreen(),
      binding: WritePostBinding(),
    ),
    GetPage(
      name: AppRoutes.postDetail,
      page: () {
        final args = Get.arguments as Map?;
        final postId = (args?['postId'] ?? '').toString().trim();

        if (postId.isEmpty) {
          return const Scaffold(
            body: Center(
              child: Text('postId required'),
            ),
          );
        }

        return PostDetailScreen(postId: postId);
      },
      binding: PostDetailBinding(),
    ),
    GetPage(
      name: AppRoutes.commentThread,
      page: () => const CommunityThreadScreen(),
      binding: CommentThreadBinding(),
    ),
  ];
}
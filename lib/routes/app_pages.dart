import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app_routes.dart';

import 'package:yupgagae/core/auth/auth_action_guard.dart';
import 'package:yupgagae/core/auth/auth_binding.dart';
import 'package:yupgagae/core/navigation/route_input_resolver.dart';
import 'package:yupgagae/core/policy/app_policy_documents.dart';

// 스플래시
import 'package:yupgagae/features/splash/view/splash_screen.dart';

// 루트
import 'package:yupgagae/root_shell.dart';

// 인증
import 'package:yupgagae/features/auth/view/login_screen.dart';
import 'package:yupgagae/features/auth/view/policy_document_screen.dart';
import 'package:yupgagae/features/auth/view/policy_list_screen.dart';
import 'package:yupgagae/features/auth/view/profile_setup_screen.dart';
import 'package:yupgagae/features/auth/view/verification_screens.dart';
import 'package:yupgagae/features/auth/bindings/profile_setup_binding.dart';

// 홈
import 'package:yupgagae/features/home/home_screen.dart';
import 'package:yupgagae/features/home/home_binding.dart';

// 하루결
import 'package:yupgagae/features/harugyeol/bindings/harugyeol_binding.dart';
import 'package:yupgagae/features/harugyeol/view/harugyeol_screen.dart';

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

// 관리자
import 'package:yupgagae/features/admin/view/admin_menu_screen.dart';

class AppPages {
  static final pages = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AppRoutes.root,
      page: () => const RootShell(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AppRoutes.home,
      page: () => const HomeScreen(),
      binding: HomeBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AppRoutes.harugyeol,
      page: () => const HarugyeolScreen(),
      binding: HarugyeolBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
      binding: AuthBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AppRoutes.profileSetup,
      page: () => const ProfileSetupScreen(),
      binding: ProfileSetupBinding(),
      transition: Transition.noTransition,
    ),
    GetPage(
      name: AppRoutes.policyList,
      page: () => const PolicyListScreen(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.policyDocument,
      page: () {
        final args = Get.arguments;

        if (args is AppPolicyDocument) {
          return PolicyDocumentScreen(document: args);
        }

        if (args is AppPolicyDocumentType) {
          return PolicyDocumentScreen(
            document: AppPolicyDocuments.byType(args),
          );
        }

        return const Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Text('policy document required'),
          ),
        );
      },
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.businessVerification,
      page: () => const BusinessVerificationScreen(),
      binding: AuthBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.adminMenu,
      page: () => const AdminMenuScreen(),
      binding: AuthBinding(),
      transition: Transition.rightToLeft,
    ),
    GetPage(
      name: AppRoutes.communitySearch,
      page: () => const CommunitySearchScreen(),
      binding: CommunitySearchBinding(),
    ),
    GetPage(
      name: AppRoutes.writePost,
      page: () => const AuthRequiredRouteGate(
        title: '로그인이 필요한 기능입니다',
        message: '로그인 후 글쓰기를 이용할 수 있어요.',
        child: WritePostScreen(),
      ),
      binding: WritePostBinding(),
    ),
    GetPage(
      name: AppRoutes.postDetail,
      page: () {
        final postId = RouteInputResolver.string('postId');

        if (postId == null || postId.trim().isEmpty) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: Text('postId required'),
            ),
          );
        }

        return PostDetailScreen(postId: postId.trim());
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
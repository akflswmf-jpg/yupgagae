import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_session_service.dart';
import 'package:yupgagae/features/community/controller/community_search_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/service/search_history_service.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';

class CommunitySearchBinding extends Bindings {
  @override
  void dependencies() {
    _requireCoreDependencies();
    _bindSearchHistoryService();

    final boardType = boardTypeFromKey(Get.parameters['boardType']);

    Get.lazyPut<CommunitySearchController>(
      () => CommunitySearchController(
        repo: Get.find<PostRepository>(),
        auth: Get.find<AuthSessionService>(),
        historyService: Get.find<SearchHistoryService>(),
        storeProfileRepo: Get.find<StoreProfileRepository>(),
        boardType: boardType,
      ),
    );
  }

  void _requireCoreDependencies() {
    if (!Get.isRegistered<AuthSessionService>()) {
      throw Exception(
        'AuthSessionService must be registered by RootBinding before CommunitySearchBinding.',
      );
    }

    if (!Get.isRegistered<PostRepository>()) {
      throw Exception(
        'PostRepository must be registered by RootBinding before CommunitySearchBinding.',
      );
    }

    if (!Get.isRegistered<StoreProfileRepository>()) {
      throw Exception(
        'StoreProfileRepository must be registered by RootBinding before CommunitySearchBinding.',
      );
    }
  }

  void _bindSearchHistoryService() {
    if (!Get.isRegistered<SearchHistoryService>()) {
      Get.put<SearchHistoryService>(
        SearchHistoryService(),
        permanent: true,
      );
    }
  }
}
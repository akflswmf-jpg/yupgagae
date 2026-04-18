import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/community/controller/community_search_controller.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/service/search_history_service.dart';

class CommunitySearchBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<SearchHistoryService>()) {
      Get.put<SearchHistoryService>(
        SearchHistoryService(),
        permanent: true,
      );
    }

    final boardType = boardTypeFromKey(Get.parameters['boardType']);

    Get.lazyPut<CommunitySearchController>(
      () => CommunitySearchController(
        repo: Get.find<PostRepository>(),
        session: Get.find<AnonSessionService>(),
        historyService: Get.find<SearchHistoryService>(),
        boardType: boardType,
      ),
    );
  }
}
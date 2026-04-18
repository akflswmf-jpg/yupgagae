import 'package:get/get.dart';

import 'package:yupgagae/core/service/anon_session_service.dart';
import 'package:yupgagae/features/my_store/data/in_memory_store_profile_repository.dart';
import 'package:yupgagae/features/my_store/domain/store_profile_repository.dart';
import 'package:yupgagae/features/revenue/controller/revenue_controller.dart';
import 'package:yupgagae/features/revenue/data/in_memory_revenue_repository.dart';
import 'package:yupgagae/features/revenue/domain/revenue_repository.dart';

class RevenueBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<StoreProfileRepository>()) {
      Get.lazyPut<StoreProfileRepository>(
        () => InMemoryStoreProfileRepository(
          session: Get.find<AnonSessionService>(),
        ),
        fenix: true,
      );
    }

    if (!Get.isRegistered<RevenueRepository>()) {
      Get.lazyPut<RevenueRepository>(
        () => InMemoryRevenueRepository(),
        fenix: true,
      );
    }

    if (!Get.isRegistered<RevenueController>()) {
      Get.lazyPut<RevenueController>(
        () => RevenueController(
          repo: Get.find<RevenueRepository>(),
          storeProfileRepo: Get.find<StoreProfileRepository>(),
        ),
        fenix: true,
      );
    }
  }
}
import 'package:get/get.dart';
import 'package:yupgagae/app/controllers/account_book_controller.dart';

class AccountBookBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AccountBookController>(() => AccountBookController());
  }
}
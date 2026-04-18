import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/root_binding.dart';
import 'core/service/anon_session_service.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final anon = await AnonSessionService.load();
  Get.put<AnonSessionService>(anon, permanent: true);

  runApp(const YeopgaGaeApp());
}

class YeopgaGaeApp extends StatelessWidget {
  const YeopgaGaeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: '옆가게',
      theme: buildAppTheme(),
      initialBinding: RootBinding(),
      initialRoute: AppRoutes.root,
      getPages: AppPages.pages,
    );
  }
}
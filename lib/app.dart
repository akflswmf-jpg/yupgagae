import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'app/bindings/root_binding.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

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
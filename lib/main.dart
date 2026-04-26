import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/bindings/root_binding.dart';
import 'core/service/anon_session_service.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_messenger.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 앱 첫 실행/첫 조작 때 튀는 비용을 줄이기 위한 최소 선예열.
  // SharedPreferences, 앱 문서 디렉터리 접근은 첫 호출 때 비용이 생길 수 있다.
  await Future.wait<void>([
    SharedPreferences.getInstance(),
    getApplicationDocumentsDirectory(),
  ]);

  // 익명 세션은 Repository/Controller들이 의존하므로 runApp 전에 반드시 등록한다.
  final anon = await AnonSessionService.load();
  Get.put<AnonSessionService>(anon, permanent: true);

  runApp(const YeopgaGaeApp());
}

class YeopgaGaeApp extends StatelessWidget {
  const YeopgaGaeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      scaffoldMessengerKey: AppMessenger.messengerKey,
      debugShowCheckedModeBanner: false,
      title: '옆가게',
      theme: buildAppTheme(),
      locale: const Locale('ko', 'KR'),
      fallbackLocale: const Locale('ko', 'KR'),
      supportedLocales: const [
        Locale('ko', 'KR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialBinding: RootBinding(),
      initialRoute: AppRoutes.root,
      getPages: AppPages.pages,
    );
  }
}
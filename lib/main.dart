import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/bindings/root_binding.dart';
import 'core/service/anon_session_service.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final anon = await AnonSessionService.load();
  Get.put<AnonSessionService>(anon, permanent: true);

  unawaited(_warmUpPlatformBasics());

  runApp(const YeopgaGaeApp());
}

Future<void> _warmUpPlatformBasics() async {
  try {
    await SharedPreferences.getInstance();
    await getApplicationDocumentsDirectory();

    final encoded = jsonEncode({
      'warmup': true,
      'at': DateTime.now().millisecondsSinceEpoch,
    });

    jsonDecode(encoded);
  } catch (_) {
    // 앱 시작 워밍업은 실패해도 실제 기능 흐름을 막지 않는다.
  }
}

class YeopgaGaeApp extends StatelessWidget {
  const YeopgaGaeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
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
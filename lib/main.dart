import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:get/get.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

import 'app/bindings/root_binding.dart';
import 'core/service/anon_session_service.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/app_messenger.dart';
import 'firebase_options.dart';
import 'routes/app_pages.dart';
import 'routes/app_routes.dart';

const String _kKakaoNativeAppKey = '1051aa4584be49ba464389eeaa5ac9c6';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 백그라운드 수신에서는 UI 이동을 하지 않는다.
  // 알림 클릭 이동은 앱이 열린 뒤 PushNotificationService에서 처리한다.
}

Future<void> main() async {
  final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // A안:
  // Flutter SplashScreen을 따로 만들지 않는다.
  // 네이티브 스플래시 하나만 유지하다가
  // RootShell이 홈 초기 데이터 준비까지 확인한 뒤 제거한다.
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Kakao SDK는 앱 실행 초기에 1회 초기화한다.
  // Kakao 로그인은 Firebase 기본 Provider가 아니므로,
  // 이번 단계에서는 accessToken 확보까지만 담당하고
  // 다음 단계에서 Cloud Function → Firebase Custom Token 구조로 연결한다.
  KakaoSdk.init(
    nativeAppKey: _kKakaoNativeAppKey,
  );

  // Firebase는 Auth/Firestore/Functions 등 서버 계층의 기준점이므로
  // 앱 실행 전에 반드시 초기화한다.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 익명 세션은 기존 Repository/Controller들이 의존하므로 runApp 전에 반드시 등록한다.
  // SharedPreferences/path_provider 별도 선예열은 첫 화면 진입 전 블로킹을 줄이기 위해 제거한다.
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
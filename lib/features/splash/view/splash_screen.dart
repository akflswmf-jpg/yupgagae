import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';

import 'package:yupgagae/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color _backgroundColor = Colors.white;

  // native splash와 동일한 이미지를 사용한다.
  // pubspec.yaml assets에 이미 등록된 assets/icon/icon_foreground.png 기준.
  static const String _splashAsset = 'assets/icon/icon_foreground.png';

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    unawaited(_goRootAfterStableFrame());
  }

  Future<void> _goRootAfterStableFrame() async {
    // Flutter SplashScreen이 최소 1프레임 이상 확실히 그려진 뒤 RootShell로 넘긴다.
    // 너무 빨리 넘기면 native splash 제거 직후 RootShell 준비 프레임과 겹쳐 깜빡임이 생길 수 있다.
    await SchedulerBinding.instance.endOfFrame;

    // 네이티브 스플래시와 Flutter 스플래시 전환을 눈에 안 띄게 하기 위한 짧은 완충.
    // 길게 잡으면 앱이 느려 보이고, 너무 짧으면 RootShell 첫 빌드와 겹칠 수 있다.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (!mounted || _navigated) return;
    _navigated = true;

    Get.offAllNamed(AppRoutes.root);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _backgroundColor,
      body: ColoredBox(
        color: _backgroundColor,
        child: Center(
          child: Image(
            image: AssetImage(_splashAsset),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
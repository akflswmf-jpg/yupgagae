import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color kColor = Color(0xFFA56E5F);

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.delayed(const Duration(milliseconds: 650));

    if (!mounted) return;
    Get.offAllNamed(AppRoutes.root);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColor,
      body: Center(
        child: Image.asset(
          'assets/images/app_icon.png',
          width: 180,
          height: 180,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
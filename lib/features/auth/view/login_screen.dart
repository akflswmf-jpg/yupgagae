import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);
  static const Color _kKakaoText = Color(0xFF191919);

  late final AuthController controller;

  bool get _canUseAppleLogin {
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  void initState() {
    super.initState();
    controller = Get.find<AuthController>();
  }

  Future<void> _handleGoogleLogin() async {
    await controller.signInWithGoogle(
      forceAccountSelection: true,
    );
  }

  Future<void> _handleAppleLogin() async {
    if (!_canUseAppleLogin) return;
    await controller.signInWithApple();
  }

  Future<void> _handleKakaoLogin() async {
    await controller.signInWithKakao();
  }

  Future<void> _handleLogout() async {
    await controller.signOut();
  }

  void _goNextAfterLogin() {
    final user = controller.currentUser.value;

    if (user == null) {
      return;
    }

    if (user.needsProfileSetup) {
      Get.offAllNamed(AppRoutes.profileSetup);
      return;
    }

    Get.offAllNamed(AppRoutes.root);
  }

  Widget _buildHeader() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '옆가게 시작하기',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.8,
            color: _kTextStrong,
            height: 1.15,
          ),
        ),
        SizedBox(height: 10),
        Text(
          '동네 사장님들과 가볍게 이야기하고\n오늘의 장사 분위기도 함께 확인해보세요.',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w600,
            color: _kTextNormal,
            height: 1.45,
            letterSpacing: -0.2,
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return Obx(() {
      final loading = controller.isSigningIn.value;

      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : _handleGoogleLogin,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFF3F4F6),
            foregroundColor: _kTextStrong,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _kBorder),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GoogleLogoMark(),
                    SizedBox(width: 10),
                    Text(
                      'Google로 로그인',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: _kTextStrong,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  Widget _buildAppleButton() {
    return Obx(() {
      final loading = controller.isSigningIn.value;

      if (loading) {
        return Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(
            child: SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            ),
          ),
        );
      }

      return SizedBox(
        width: double.infinity,
        height: 52,
        child: SignInWithAppleButton(
          onPressed: _handleAppleLogin,
          text: 'Apple로 로그인',
          style: SignInWithAppleButtonStyle.black,
          borderRadius: BorderRadius.circular(16),
          height: 52,
        ),
      );
    });
  }

  Widget _buildKakaoButton() {
    return Obx(() {
      final loading = controller.isSigningIn.value;

      return SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: loading ? null : _handleKakaoLogin,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFF3F4F6),
            foregroundColor: _kTextStrong,
            disabledForegroundColor: _kTextSoft,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: _kBorder),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: _kKakaoText,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _KakaoLogoMark(),
                    SizedBox(width: 10),
                    Text(
                      '카카오로 로그인',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.2,
                        color: _kTextStrong,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  Widget _buildLoggedInCard() {
    return Obx(() {
      final user = controller.currentUser.value;

      if (user == null) {
        return const SizedBox.shrink();
      }

      final buttonText = user.needsProfileSetup ? '가입 설정하기' : '옆가게로 이동';
      final description = user.needsProfileSetup
          ? '닉네임, 업종, 지역을 설정하면\n옆가게를 바로 이용할 수 있습니다.'
          : '로그인이 완료되었습니다.';

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 22,
                  color: _kPrimary,
                ),
                SizedBox(width: 8),
                Text(
                  '로그인 완료',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: _kTextStrong,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTextNormal,
                height: 1.45,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _goNextAfterLogin,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: Text(
                  buttonText,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Obx(() {
              final loggingOut = controller.isSigningOut.value;

              return SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  onPressed: loggingOut ? null : _handleLogout,
                  child: loggingOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          '로그아웃',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: _kTextSoft,
                          ),
                        ),
                ),
              );
            }),
          ],
        ),
      );
    });
  }

  Widget _buildLoginHelpText() {
    return const Text(
      '로그인 후 기본 정보를 설정하면\n옆가게를 바로 이용할 수 있습니다.\n안전한 이용을 위해 일부 기능은 인증 후 열립니다.',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: _kTextSoft,
        height: 1.45,
      ),
    );
  }

  Widget _buildLoginBody() {
    return Obx(() {
      final initialized = controller.isInitialized.value;
      final loggedIn = controller.isLoggedIn;

      if (!initialized) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 34, 20, 28),
        physics: const ClampingScrollPhysics(),
        children: [
          _buildHeader(),
          const SizedBox(height: 22),
          if (loggedIn) ...[
            _buildLoggedInCard(),
          ] else ...[
            _buildGoogleButton(),
            const SizedBox(height: 10),
            if (_canUseAppleLogin) ...[
              _buildAppleButton(),
              const SizedBox(height: 10),
            ],
            _buildKakaoButton(),
            const SizedBox(height: 18),
            _buildLoginHelpText(),
          ],
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          '로그인',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: _kTextStrong,
      ),
      body: SafeArea(
        child: _buildLoginBody(),
      ),
    );
  }
}

class _GoogleLogoMark extends StatelessWidget {
  const _GoogleLogoMark();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const Color _blue = Color(0xFF4285F4);
  static const Color _red = Color(0xFFEA4335);
  static const Color _yellow = Color(0xFFFBBC05);
  static const Color _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.19;
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    Paint arcPaint(Color color) {
      return Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;
    }

    const double deg = math.pi / 180;

    canvas.drawArc(rect, -38 * deg, 78 * deg, false, arcPaint(_blue));
    canvas.drawArc(rect, 40 * deg, 78 * deg, false, arcPaint(_green));
    canvas.drawArc(rect, 118 * deg, 72 * deg, false, arcPaint(_yellow));
    canvas.drawArc(rect, 190 * deg, 92 * deg, false, arcPaint(_red));
    canvas.drawArc(rect, 282 * deg, 40 * deg, false, arcPaint(_blue));

    final barPaint = Paint()
      ..color = _blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final centerY = size.height * 0.5;
    canvas.drawLine(
      Offset(size.width * 0.52, centerY),
      Offset(size.width * 0.96, centerY),
      barPaint,
    );

    final innerCutPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.67,
        size.height * 0.34,
        size.width * 0.34,
        size.height * 0.16,
      ),
      innerCutPaint,
    );

    canvas.drawLine(
      Offset(size.width * 0.52, centerY),
      Offset(size.width * 0.96, centerY),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) {
    return false;
  }
}

class _KakaoLogoMark extends StatelessWidget {
  const _KakaoLogoMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 25,
      height: 25,
      decoration: const BoxDecoration(
        color: Color(0xFFFEE500),
        borderRadius: BorderRadius.all(Radius.circular(8)),
      ),
      child: const Center(
        child: Icon(
          Icons.chat_bubble_rounded,
          size: 16,
          color: Color(0xFF191919),
        ),
      ),
    );
  }
}
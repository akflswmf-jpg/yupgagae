import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/routes/app_routes.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kPrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  late final AuthController controller;

  @override
  void initState() {
    super.initState();
    controller = Get.find<AuthController>();
  }

  Future<void> _handleGoogleLogin() async {
    await controller.signInWithGoogle();
  }

  Future<void> _handleLogout() async {
    await controller.signOut();
  }

  void _goRoot() {
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
          '자영업자 커뮤니티와 매출 비교 기능을 안전하게 사용하기 위해 계정 로그인을 시작합니다.',
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

  Widget _buildProviderNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: _kPrimarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8D8D0)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: _kPrimary,
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '현재는 Google 로그인부터 연결합니다. 이후 Kakao, Apple 로그인을 같은 내부 userId 체계에 붙입니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6B4D44),
                height: 1.4,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Obx(() {
      final message = controller.errorMessage.value;

      if (message == null || message.trim().isEmpty) {
        return const SizedBox.shrink();
      }

      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF1F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFCDD2)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: Color(0xFFE11D48),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF9F1239),
                    height: 1.4,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: controller.clearError,
                child: const Padding(
                  padding: EdgeInsets.all(2),
                  child: Icon(
                    Icons.close_rounded,
                    size: 17,
                    color: Color(0xFF9F1239),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
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
                    Icon(
                      Icons.g_mobiledata_rounded,
                      size: 30,
                      color: _kTextStrong,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Google로 계속하기',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      );
    });
  }

  Widget _buildComingSoonButton({
    required String label,
    required IconData icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          disabledForegroundColor: _kTextSoft,
          side: const BorderSide(color: _kBorder),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19),
            const SizedBox(width: 8),
            Text(
              '$label 준비 중',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoggedInCard() {
    return Obx(() {
      final user = controller.currentUser.value;

      if (user == null) {
        return const SizedBox.shrink();
      }

      final email = user.email ?? '이메일 없음';
      final provider = user.provider;
      final userId = user.userId;

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
                  size: 20,
                  color: _kPrimary,
                ),
                SizedBox(width: 8),
                Text(
                  '로그인 완료',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: _kTextStrong,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _InfoLine(label: '이메일', value: email),
            const SizedBox(height: 7),
            _InfoLine(label: 'Provider', value: provider),
            const SizedBox(height: 7),
            _InfoLine(label: '내부 userId', value: userId),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _goRoot,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  '옆가게로 이동',
                  style: TextStyle(
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
          const SizedBox(height: 18),
          _buildProviderNotice(),
          _buildErrorBox(),
          const SizedBox(height: 22),
          if (loggedIn) ...[
            _buildLoggedInCard(),
          ] else ...[
            _buildGoogleButton(),
            const SizedBox(height: 10),
            _buildComingSoonButton(
              label: '카카오 로그인',
              icon: Icons.chat_bubble_rounded,
            ),
            const SizedBox(height: 10),
            _buildComingSoonButton(
              label: 'Apple 로그인',
              icon: Icons.apple_rounded,
            ),
            const SizedBox(height: 18),
            const Text(
              '로그인 후 본인인증과 사업자 인증을 단계적으로 연결합니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: _kTextSoft,
                height: 1.45,
              ),
            ),
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

class _InfoLine extends StatelessWidget {
  final String label;
  final String value;

  const _InfoLine({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8A817C),
              height: 1.35,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF374151),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
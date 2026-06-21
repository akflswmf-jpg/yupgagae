import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_binding.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/routes/app_routes.dart';

class AuthActionGuard {
  AuthActionGuard._();

  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kBorder = Color(0xFFEDE7E3);

  static AuthController _authController() {
    if (!Get.isRegistered<AuthController>()) {
      AuthBinding().dependencies();
    }

    return Get.find<AuthController>();
  }

  static bool isParticipationAllowedNow() {
    final auth = _authController();
    final user = auth.currentUser.value;

    if (user == null) return false;
    if (user.needsProfileSetup) return false;

    return true;
  }

  static Future<bool> ensureParticipationAllowed({
    String title = '로그인이 필요한 기능입니다',
    String message = '로그인 후 글쓰기, 댓글, 좋아요를 이용할 수 있어요.',
  }) async {
    final auth = _authController();
    final user = auth.currentUser.value;

    if (user == null) {
      final shouldLogin = await _showLoginRequiredDialog(
        title: title,
        message: message,
      );

      if (shouldLogin) {
        Get.toNamed(AppRoutes.login);
      }

      return false;
    }

    if (user.needsProfileSetup) {
      Get.toNamed(AppRoutes.profileSetup);
      return false;
    }

    return true;
  }

  static Future<bool> ensureDirectRouteAllowed({
    String title = '로그인이 필요한 기능입니다',
    String message = '로그인 후 글쓰기, 댓글, 좋아요를 이용할 수 있어요.',
  }) async {
    final auth = _authController();
    final user = auth.currentUser.value;

    if (user == null) {
      final shouldLogin = await _showLoginRequiredDialog(
        title: title,
        message: message,
      );

      if (shouldLogin) {
        Get.offNamed(AppRoutes.login);
      } else {
        Get.offAllNamed(AppRoutes.root);
      }

      return false;
    }

    if (user.needsProfileSetup) {
      Get.offNamed(AppRoutes.profileSetup);
      return false;
    }

    return true;
  }

  static Future<bool> _showLoginRequiredDialog({
    required String title,
    required String message,
  }) async {
    final result = await Get.dialog<bool>(
      Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6EEEA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 20,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: _kTextStrong,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _kTextNormal,
                  height: 1.45,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: OutlinedButton(
                        onPressed: () {
                          Get.back(result: false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kTextNormal,
                          side: const BorderSide(color: _kBorder),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '나중에',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        onPressed: () {
                          Get.back(result: true);
                        },
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: _kPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text(
                          '로그인하기',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      barrierDismissible: true,
    );

    return result == true;
  }
}

class AuthRequiredRouteGate extends StatefulWidget {
  final Widget child;
  final String title;
  final String message;

  const AuthRequiredRouteGate({
    super.key,
    required this.child,
    this.title = '로그인이 필요한 기능입니다',
    this.message = '로그인 후 글쓰기, 댓글, 좋아요를 이용할 수 있어요.',
  });

  @override
  State<AuthRequiredRouteGate> createState() => _AuthRequiredRouteGateState();
}

class _AuthRequiredRouteGateState extends State<AuthRequiredRouteGate> {
  bool _checking = true;
  bool _allowed = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _check();
    });
  }

  Future<void> _check() async {
    if (_started) return;
    _started = true;

    final allowed = await AuthActionGuard.ensureDirectRouteAllowed(
      title: widget.title,
      message: widget.message,
    );

    if (!mounted) return;

    setState(() {
      _allowed = allowed;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_allowed) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: _checking
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              )
            : const SizedBox.shrink(),
      ),
    );
  }
}
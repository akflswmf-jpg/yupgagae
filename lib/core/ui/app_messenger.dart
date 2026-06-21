import 'dart:async';
import 'package:flutter/material.dart';

class AppMessenger {
  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static ScaffoldMessengerState? get _m => messengerKey.currentState;

  /// ✅ 배너/스낵바/큐까지 “완전 제거”
  static void clearAll() {
    final m = _m;
    if (m == null) return;

    // Banner
    m.hideCurrentMaterialBanner();
    m.clearMaterialBanners();

    // SnackBar
    m.removeCurrentSnackBar();
    m.clearSnackBars();

    // ✅ 프레임/큐 잔상 방지 2차 제거
    scheduleMicrotask(() {
      final mm = _m;
      if (mm == null) return;
      mm.hideCurrentMaterialBanner();
      mm.clearMaterialBanners();
      mm.removeCurrentSnackBar();
      mm.clearSnackBars();
    });
  }

  /// ✅ SnackBar 표시 (빈 메시지는 절대 띄우지 않음)
  static void showSnack(
    String message, {
    String? title,
    bool isError = false,
    Duration duration = const Duration(seconds: 2),
  }) {
    final msg = message.trim();
    final ttl = title?.trim();

    // ✅ “빈 빨간 박스” 1차 방지
    if (msg.isEmpty && (ttl == null || ttl.isEmpty)) return;

    final m = _m;
    if (m == null) return;

    // ✅ 잔상/큐 방지: 항상 클리어 후 표시
    clearAll();

    final text = (ttl != null && ttl.isNotEmpty) ? '[$ttl] $msg' : msg;

    m.showSnackBar(
      SnackBar(
        content: Text(text.trim()),
        duration: duration,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ✅ MaterialBanner 표시 (사용 시)
  static void showBanner(
    String message, {
    String? title,
    bool isError = false,
    Duration? duration,
    List<Widget>? actions,
  }) {
    final msg = message.trim();
    final ttl = title?.trim();

    if (msg.isEmpty && (ttl == null || ttl.isEmpty)) return;

    final m = _m;
    if (m == null) return;

    clearAll();

    final text = (ttl != null && ttl.isNotEmpty) ? '[$ttl] $msg' : msg;

    m.showMaterialBanner(
      MaterialBanner(
        content: Text(text.trim()),
        actions: actions ?? const [],
      ),
    );

    if (duration != null) {
      Future.delayed(duration, () => clearAll());
    }
  }
}
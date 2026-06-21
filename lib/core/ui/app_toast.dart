import 'package:yupgagae/core/ui/app_messenger.dart';

class AppToast {
  /// 기존 코드 호환용 API 유지
  static void show(
    String message, {
    String? title,
    bool isError = false,
  }) {
    final msg = message.trim();
    final ttl = title?.trim();

    // ✅ 빈 박스 방지: title/message 둘 다 비면 아무 것도 띄우지 않음
    if (msg.isEmpty && (ttl == null || ttl.isEmpty)) return;

    AppMessenger.showSnack(
      msg,
      title: ttl,
      isError: isError,
    );
  }

  static void clear() {
    AppMessenger.clearAll();
  }
}
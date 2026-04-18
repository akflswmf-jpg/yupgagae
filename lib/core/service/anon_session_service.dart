import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// ✅ 익명 세션 서비스
/// - main.dart: final anon = await AnonSessionService.load();
/// - 그 외 코드: AnonSessionService() 기본 생성자도 허용 (호환성)
class AnonSessionService {
  static const _kAnonIdKey = 'anon_id_v1';

  String _anonId;

  /// ✅ 기본 생성자 (즉시 사용 가능)
  /// - 저장된 값은 load()에서만 보장되지만,
  /// - DI 실수/호출 순서 문제로도 "앵꼬" 안 나게 일단 임시 anonId를 가진 인스턴스를 만들 수 있게 함.
  AnonSessionService() : _anonId = _generateAnonId();

  /// ✅ 내부 생성자 (load()에서 사용)
  AnonSessionService._(this._anonId);

  String get anonId => _anonId;

  /// ✅ main.dart가 이미 쓰는 형태 그대로 지원
  static Future<AnonSessionService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kAnonIdKey);

    if (existing != null && existing.isNotEmpty) {
      return AnonSessionService._(existing);
    }

    final created = _generateAnonId();
    await prefs.setString(_kAnonIdKey, created);
    return AnonSessionService._(created);
  }

  /// ✅ (선택) 런타임 중에라도 영구 저장 ID로 동기화하고 싶을 때 호출 가능
  Future<void> syncFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kAnonIdKey);
    if (existing != null && existing.isNotEmpty) {
      _anonId = existing;
    } else {
      await prefs.setString(_kAnonIdKey, _anonId);
    }
  }

  static String _generateAnonId() {
    final r = Random();
    final n = r.nextInt(1 << 31);
    return 'anon_$n';
  }
}
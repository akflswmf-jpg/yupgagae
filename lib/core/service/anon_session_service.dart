import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class AnonSessionService {
  static const _kAnonIdKey = 'anon_id_v1';

  final String _anonId;

  AnonSessionService._(this._anonId);

  String get anonId => _anonId;

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

  static String _generateAnonId() {
    final r = Random();
    final n = r.nextInt(1 << 31);
    return 'anon_$n';
  }
}
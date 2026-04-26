import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AnonSessionService {
  static const _kAnonIdKey = 'anon_id_v1';

  static const Uuid _uuid = Uuid();

  final String _anonId;

  AnonSessionService._(this._anonId);

  String get anonId => _anonId;

  static Future<AnonSessionService> load() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kAnonIdKey)?.trim();

    if (existing != null && existing.isNotEmpty) {
      return AnonSessionService._(existing);
    }

    final created = _generateAnonId();
    await prefs.setString(_kAnonIdKey, created);

    return AnonSessionService._(created);
  }

  static String _generateAnonId() {
    return 'anon_${_uuid.v4()}';
  }
}
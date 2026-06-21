import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const _key = 'community_search_history_v2_json';

  Future<List<String>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) {
      return <String>[];
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>[];

      return decoded
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> saveKeyword(String keyword) async {
    final q = keyword.trim();
    if (q.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = await getHistory();

    current.removeWhere((e) => e == q);
    current.insert(0, q);

    if (current.length > 10) {
      current.removeRange(10, current.length);
    }

    await prefs.setString(_key, jsonEncode(current));
  }

  Future<void> removeKeyword(String keyword) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getHistory();

    current.removeWhere((e) => e == keyword);
    await prefs.setString(_key, jsonEncode(current));
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(<String>[]));
  }
}
import 'package:yupgagae/features/community/service/moderation_service.dart';

/// 글쓰기 전 “행동 규칙”
/// - 쿨다운(작성자별)
/// - 중복 작성 방지(작성자별)
/// - 링크 제한(원하면 여기에도 추가 가능)
class PostGuardService {
  final ModerationService moderation;
  PostGuardService({required this.moderation});

  /// userId(=anonId)별 마지막 글 작성 시간
  final Map<String, DateTime> _lastPostAtByUser = {};

  /// userId별 최근 해시(중복 방지)
  final Map<String, Map<String, DateTime>> _recentHashesByUser = {};

  bool canPostNow(String userId) {
    final last = _lastPostAtByUser[userId];
    if (last == null) return true;

    final cooldown = moderation.cooldownSecondsForAuthor(userId);
    final diff = DateTime.now().difference(last).inSeconds;
    return diff >= cooldown;
  }

  int cooldownSecondsNow(String userId) {
    return moderation.cooldownSecondsForAuthor(userId);
  }

  bool isDuplicate(String userId, String contentHash, {required int windowMinutes}) {
    final map = _recentHashesByUser[userId];
    if (map == null) return false;

    final last = map[contentHash];
    if (last == null) return false;

    final diff = DateTime.now().difference(last).inMinutes;
    return diff <= windowMinutes;
  }

  void markPosted(String userId, String contentHash) {
    _lastPostAtByUser[userId] = DateTime.now();
    final map = _recentHashesByUser.putIfAbsent(userId, () => {});
    map[contentHash] = DateTime.now();
  }

  void compact({required int windowMinutes}) {
    final now = DateTime.now();
    for (final entry in _recentHashesByUser.entries) {
      entry.value.removeWhere((_, t) => now.difference(t).inMinutes > windowMinutes * 2);
    }
  }

  int countLinks(String text) {
    final urlRegex = RegExp(r'(https?:\/\/|www\.)\S+', caseSensitive: false);
    return urlRegex.allMatches(text).length;
  }
}
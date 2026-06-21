import 'package:yupgagae/features/harugyeol/domain/harugyeol_comment.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_day_summary.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_entry.dart';
import 'package:yupgagae/features/harugyeol/domain/harugyeol_enums.dart';

class HarugyeolSubmitInput {
  final String dateKey;
  final HarugyeolSlot slot;
  final HarugyeolMood mood;
  final List<HarugyeolReason> reasons;
  final String oneLineText;

  const HarugyeolSubmitInput({
    required this.dateKey,
    required this.slot,
    required this.mood,
    required this.reasons,
    required this.oneLineText,
  });
}

abstract class HarugyeolRepository {
  Stream<HarugyeolDaySummary> watchDaySummary(String dateKey);

  Stream<List<HarugyeolEntry>> watchMyEntries(String dateKey);

  Stream<List<HarugyeolComment>> watchComments(String dateKey);

  Future<void> submitEntry(HarugyeolSubmitInput input);

  Future<void> toggleCommentLike({
    required String dateKey,
    required String commentId,
  });
}
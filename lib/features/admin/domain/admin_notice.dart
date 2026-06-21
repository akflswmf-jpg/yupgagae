import 'package:cloud_firestore/cloud_firestore.dart';

class AdminNotice {
  final String noticeId;
  final String title;
  final String body;
  final bool isVisible;
  final bool isPinned;
  final String createdByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AdminNotice({
    required this.noticeId,
    required this.title,
    required this.body,
    required this.isVisible,
    required this.isPinned,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminNotice.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return AdminNotice(
      noticeId: doc.id,
      title: (data['title'] as String?)?.trim() ?? '',
      body: (data['body'] as String?)?.trim() ?? '',
      isVisible: data['isVisible'] == true,
      isPinned: data['isPinned'] == true,
      createdByUserId: (data['createdByUserId'] as String?)?.trim() ?? '',
      createdAt: _timestampToDate(data['createdAt']),
      updatedAt: _timestampToDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'title': title.trim(),
      'body': body.trim(),
      'isVisible': isVisible,
      'isPinned': isPinned,
      'createdByUserId': createdByUserId.trim(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  Map<String, dynamic> toUpdateMap() {
    return {
      'title': title.trim(),
      'body': body.trim(),
      'isVisible': isVisible,
      'isPinned': isPinned,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AdminNotice copyWith({
    String? noticeId,
    String? title,
    String? body,
    bool? isVisible,
    bool? isPinned,
    String? createdByUserId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminNotice(
      noticeId: noticeId ?? this.noticeId,
      title: title ?? this.title,
      body: body ?? this.body,
      isVisible: isVisible ?? this.isVisible,
      isPinned: isPinned ?? this.isPinned,
      createdByUserId: createdByUserId ?? this.createdByUserId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  static DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return null;
  }
}

// END_OF_FILE: lib/features/admin/domain/admin_notice.dart
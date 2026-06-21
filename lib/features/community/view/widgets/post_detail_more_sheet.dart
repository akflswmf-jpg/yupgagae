import 'package:flutter/material.dart';

enum PostDetailMoreAction {
  editPost,
  deletePost,
  reportPost,
}

Future<PostDetailMoreAction?> showPostDetailMoreSheet({
  required BuildContext context,
  required bool isOwner,
  required bool isDeleting,
}) {
  return showModalBottomSheet<PostDetailMoreAction>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner) ...[
                _MoreActionTile(
                  icon: Icons.edit_outlined,
                  iconColor: const Color(0xFF374151),
                  backgroundColor: const Color(0xFFF8FAFC),
                  label: '게시글 수정',
                  labelColor: const Color(0xFF111111),
                  onTap: () => Navigator.of(context).pop(
                    PostDetailMoreAction.editPost,
                  ),
                ),
                const SizedBox(height: 10),
                _MoreActionTile(
                  icon: Icons.delete_outline_rounded,
                  iconColor: isDeleting
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFFE5484D),
                  backgroundColor: isDeleting
                      ? const Color(0xFFF8FAFC)
                      : const Color(0xFFFFF1F2),
                  label: isDeleting ? '삭제 중...' : '게시글 삭제',
                  labelColor: isDeleting
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFFE5484D),
                  onTap: isDeleting
                      ? null
                      : () => Navigator.of(context).pop(
                            PostDetailMoreAction.deletePost,
                          ),
                ),
              ],
              if (!isOwner) ...[
                _MoreActionTile(
                  icon: Icons.flag_outlined,
                  iconColor: const Color(0xFF374151),
                  backgroundColor: const Color(0xFFF8FAFC),
                  label: '게시글 신고',
                  labelColor: const Color(0xFF111111),
                  onTap: () => Navigator.of(context).pop(
                    PostDetailMoreAction.reportPost,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

Future<String?> showCommentReportReasonSheet(BuildContext context) {
  const reasons = <String>[
    '스팸/도배',
    '욕설/비방',
    '허위정보',
    '음란/부적절한 내용',
    '기타',
  ];

  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '신고 사유를 선택하세요.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111111),
                    ),
                  ),
                ),
              ),
              ...reasons.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _ReasonTile(
                    label: reason,
                    onTap: () => Navigator.of(sheetContext).pop(reason),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _MoreActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final String label;
  final Color labelColor;
  final VoidCallback? onTap;

  const _MoreActionTile({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.label,
    required this.labelColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;

    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Opacity(
          opacity: disabled ? 0.72 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 19,
                    color: iconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: labelColor,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: disabled
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF9CA3AF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReasonTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ReasonTile({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 18,
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
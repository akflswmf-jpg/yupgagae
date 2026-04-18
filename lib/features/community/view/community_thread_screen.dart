import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/view/widgets/author_meta_line.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';

const Color kThreadSnackBg = Color(0xFF875646);

class CommunityThreadScreen extends StatefulWidget {
  const CommunityThreadScreen({super.key});

  @override
  State<CommunityThreadScreen> createState() => _CommunityThreadScreenState();
}

class _CommunityThreadScreenState extends State<CommunityThreadScreen> {
  late final CommentController c;
  late final ScrollController _scrollController;

  final TextEditingController _inputCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// 등록/수정 중 중복 입력 방지용
  final RxBool _isSubmittingLocal = false.obs;

  String _postId = '';
  String _rootCommentId = '';
  String? _focusCommentId;
  String? _editingCommentId;

  bool _bootLoading = true;
  String? _bootError;

  @override
  void initState() {
    super.initState();

    c = Get.find<CommentController>();
    _scrollController = ScrollController();

    final args = (Get.arguments as Map?) ?? const {};
    _postId = (args['postId'] ?? '').toString().trim();
    _rootCommentId = (args['rootCommentId'] ?? '').toString().trim();

    final focusRaw = (args['focusCommentId'] ?? '').toString().trim();
    _focusCommentId = focusRaw.isEmpty ? null : focusRaw;

    final editingRaw = (args['editingCommentId'] ?? '').toString().trim();
    _editingCommentId = editingRaw.isEmpty ? null : editingRaw;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_postId.isEmpty || _rootCommentId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _bootLoading = false;
          _bootError = 'postId 또는 rootCommentId가 없습니다.';
        });
        return;
      }

      try {
        await c.initialize(_postId);

        if (_editingCommentId != null) {
          final editingTarget = c.commentById(_editingCommentId!);
          if (editingTarget != null &&
              !editingTarget.isDeleted &&
              !editingTarget.isReportThresholdReached) {
            _inputCtrl.text = editingTarget.text;
          } else {
            _editingCommentId = null;
          }
        }

        if (!mounted) return;
        setState(() {
          _bootLoading = false;
          _bootError = null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (_editingCommentId != null) {
            _focusNode.requestFocus();
          }

          _scrollToTargetOrBottom();
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _bootLoading = false;
          _bootError = e.toString();
        });
      }
    });
  }

  @override
  void dispose() {
    _focusNode.unfocus();
    _scrollController.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  void _dismissKeyboard() {
    final scope = FocusScope.of(context);
    if (!scope.hasPrimaryFocus && scope.focusedChild != null) {
      scope.unfocus();
    }
    FocusManager.instance.primaryFocus?.unfocus();
    _focusNode.unfocus();
  }

  Future<void> _settleKeyboard() async {
    _dismissKeyboard();
    await Future.delayed(const Duration(milliseconds: 240));
  }

  Future<void> _settleKeyboardForSubmit() async {
    _dismissKeyboard();
    await WidgetsBinding.instance.endOfFrame;
    await Future.delayed(const Duration(milliseconds: 180));
  }

  Future<void> _handleWillPop() async {
    await _settleKeyboard();
  }

  void _scrollToBottom({bool animated = false}) {
    if (!mounted || !_scrollController.hasClients) return;

    final target = _scrollController.position.maxScrollExtent;

    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    _scrollController.jumpTo(target);
  }

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (_isSubmittingLocal.value) return;
    if (c.isSubmitting.value) return;

    _isSubmittingLocal.value = true;

    try {
      // 일반 댓글과 동일한 방식:
      // 1) 키보드 먼저 안정적으로 내리고
      // 2) 그 다음 상태 변경
      // 3) 입력 clear / scroll은 뒤로 분리
      await _settleKeyboardForSubmit();

      if (_editingCommentId != null) {
        await c.updateComment(
          commentId: _editingCommentId!,
          text: text,
        );
        _showSnack('댓글을 수정했어요.');
      } else {
        await c.reply(
          parentCommentId: _rootCommentId,
          text: text,
        );
        _showSnack('답글을 등록했어요.');
      }

      _inputCtrl.clear();

      if (!mounted) return;
      setState(() {
        _editingCommentId = null;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 70), () {
          if (!mounted) return;
          _scrollToBottom(animated: true);
        });
      });
    } catch (e) {
      _inputCtrl.text = text;
      _inputCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputCtrl.text.length),
      );
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        _isSubmittingLocal.value = false;
      }
    }
  }

  void _startEdit(Comment comment) {
    if (comment.isDeleted || comment.isReportThresholdReached) return;

    setState(() {
      _editingCommentId = comment.id;
      _inputCtrl.text = comment.text;
    });

    _focusNode.requestFocus();
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: true);
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingCommentId = null;
      _inputCtrl.clear();
    });
    _dismissKeyboard();
  }

  Future<void> _delete(Comment comment) async {
    final ok = await _showConfirmDialog(
      title: '댓글 삭제',
      message: '이 댓글을 삭제할까요?',
      confirmText: '삭제',
      isDestructive: true,
    );
    if (!ok) return;

    await _settleKeyboard();

    try {
      await c.delete(comment.id);
      _showSnack('댓글을 삭제했어요.');

      if (_editingCommentId == comment.id) {
        _cancelEdit();
      }
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _report(Comment comment) async {
    final reason = await _showReasonPicker(title: '댓글 신고');
    if (reason == null) return;

    await _settleKeyboard();

    try {
      await c.report(
        commentId: comment.id,
        reason: reason,
      );
      _showSnack('댓글을 신고했어요.');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    bool isDestructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('취소'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                confirmText,
                style: TextStyle(
                  color: isDestructive ? Colors.red : null,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  Future<String?> _showReasonPicker({
    required String title,
  }) async {
    const reasons = <String>[
      '광고/홍보성 내용',
      '욕설/비방',
      '음란/불쾌한 내용',
      '도배/스팸',
      '기타',
    ];

    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              for (final reason in reasons)
                ListTile(
                  title: Text(reason),
                  onTap: () => Navigator.of(context).pop(reason),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showSnack(String message) {
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kThreadSnackBg,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _scrollToTargetOrBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final replies = c.repliesOf(_rootCommentId);
      final hasTarget =
          _focusCommentId != null && replies.any((e) => e.id == _focusCommentId);

      if (hasTarget) {
        final index = replies.indexWhere((e) => e.id == _focusCommentId) + 1;
        final offset = index * 108.0;

        _scrollController.jumpTo(
          offset.clamp(
            0,
            _scrollController.position.maxScrollExtent,
          ),
        );
        return;
      }

      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_bootLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_bootError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('답글')),
        body: Center(child: Text(_bootError!)),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        await _handleWillPop();
        return true;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            title: const Text('답글'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () async {
                await _handleWillPop();
                if (mounted) Get.back(result: true);
              },
            ),
          ),
          body: SafeArea(
            top: false,
            bottom: false,
            child: _ThreadBodyList(
              controller: c,
              scrollController: _scrollController,
              rootCommentId: _rootCommentId,
              focusCommentId: _focusCommentId,
              timeLabel: _timeLabel,
              onEdit: _startEdit,
              onDelete: _delete,
              onReport: _report,
            ),
          ),
          bottomNavigationBar: _BottomReplyBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            isSubmitting: _isSubmittingLocal,
            isEditing: _editingCommentId != null,
            onCancelEdit: _cancelEdit,
            onSubmit: _submit,
          ),
        ),
      ),
    );
  }
}

class _ThreadBodyList extends StatelessWidget {
  final CommentController controller;
  final ScrollController scrollController;
  final String rootCommentId;
  final String? focusCommentId;
  final String Function(DateTime) timeLabel;
  final void Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;

  const _ThreadBodyList({
    required this.controller,
    required this.scrollController,
    required this.rootCommentId,
    required this.focusCommentId,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ListView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        children: [
          _RootCommentCard(
            rootId: rootCommentId,
            controller: controller,
            timeLabel: timeLabel,
            onEdit: onEdit,
            onDelete: onDelete,
            onReport: onReport,
          ),
          _RepliesHeader(
            controller: controller,
            rootCommentId: rootCommentId,
          ),
          _RepliesList(
            controller: controller,
            rootCommentId: rootCommentId,
            timeLabel: timeLabel,
            onEdit: onEdit,
            onDelete: onDelete,
            onReport: onReport,
          ),
        ],
      ),
    );
  }
}

class _RepliesHeader extends StatelessWidget {
  final CommentController controller;
  final String rootCommentId;

  const _RepliesHeader({
    required this.controller,
    required this.rootCommentId,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final myStore = Get.find<MyStoreController>();
      final blockedIds = myStore.blockedUsers.map((e) => e.userId).toSet();

      final replies = controller.repliesOf(rootCommentId);
      final visibleReplies = replies.where((reply) {
        return !blockedIds.contains(reply.authorId);
      }).toList(growable: false);

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        child: Text(
          '답글 ${visibleReplies.length}',
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: Color(0xFF6B7280),
          ),
        ),
      );
    });
  }
}

class _RepliesList extends StatelessWidget {
  final CommentController controller;
  final String rootCommentId;
  final String Function(DateTime) timeLabel;
  final void Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;

  const _RepliesList({
    required this.controller,
    required this.rootCommentId,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final myStore = Get.find<MyStoreController>();
      final blockedIds = myStore.blockedUsers.map((e) => e.userId).toSet();

      final replies = controller.repliesOf(rootCommentId);
      final visibleReplies = replies.where((reply) {
        return !blockedIds.contains(reply.authorId);
      }).toList(growable: false);

      return Column(
        children: [
          for (final reply in visibleReplies)
            _ReplyCommentCard(
              replyId: reply.id,
              controller: controller,
              timeLabel: timeLabel,
              onEdit: onEdit,
              onDelete: onDelete,
              onReport: onReport,
            ),
        ],
      );
    });
  }
}

class _RootCommentCard extends StatelessWidget {
  final String rootId;
  final CommentController controller;
  final String Function(DateTime) timeLabel;
  final void Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;

  const _RootCommentCard({
    required this.rootId,
    required this.controller,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  Future<void> _blockUser(Comment root) async {
    final myStore = Get.find<MyStoreController>();

    await myStore.blockUser(
      BlockedUserItem(
        userId: root.authorId,
        nickname: root.authorLabel.trim().isEmpty ? '익명' : root.authorLabel,
        industry: root.industryId,
        region: root.locationLabel,
        blockedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final root = controller.commentById(rootId);
      if (root == null) return const SizedBox.shrink();

      final myStore = Get.find<MyStoreController>();
      final blockedIds = myStore.blockedUsers.map((e) => e.userId).toSet();

      if (blockedIds.contains(root.authorId)) {
        return const SizedBox.shrink();
      }

      final blocked = root.isDeleted || root.isReportThresholdReached;
      final isMine = root.authorId == controller.currentUserId;
      final isLikedByMe = root.likedUserIds.contains(controller.currentUserId);
      final likeColor =
          isLikedByMe ? const Color(0xFFE5484D) : const Color(0xFF6B7280);

      return Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E9EE)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthorMetaLine(
              industryId: root.industryId,
              locationLabel: root.locationLabel,
              nicknameLabel: root.authorLabel,
              timeLabel: timeLabel(root.createdAt),
              dense: true,
              isOwnerVerified: root.isOwnerVerified,
            ),
            const SizedBox(height: 7),
            Text(
              root.isDeleted
                  ? '삭제된 댓글입니다.'
                  : root.isReportThresholdReached
                      ? '블라인드 처리된 댓글입니다.'
                      : root.text,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: blocked
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF1F2937),
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!blocked) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  _InlineTextAction(
                    onTap: () async {
                      await controller.toggleLike(root.id);
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLikedByMe ? Icons.favorite : Icons.favorite_border,
                          size: 14,
                          color: likeColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${root.likeCount}',
                          style: TextStyle(
                            fontSize: 12,
                            color: likeColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isMine)
                    _InlineTextAction(
                      onTap: () async {
                        onEdit(root);
                      },
                      child: const Text(
                        '수정',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (isMine)
                    _InlineTextAction(
                      onTap: () async {
                        await onDelete(root);
                      },
                      child: const Text(
                        '삭제',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE5484D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (!isMine)
                    _InlineTextAction(
                      onTap: () async {
                        await onReport(root);
                      },
                      child: const Text(
                        '신고',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (!isMine)
                    _InlineTextAction(
                      onTap: () async {
                        await _blockUser(root);
                      },
                      child: const Text(
                        '차단',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFFE5484D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _ReplyCommentCard extends StatelessWidget {
  final String replyId;
  final CommentController controller;
  final String Function(DateTime) timeLabel;
  final void Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;

  const _ReplyCommentCard({
    required this.replyId,
    required this.controller,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
  });

  Future<void> _blockUser(Comment reply) async {
    final myStore = Get.find<MyStoreController>();

    await myStore.blockUser(
      BlockedUserItem(
        userId: reply.authorId,
        nickname: reply.authorLabel.trim().isEmpty ? '익명' : reply.authorLabel,
        industry: reply.industryId,
        region: reply.locationLabel,
        blockedAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final reply = controller.commentById(replyId);
      if (reply == null) return const SizedBox.shrink();

      final myStore = Get.find<MyStoreController>();
      final blockedIds = myStore.blockedUsers.map((e) => e.userId).toSet();

      if (blockedIds.contains(reply.authorId)) {
        return const SizedBox.shrink();
      }

      final blocked = reply.isDeleted || reply.isReportThresholdReached;
      final isMine = reply.authorId == controller.currentUserId;
      final isLikedByMe = reply.likedUserIds.contains(controller.currentUserId);
      final likeColor =
          isLikedByMe ? const Color(0xFFE5484D) : const Color(0xFF6B7280);

      return Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF1F3F5)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(
                    Icons.subdirectory_arrow_right_rounded,
                    size: 14,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
                Expanded(
                  child: AuthorMetaLine(
                    industryId: reply.industryId,
                    locationLabel: reply.locationLabel,
                    nicknameLabel: reply.authorLabel,
                    timeLabel: timeLabel(reply.createdAt),
                    dense: true,
                    isOwnerVerified: reply.isOwnerVerified,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(left: 19),
              child: Text(
                reply.isDeleted
                    ? '삭제된 댓글입니다.'
                    : reply.isReportThresholdReached
                        ? '블라인드 처리된 댓글입니다.'
                        : reply.text,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: blocked
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!blocked) ...[
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 19),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _InlineTextAction(
                      onTap: () async {
                        await controller.toggleLike(reply.id);
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isLikedByMe ? Icons.favorite : Icons.favorite_border,
                            size: 14,
                            color: likeColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${reply.likeCount}',
                            style: TextStyle(
                              fontSize: 12,
                              color: likeColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isMine)
                      _InlineTextAction(
                        onTap: () async {
                          onEdit(reply);
                        },
                        child: const Text(
                          '수정',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    if (isMine)
                      _InlineTextAction(
                        onTap: () async {
                          await onDelete(reply);
                        },
                        child: const Text(
                          '삭제',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE5484D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (!isMine)
                      _InlineTextAction(
                        onTap: () async {
                          await onReport(reply);
                        },
                        child: const Text(
                          '신고',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (!isMine)
                      _InlineTextAction(
                        onTap: () async {
                          await _blockUser(reply);
                        },
                        child: const Text(
                          '차단',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFFE5484D),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
    });
  }
}

class _BottomReplyBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final RxBool isSubmitting;
  final bool isEditing;
  final VoidCallback onCancelEdit;
  final Future<void> Function() onSubmit;

  const _BottomReplyBar({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.isEditing,
    required this.onCancelEdit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final keyboardBottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardBottom),
      child: RepaintBoundary(
        child: Material(
          color: Colors.white,
          elevation: 8,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isEditing)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              '댓글 수정 중',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: onCancelEdit,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              '취소',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF6B7280),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 38),
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            minLines: 1,
                            maxLines: 3,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => onSubmit(),
                            decoration: InputDecoration(
                              hintText:
                                  isEditing ? '댓글을 수정하세요.' : '답글을 입력하세요.',
                              hintStyle: const TextStyle(
                                color: Color(0xFF9CA3AF),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              isDense: true,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              errorBorder: InputBorder.none,
                              focusedErrorBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 0,
                                vertical: 8,
                              ),
                            ),
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 14,
                              height: 1.35,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Obx(() {
                        final enabled = !isSubmitting.value;

                        return TextButton(
                          onPressed: enabled ? onSubmit : null,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            isEditing ? '수정' : '등록',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: enabled
                                  ? const Color(0xFF875646)
                                  : const Color(0xFFB6A79F),
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineTextAction extends StatelessWidget {
  final Widget child;
  final Future<void> Function() onTap;

  const _InlineTextAction({
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        await onTap();
      },
      borderRadius: BorderRadius.circular(6),
      splashColor: const Color(0x08000000),
      highlightColor: const Color(0x04000000),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 2),
        child: child,
      ),
    );
  }
}
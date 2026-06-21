import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_action_guard.dart';
import 'package:yupgagae/core/navigation/route_input_resolver.dart';
import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/view/widgets/post_detail_comments_section.dart';

const Color kThreadSnackBg = Color(0xFF875646);
const Color kThreadSubmitAccent = Color(0xFF875646);

const Duration kThreadSubmitMinimumDuration = Duration(milliseconds: 1000);

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

  final RxBool _isSubmittingLocal = false.obs;
  final Map<String, GlobalKey> _commentItemKeys = <String, GlobalKey>{};

  bool _isPopping = false;
  bool _didSubmit = false;

  String _postId = '';
  String _rootCommentId = '';
  String? _focusCommentId;
  String? _editingCommentId;
  String? _latestSubmittedReplyId;

  bool _bootLoading = true;
  String? _bootError;

  @override
  void initState() {
    super.initState();

    c = Get.find<CommentController>();
    _scrollController = ScrollController();

    _postId = RouteInputResolver.string('postId')?.trim() ?? '';
    _rootCommentId = RouteInputResolver.string('rootCommentId')?.trim() ?? '';

    final focusRaw = RouteInputResolver.string('focusCommentId')?.trim() ?? '';
    _focusCommentId = focusRaw.isEmpty ? null : focusRaw;

    final editingRaw =
        RouteInputResolver.string('editingCommentId')?.trim() ?? '';
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
          final canEditInCurrentPost = c.canWriteCurrentPostComment;

          if (editingTarget != null &&
              canEditInCurrentPost &&
              !editingTarget.isDeleted &&
              !editingTarget.isHiddenFromPublic) {
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

          if (_editingCommentId != null && c.canWriteCurrentPostComment) {
            _focusNode.requestFocus();
          }

          _scrollToTargetOrBottom();
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _bootLoading = false;
          _bootError = e.toString().replaceFirst('Exception: ', '');
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

  GlobalKey _keyForComment(String commentId) {
    return _commentItemKeys.putIfAbsent(
      commentId,
      () => GlobalKey(debugLabel: 'thread_comment_$commentId'),
    );
  }

  Future<bool> _ensureParticipation({
    required String message,
  }) {
    return AuthActionGuard.ensureParticipationAllowed(
      title: '로그인이 필요한 기능입니다',
      message: message,
    );
  }

  String _permissionMessage({
    required bool isEditing,
  }) {
    if (!c.canParticipate) {
      return isEditing
          ? '로그인 후 댓글 수정을 이용할 수 있어요.'
          : '로그인 후 답글을 이용할 수 있어요.';
    }

    return isEditing
        ? '인증 후 댓글을 수정할 수 있습니다.'
        : '인증 후 답글을 작성할 수 있습니다.';
  }

  String _lockedHintText({
    required bool isEditing,
  }) {
    return isEditing
        ? '본인인증 후 댓글 수정이 가능합니다.'
        : '본인인증 후 답글 입력이 가능합니다.';
  }

  Future<bool> _ensureThreadWriteAllowed({
    required bool isEditing,
  }) async {
    final allowed = await _ensureParticipation(
      message: _permissionMessage(isEditing: isEditing),
    );

    if (!allowed) return false;

    if (!c.canWriteCurrentPostComment) {
      _showSnack(_permissionMessage(isEditing: isEditing));
      return false;
    }

    return true;
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

  void _dismissKeyboardForSubmit() {
    _dismissKeyboard();
  }

  Future<void> _paintSubmitOverlayBeforeWork() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 60));
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

  Future<void> _scrollToBottomAfterLocalReplyInsert() async {
    for (var i = 0; i < 4; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _scrollToBottom(animated: false);
    }
  }

  void _jumpNearTarget(String commentId) {
    if (!mounted || !_scrollController.hasClients) return;

    if (commentId == _rootCommentId) {
      _scrollController.jumpTo(0);
      return;
    }

    final index = c.replyIndexOf(
      rootCommentId: _rootCommentId,
      replyId: commentId,
    );

    if (index < 0) return;

    final estimatedOffset = 120.0 + (index * 92.0);
    final maxScrollExtent = _scrollController.position.maxScrollExtent;

    _scrollController.jumpTo(
      estimatedOffset.clamp(0.0, maxScrollExtent),
    );
  }

  Future<void> _ensureCommentVisible(String commentId) async {
    if (!mounted) return;

    _jumpNearTarget(commentId);

    for (var i = 0; i < 6; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final targetContext = _commentItemKeys[commentId]?.currentContext;
      if (targetContext == null) {
        _jumpNearTarget(commentId);
        continue;
      }

      await Scrollable.ensureVisible(
        targetContext,
        duration: Duration.zero,
        alignment: 0.08,
        curve: Curves.linear,
      );
      return;
    }
  }

  Future<void> _forceRevealNewReply(String replyId) async {
    if (replyId.trim().isEmpty) return;

    for (var i = 0; i < 5; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;

      final targetContext = _commentItemKeys[replyId]?.currentContext;
      if (targetContext != null) {
        await Scrollable.ensureVisible(
          targetContext,
          duration: Duration.zero,
          alignment: 0.78,
          curve: Curves.linear,
        );
        return;
      }

      _scrollToBottom(animated: false);
    }

    if (!mounted) return;
    _scrollToBottom(animated: false);
  }

  Future<void> _submit() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    if (_isSubmittingLocal.value) return;
    if (c.isSubmitting.value) return;

    final editingId = _editingCommentId;
    final isEditing = editingId != null;

    final allowed = await _ensureThreadWriteAllowed(
      isEditing: isEditing,
    );
    if (!allowed) return;

    _isSubmittingLocal.value = true;
    _inputCtrl.clear();
    _dismissKeyboardForSubmit();

    final minimumSubmitFuture =
        Future<void>.delayed(kThreadSubmitMinimumDuration);

    try {
      await _paintSubmitOverlayBeforeWork();

      if (editingId != null) {
        await c.updateComment(
          commentId: editingId,
          text: text,
        );

        await minimumSubmitFuture;

        _didSubmit = true;

        if (!mounted) return;

        setState(() {
          _editingCommentId = null;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_ensureCommentVisible(editingId));
        });

        _showSnack('댓글을 수정했어요.');
      } else {
        final submitFuture = c.reply(
          parentCommentId: _rootCommentId,
          text: text,
        );

        unawaited(_scrollToBottomAfterLocalReplyInsert());

        final createdReply = await submitFuture;

        await minimumSubmitFuture;

        final replyId = createdReply.id;
        _didSubmit = true;

        if (!mounted) return;

        setState(() {
          _latestSubmittedReplyId = replyId.trim().isEmpty ? null : replyId;
        });

        if (replyId.trim().isNotEmpty) {
          unawaited(_forceRevealNewReply(replyId));
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            _scrollToBottom(animated: false);
          });
        }

        _showSnack('답글을 등록했어요.');
      }
    } catch (e) {
      await minimumSubmitFuture;

      _inputCtrl.text = text;
      _inputCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _inputCtrl.text.length),
      );
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        _isSubmittingLocal.value = false;
      }
    }
  }

  Future<void> _startEdit(Comment comment) async {
    final allowed = await _ensureThreadWriteAllowed(
      isEditing: true,
    );
    if (!allowed) return;

    if (comment.isDeleted || comment.isHiddenFromPublic) return;

    _inputCtrl.text = comment.text;
    _inputCtrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputCtrl.text.length),
    );

    setState(() {
      _editingCommentId = comment.id;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _focusNode.requestFocus();
      unawaited(_ensureCommentVisible(comment.id));
    });
  }

  void _cancelEdit() {
    _dismissKeyboard();

    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _editingCommentId = null;
      });
      _inputCtrl.clear();
    });
  }

  Future<void> _delete(Comment comment) async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 댓글 삭제를 이용할 수 있어요.',
    );
    if (!allowed) return;

    final ok = await _showConfirmDialog(
      title: '댓글 삭제',
      message: '이 댓글을 삭제할까요?',
      confirmText: '삭제',
      isDestructive: true,
    );

    if (!ok) return;

    _dismissKeyboard();

    try {
      await c.delete(comment.id);
      _showSnack('댓글을 삭제했어요.');

      if (_editingCommentId == comment.id) {
        _cancelEdit();
      }
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _report(Comment comment) async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 신고를 이용할 수 있어요.',
    );
    if (!allowed) return;

    final reason = await _showReasonPicker(title: '댓글 신고');
    if (reason == null) return;

    _dismissKeyboard();

    try {
      await c.report(
        commentId: comment.id,
        reason: reason,
      );
      _showSnack('댓글을 신고했어요.');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggleLike(Comment comment) async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 좋아요를 이용할 수 있어요.',
    );
    if (!allowed) return;

    try {
      await c.toggleLike(comment.id);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onLockedInputTap() async {
    _dismissKeyboard();
    _showSnack(
      _permissionMessage(
        isEditing: _editingCommentId != null,
      ),
    );
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

  Future<String?> _showReasonPicker({required String title}) async {
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

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    final isEditing = _editingCommentId != null;

    final bottomMargin = bottomInset > 0
        ? bottomInset + (isEditing ? 110 : 68)
        : safeBottom + 12;

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
        duration: const Duration(milliseconds: 1300),
        behavior: SnackBarBehavior.floating,
        backgroundColor: kThreadSnackBg,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  void _scrollToTargetOrBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;

      final focusId = _focusCommentId;
      if (focusId != null && focusId.isNotEmpty) {
        unawaited(_ensureCommentVisible(focusId));
        return;
      }

      _scrollToBottom(animated: false);
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

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          title: const Text('답글'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (_isPopping) return;
              _isPopping = true;
              _dismissKeyboard();
              Get.back(result: _didSubmit);
            },
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                bottom: _editingCommentId == null ? 56 : 98,
                child: _ThreadBodyList(
                  controller: c,
                  scrollController: _scrollController,
                  rootCommentId: _rootCommentId,
                  latestSubmittedReplyId: _latestSubmittedReplyId,
                  timeLabel: _timeLabel,
                  itemKeyFor: _keyForComment,
                  onEdit: _startEdit,
                  onDelete: _delete,
                  onReport: _report,
                  onToggleLike: _toggleLike,
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Obx(() {
                  if (_isSubmittingLocal.value) {
                    return const SizedBox.shrink();
                  }

                  final isEditing = _editingCommentId != null;
                  final canWrite = c.canWriteCurrentPostComment;

                  return _KeyboardInsetFollower(
                    child: _BottomReplyBar(
                      controller: _inputCtrl,
                      focusNode: _focusNode,
                      isSubmitting: _isSubmittingLocal,
                      isEditing: isEditing,
                      canWriteReply: canWrite,
                      lockedHintText: _lockedHintText(isEditing: isEditing),
                      onLockedTap: _onLockedInputTap,
                      onCancelEdit: _cancelEdit,
                      onSubmit: _submit,
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Obx(() {
                  if (!_isSubmittingLocal.value) {
                    return const SizedBox.shrink();
                  }

                  return const _ThreadSubmitOverlay();
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KeyboardInsetFollower extends StatelessWidget {
  final Widget child;

  const _KeyboardInsetFollower({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return RepaintBoundary(
      child: Padding(
        padding: EdgeInsets.only(bottom: bottom),
        child: child,
      ),
    );
  }
}

class _ThreadSubmitOverlay extends StatelessWidget {
  const _ThreadSubmitOverlay();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      ignoring: true,
      child: Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: kThreadSubmitAccent,
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
  final String? latestSubmittedReplyId;
  final String Function(DateTime) timeLabel;
  final GlobalKey Function(String commentId) itemKeyFor;
  final Future<void> Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;
  final Future<void> Function(Comment comment) onToggleLike;

  const _ThreadBodyList({
    required this.controller,
    required this.scrollController,
    required this.rootCommentId,
    required this.latestSubmittedReplyId,
    required this.timeLabel,
    required this.itemKeyFor,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomScrollView(
        controller: scrollController,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              key: itemKeyFor(rootCommentId),
              child: _RootCommentCard(
                rootId: rootCommentId,
                controller: controller,
                timeLabel: timeLabel,
                onEdit: onEdit,
                onDelete: onDelete,
                onReport: onReport,
                onToggleLike: onToggleLike,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: _RepliesHeader(
              controller: controller,
              rootCommentId: rootCommentId,
            ),
          ),
          _RepliesSliverList(
            controller: controller,
            rootCommentId: rootCommentId,
            latestSubmittedReplyId: latestSubmittedReplyId,
            timeLabel: timeLabel,
            itemKeyFor: itemKeyFor,
            onEdit: onEdit,
            onDelete: onDelete,
            onReport: onReport,
            onToggleLike: onToggleLike,
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
      controller.comments.length;

      final count = controller.replyCountOf(rootCommentId);

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 4),
        child: Text(
          '답글 $count',
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

class _RepliesSliverList extends StatelessWidget {
  final CommentController controller;
  final String rootCommentId;
  final String? latestSubmittedReplyId;
  final String Function(DateTime) timeLabel;
  final GlobalKey Function(String commentId) itemKeyFor;
  final Future<void> Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;
  final Future<void> Function(Comment comment) onToggleLike;

  const _RepliesSliverList({
    required this.controller,
    required this.rootCommentId,
    required this.latestSubmittedReplyId,
    required this.timeLabel,
    required this.itemKeyFor,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.comments.length;

      final allReplies = controller.repliesOf(rootCommentId);
      final pinnedId = latestSubmittedReplyId?.trim();

      final replies = <Comment>[
        ...allReplies,
      ];

      if (pinnedId != null && pinnedId.isNotEmpty) {
        final pinnedReply = controller.commentById(pinnedId);
        final shouldAppendPinnedReply = pinnedReply != null &&
            pinnedReply.parentId == rootCommentId &&
            !replies.any((reply) => reply.id == pinnedReply.id);

        if (shouldAppendPinnedReply) {
          replies.add(pinnedReply);
        }
      }

      if (replies.isEmpty) {
        return const SliverToBoxAdapter(
          child: SizedBox(height: 8),
        );
      }

      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final reply = replies[index];

            return Container(
              key: itemKeyFor(reply.id),
              child: RepaintBoundary(
                child: _ReplyCommentCard(
                  replyId: reply.id,
                  controller: controller,
                  timeLabel: timeLabel,
                  onEdit: onEdit,
                  onDelete: onDelete,
                  onReport: onReport,
                  onToggleLike: onToggleLike,
                ),
              ),
            );
          },
          childCount: replies.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          addSemanticIndexes: false,
        ),
      );
    });
  }
}

class _RootCommentCard extends StatelessWidget {
  final String rootId;
  final CommentController controller;
  final String Function(DateTime) timeLabel;
  final Future<void> Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;
  final Future<void> Function(Comment comment) onToggleLike;

  const _RootCommentCard({
    required this.rootId,
    required this.controller,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.comments.length;

      final root = controller.commentById(rootId);
      if (root == null) return const SizedBox.shrink();

      return CommunityCommentCard(
        comment: root,
        depth: 0,
        currentUserId: controller.currentUserId,
        timeLabel: timeLabel,
        onReplyTap: (_) async {},
        onEditTap: onEdit,
        onDeleteTap: onDelete,
        onReportTap: onReport,
        onToggleLikeTap: onToggleLike,
        replyLabel: '답글',
        showReplyAction: false,
        denseMeta: true,
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFCFCFD),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE7E9EE)),
        ),
        bodyLeftInset: 0,
        actionLeftInset: 0,
        replyArrowPadding: const EdgeInsets.only(right: 5),
        replyArrowSize: 14,
        actionSpacing: 12,
        actionRunSpacing: 6,
        moreIconSize: 16,
        likeIconSize: 14,
        likeTextSize: 12,
        moreIconColor: const Color(0xFF6B7280),
        deletedText: '삭제된 댓글입니다.',
        reportBlindedText: '신고에 의해 블라인드된 댓글입니다.',
        adminHiddenText: '관리자에 의해 숨김 처리된 댓글입니다.',
        textStyle: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        blockedTextStyle: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w500,
        ),
        actionTopSpacing: 8,
      );
    });
  }
}

class _ReplyCommentCard extends StatelessWidget {
  final String replyId;
  final CommentController controller;
  final String Function(DateTime) timeLabel;
  final Future<void> Function(Comment comment) onEdit;
  final Future<void> Function(Comment comment) onDelete;
  final Future<void> Function(Comment comment) onReport;
  final Future<void> Function(Comment comment) onToggleLike;

  const _ReplyCommentCard({
    required this.replyId,
    required this.controller,
    required this.timeLabel,
    required this.onEdit,
    required this.onDelete,
    required this.onReport,
    required this.onToggleLike,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      controller.comments.length;

      final reply = controller.commentById(replyId);
      if (reply == null) return const SizedBox.shrink();

      return CommunityCommentCard(
        comment: reply,
        depth: 1,
        currentUserId: controller.currentUserId,
        timeLabel: timeLabel,
        onReplyTap: (_) async {},
        onEditTap: onEdit,
        onDeleteTap: onDelete,
        onReportTap: onReport,
        onToggleLikeTap: onToggleLike,
        replyLabel: '답글 보기',
        showReplyAction: false,
        denseMeta: true,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 9),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Color(0xFFF1F3F5)),
          ),
        ),
        bodyLeftInset: 19,
        actionLeftInset: 19,
        replyArrowPadding: const EdgeInsets.only(right: 5),
        replyArrowSize: 14,
        actionSpacing: 12,
        actionRunSpacing: 6,
        moreIconSize: 16,
        likeIconSize: 14,
        likeTextSize: 12,
        moreIconColor: Color(0xFF6B7280),
        deletedText: '삭제된 댓글입니다.',
        reportBlindedText: '신고에 의해 블라인드된 댓글입니다.',
        adminHiddenText: '관리자에 의해 숨김 처리된 댓글입니다.',
        textStyle: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Color(0xFF1F2937),
          fontWeight: FontWeight.w500,
        ),
        blockedTextStyle: const TextStyle(
          fontSize: 14,
          height: 1.45,
          color: Color(0xFF9CA3AF),
          fontWeight: FontWeight.w500,
        ),
        actionTopSpacing: 7,
      );
    });
  }
}

class _BottomReplyBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final RxBool isSubmitting;
  final bool isEditing;
  final bool canWriteReply;
  final String lockedHintText;
  final Future<void> Function() onLockedTap;
  final VoidCallback onCancelEdit;
  final Future<void> Function() onSubmit;

  const _BottomReplyBar({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.isEditing,
    required this.canWriteReply,
    required this.lockedHintText,
    required this.onLockedTap,
    required this.onCancelEdit,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.viewPaddingOf(context).bottom;
    final hintText = canWriteReply
        ? isEditing
            ? '댓글을 수정하세요.'
            : '답글을 입력하세요.'
        : lockedHintText;

    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        elevation: 8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, 14, 8 + safeBottom),
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
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                        readOnly: !canWriteReply,
                        enableInteractiveSelection: canWriteReply,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(
                            CommentController.maxCommentLength,
                          ),
                        ],
                        maxLength: CommentController.maxCommentLength,
                        maxLengthEnforcement: MaxLengthEnforcement.enforced,
                        buildCounter: (
                          context, {
                          required currentLength,
                          required isFocused,
                          required maxLength,
                        }) {
                          return null;
                        },
                        minLines: 1,
                        maxLines: 3,
                        textInputAction: TextInputAction.send,
                        onTap: () {
                          if (canWriteReply) return;
                          onLockedTap();
                        },
                        onSubmitted: (_) {
                          if (!canWriteReply) {
                            onLockedTap();
                            return;
                          }
                          onSubmit();
                        },
                        decoration: InputDecoration(
                          hintText: hintText,
                          hintStyle: TextStyle(
                            color: canWriteReply
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFFB6A79F),
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
                        style: TextStyle(
                          color: canWriteReply
                              ? const Color(0xFF111111)
                              : const Color(0xFF9CA3AF),
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Obx(() {
                    final enabled = !isSubmitting.value && canWriteReply;

                    return TextButton(
                      onPressed: enabled ? onSubmit : null,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 8,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
    );
  }
}
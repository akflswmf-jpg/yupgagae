import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/controller/post_detail_controller.dart';
import 'package:yupgagae/features/community/domain/comment.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/post_detail_body.dart';
import 'package:yupgagae/features/my_store/controller/my_store_controller.dart';
import 'package:yupgagae/features/my_store/domain/blocked_user_item.dart';
import 'package:yupgagae/routes/app_routes.dart';

const Color kCommentAccentDark = Color(0xFF875646);
const Color kCommentHint = Color(0xFF9CA3AF);
const Color kCommentText = Color(0xFF111111);
const Color kYupgagaeSnackBg = Color(0xFF875646);

const Duration kCommentSubmitMinimumDuration = Duration(milliseconds: 1000);

class PostDetailScreen extends StatefulWidget {
  final String postId;

  const PostDetailScreen({
    super.key,
    required this.postId,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PostDetailController c;
  late final CommentController commentC;
  late final ScrollController _scrollController;
  late final MyStoreController myStoreC;

  final TextEditingController _commentCtrl = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();

  final RxBool _isSubmittingLocal = false.obs;

  bool _bootLoading = true;
  String? _bootError;

  bool _commentBootStarted = false;
  bool _commentBootDone = false;

  String get _postId => widget.postId.trim();

  @override
  void initState() {
    super.initState();

    c = Get.find<PostDetailController>();
    commentC = Get.find<CommentController>();
    myStoreC = Get.find<MyStoreController>();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _boot();
    });
  }

  Future<void> _boot() async {
    if (_postId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _bootLoading = false;
        _bootError = 'postId required';
      });
      return;
    }

    try {
      await c.initialize(_postId);

      if (!mounted) return;
      setState(() {
        _bootLoading = false;
        _bootError = null;
      });

      unawaited(_startCommentBoot());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootLoading = false;
        _bootError = e.toString();
      });
    }
  }

  Future<void> _startCommentBoot() async {
    if (_commentBootStarted) return;
    _commentBootStarted = true;

    try {
      await commentC.initialize(_postId);
    } catch (_) {
    } finally {
      if (!mounted) return;
      _commentBootDone = true;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _commentFocusNode.unfocus();
    _scrollController.dispose();
    _commentCtrl.dispose();
    _commentFocusNode.dispose();
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
    _commentFocusNode.unfocus();
  }

  Future<void> _settleKeyboard() async {
    _dismissKeyboard();
    await Future.delayed(const Duration(milliseconds: 180));
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

  Future<void> _scrollToBottomAfterCommentInsert() async {
    for (var i = 0; i < 4; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      _scrollToBottom(animated: false);
    }
  }

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    if (_isSubmittingLocal.value) return;
    if (commentC.isSubmitting.value) return;
    if (!_commentBootDone) return;

    _isSubmittingLocal.value = true;
    _commentCtrl.clear();
    _dismissKeyboardForSubmit();

    final minimumSubmitFuture =
        Future<void>.delayed(kCommentSubmitMinimumDuration);

    try {
      await _paintSubmitOverlayBeforeWork();

      final createdComment = await commentC.add(text);

      await minimumSubmitFuture;

      c.applyUpdatedCommentCount(commentC.activeCommentCount);

      if (!mounted) return;

      if (createdComment.id.trim().isNotEmpty) {
        unawaited(_scrollToBottomAfterCommentInsert());
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToBottom(animated: false);
        });
      }

      _showSnack('댓글을 등록했어요.');
    } catch (e) {
      await minimumSubmitFuture;

      _commentCtrl.text = text;
      _commentCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _commentCtrl.text.length),
      );
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        _isSubmittingLocal.value = false;
      }
    }
  }

  Future<void> _openThread({
    required String commentId,
    String? editingCommentId,
  }) async {
    final rootId = commentC.resolveReplyRootId(commentId);

    await _settleKeyboard();

    final result = await Get.toNamed(
      AppRoutes.commentThread,
      arguments: {
        'postId': _postId,
        'rootCommentId': rootId,
        'focusCommentId': commentId,
        'editingCommentId': editingCommentId,
      },
    );

    await _settleKeyboard();

    if (!mounted) return;

    if (result == true) {
      c.applyUpdatedCommentCount(commentC.activeCommentCount);
      unawaited(c.refreshPost());

      unawaited(_scrollToBottomAfterCommentInsert());
    }
  }

  Future<void> _onReplyTap(String commentId) async {
    await _openThread(commentId: commentId);
  }

  Future<void> _onEditTap(String commentId, String currentText) async {
    await _openThread(
      commentId: commentId,
      editingCommentId: commentId,
    );
  }

  Future<void> _onDelete(Comment comment) async {
    final ok = await _showConfirmDialog(
      title: '댓글 삭제',
      message: '이 댓글을 삭제할까요?',
      confirmText: '삭제',
      isDestructive: true,
    );

    if (!ok) return;

    await _settleKeyboard();

    try {
      await commentC.delete(comment.id);
      c.applyUpdatedCommentCount(commentC.activeCommentCount);
      _showSnack('댓글을 삭제했어요.');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _onReport(Comment comment) async {
    final reason = await _showReasonPicker(title: '댓글 신고');
    if (reason == null) return;

    await _settleKeyboard();

    try {
      await commentC.report(
        commentId: comment.id,
        reason: reason,
      );
      _showSnack('댓글을 신고했어요.');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _onReportPost() async {
    final reason = await _showReasonPicker(title: '게시글 신고');
    if (reason == null) return;

    await _settleKeyboard();

    try {
      await c.reportThisPost(reason);
      _showSnack('게시글을 신고했어요.');
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _onBlockPostAuthor() async {
    final post = c.post.value;
    if (post == null) return;

    if (post.authorId.trim().isEmpty) {
      _showSnack('차단할 사용자를 찾을 수 없어요.');
      return;
    }

    final alreadyBlocked = myStoreC.blockedUsers.any(
      (e) => e.userId == post.authorId,
    );

    if (alreadyBlocked) {
      _showSnack('이미 차단한 사용자예요.');
      return;
    }

    final ok = await _showConfirmDialog(
      title: '사용자 차단',
      message:
          '${post.authorLabel} 사용자를 차단할까요?\n이 사용자의 게시글과 댓글은 보이지 않게 됩니다.',
      confirmText: '차단',
      isDestructive: true,
    );

    if (!ok) return;

    await _settleKeyboard();

    try {
      await myStoreC.blockUser(
        BlockedUserItem(
          userId: post.authorId,
          nickname: post.authorLabel.trim().isEmpty ? '익명' : post.authorLabel,
          industry: post.industryId,
          region: post.locationLabel,
          blockedAt: DateTime.now(),
        ),
      );

      if (!mounted) return;
      _showSnack('사용자를 차단했어요.');
      Get.back(result: true);
    } catch (e) {
      _showSnack(e.toString());
    }
  }

  Future<void> _onDeletePost() async {
    final ok = await _showConfirmDialog(
      title: '게시글 삭제',
      message: '이 게시글을 삭제할까요?',
      confirmText: '삭제',
      isDestructive: true,
    );
    if (!ok) return;

    await _settleKeyboard();

    final deleted = await c.deleteThisPost();
    if (!mounted) return;

    if (deleted) {
      Get.back(result: true);
      return;
    }

    _showSnack(c.error.value ?? '게시글 삭제에 실패했어요.');
  }

  Future<void> _onEditPost() async {
    final post = c.post.value;
    if (post == null) return;

    await _settleKeyboard();

    final result = await Get.toNamed(
      AppRoutes.writePost,
      arguments: {
        'postId': post.id,
        'boardType': post.boardType.key,
      },
    );

    if (result == true) {
      await c.refreshPost();
      await commentC.load();
      if (!mounted) return;
      _showSnack('게시글을 수정했어요.');
    }
  }

  Future<void> _onToggleSold() async {
    final post = c.post.value;
    if (post == null) return;
    if (post.boardType != BoardType.used) return;

    final ok = await _showConfirmDialog(
      title: post.isSold ? '거래완료 해제' : '거래완료 처리',
      message: post.isSold
          ? '거래완료 상태를 해제할까요?'
          : '이 게시글을 거래완료 처리할까요?',
      confirmText: post.isSold ? '해제' : '완료',
    );
    if (!ok) return;

    await _settleKeyboard();

    try {
      final updated = await c.toggleSold();
      if (!mounted) return;

      _showSnack(
        updated.isSold ? '거래완료 처리됐어요.' : '거래완료가 해제됐어요.',
      );
    } catch (e) {
      _showSnack(e.toString());
    }
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
        backgroundColor: kYupgagaeSnackBg,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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

  List<Widget> _buildOwnerActions(Post post) {
    final children = <Widget>[];

    if (post.boardType == BoardType.used) {
      children.add(
        Obx(() {
          final toggling = c.isTogglingSold.value;
          final sold = c.post.value?.isSold ?? post.isSold;

          return IconButton(
            tooltip: sold ? '거래완료 해제' : '거래완료 처리',
            onPressed: toggling ? null : _onToggleSold,
            icon: Icon(
              sold ? Icons.check_circle : Icons.check_circle_outline,
              color: sold
                  ? const Color(0xFFA56E5F)
                  : const Color(0xFF111111),
            ),
          );
        }),
      );
    }

    children.addAll([
      IconButton(
        tooltip: '수정',
        onPressed: _onEditPost,
        icon: const Icon(
          Icons.edit_outlined,
          color: Color(0xFF111111),
        ),
      ),
      IconButton(
        tooltip: '삭제',
        onPressed: _onDeletePost,
        icon: const Icon(
          Icons.delete_outline,
          color: Color(0xFF111111),
        ),
      ),
    ]);

    return children;
  }

  List<Widget> _buildGuestActions() {
    return [
      IconButton(
        tooltip: '신고',
        onPressed: _onReportPost,
        icon: const Icon(
          Icons.flag_outlined,
          color: Color(0xFF111111),
        ),
      ),
      IconButton(
        tooltip: '차단',
        onPressed: _onBlockPostAuthor,
        icon: const Icon(
          Icons.block_outlined,
          color: Color(0xFFE5484D),
        ),
      ),
    ];
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        '게시물',
        style: TextStyle(
          fontWeight: FontWeight.w800,
          color: Color(0xFF111111),
        ),
      ),
      backgroundColor: Colors.white,
      elevation: 0,
      actions: [
        Obx(() {
          final post = c.post.value;
          if (post == null) return const SizedBox.shrink();

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: c.isOwner ? _buildOwnerActions(post) : _buildGuestActions(),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_bootLoading) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_bootError != null) {
      return Scaffold(
        appBar: _buildAppBar(),
        body: Center(child: Text(_bootError!)),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _dismissKeyboard,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        appBar: _buildAppBar(),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Stack(
            children: [
              Positioned.fill(
                bottom: 56,
                child: RepaintBoundary(
                  child: Stack(
                    children: [
                      PostDetailBody(
                        c: c,
                        commentC: commentC,
                        scrollController: _scrollController,
                        timeLabel: _timeLabel,
                        onCommentTap: () {
                          if (!_commentBootDone) return;
                          if (_isSubmittingLocal.value) return;

                          _commentFocusNode.requestFocus();
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!mounted) return;
                            _scrollToBottom(animated: false);
                          });
                        },
                        onReplyTap: _onReplyTap,
                        onEditTap: _onEditTap,
                        activeReplyId: null,
                        activeEditingId: null,
                        onDelete: _onDelete,
                        onReport: _onReport,
                        onLikeTap: c.toggleLike,
                      ),
                      if (!_commentBootDone)
                        const Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            minHeight: 2,
                            color: kCommentAccentDark,
                            backgroundColor: Color(0xFFEDE7E3),
                          ),
                        ),
                    ],
                  ),
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

                  return _KeyboardInsetFollower(
                    child: _BottomCommentBar(
                      controller: _commentCtrl,
                      focusNode: _commentFocusNode,
                      isSubmitting: _isSubmittingLocal,
                      isCommentReady: _commentBootDone,
                      onSubmit: _submitComment,
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Obx(() {
                  if (!_isSubmittingLocal.value) {
                    return const SizedBox.shrink();
                  }

                  return const _CommentSubmitOverlay();
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

class _CommentSubmitOverlay extends StatelessWidget {
  const _CommentSubmitOverlay();

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
            color: kCommentAccentDark,
          ),
        ),
      ),
    );
  }
}

class _BottomCommentBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final RxBool isSubmitting;
  final bool isCommentReady;
  final Future<void> Function() onSubmit;

  const _BottomCommentBar({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.isCommentReady,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Material(
        color: Colors.white,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 38),
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
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
                      maxLines: 2,
                      enabled: true,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) {
                        if (!isCommentReady) return;
                        onSubmit();
                      },
                      decoration: const InputDecoration(
                        hintText: '댓글을 입력하세요.',
                        hintStyle: TextStyle(
                          color: kCommentHint,
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
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                      ),
                      style: const TextStyle(
                        color: kCommentText,
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Obx(() {
                  final enabled = !isSubmitting.value && isCommentReady;

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
                      '등록',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: enabled
                            ? kCommentAccentDark
                            : const Color(0xFFB6A79F),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
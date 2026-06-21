import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_action_guard.dart';
import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
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

enum _PostMoreAction {
  report,
  block,
}

class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Post? initialPost;

  const PostDetailScreen({
    super.key,
    required this.postId,
    this.initialPost,
  });

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  late final PostDetailController c;
  late final CommentController commentC;
  late final ScrollController _scrollController;
  late final MyStoreController myStoreC;

  AuthController? authC;

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

    if (Get.isRegistered<AuthController>()) {
      authC = Get.find<AuthController>();
    }

    final initialPost = widget.initialPost;
    final hasUsableInitialPost =
        initialPost != null && initialPost.id.trim() == _postId;

    if (hasUsableInitialPost) {
      c.applyInitialPost(initialPost!);
      _bootLoading = false;
      _bootError = null;
    }

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

    final initialPost = widget.initialPost;
    final hasUsableInitialPost =
        initialPost != null && initialPost.id.trim() == _postId;

    try {
      if (hasUsableInitialPost) {
        if (!c.isBlockedAuthorPost && !_isCurrentOwnerPostLocked()) {
          unawaited(_startCommentBootAfterFirstPaint());
        }

        unawaited(_refreshPostAfterFirstPaint(initialPost!));
        return;
      }

      await c.initialize(_postId);

      if (!mounted) return;
      setState(() {
        _bootLoading = false;
        _bootError = null;
      });

      if (!c.isBlockedAuthorPost && !_isCurrentOwnerPostLocked()) {
        unawaited(_startCommentBootAfterFirstPaint());
      }
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
    if (c.isBlockedAuthorPost) return;

    _commentBootStarted = true;

    try {
      await commentC.initialize(
        _postId,
        permissionPost: c.post.value,
      );
    } catch (_) {
    } finally {
      if (!mounted) return;
      _commentBootDone = true;
      setState(() {});
    }
  }

  Future<void> _startCommentBootAfterFirstPaint() async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    if (!mounted) return;
    if (c.isBlockedAuthorPost) return;

    await _startCommentBoot();
  }

  Future<void> _refreshPostAfterFirstPaint(Post initialPost) async {
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    await c.initialize(
      _postId,
      initialPost: initialPost,
    );

    if (!mounted) return;
    if (!c.isBlockedAuthorPost && !_isCurrentOwnerPostLocked()) {
      unawaited(_startCommentBootAfterFirstPaint());
    }
  }

  bool _isCurrentOwnerPostLocked() {
    final post = c.post.value;
    if (post == null) return false;
    return _isOwnerPostLocked(post);
  }

  bool _isOwnerPostLocked(Post post) {
    if (post.boardType != BoardType.owner) return false;

    final user = authC?.currentUser.value;

    return !PermissionPolicy.canWriteOwnerBoardComment(user);
  }

  bool _canWriteCommentForCurrentPost() {
    if (c.isBlockedAuthorPost) return false;

    final post = c.post.value;
    final user = authC?.currentUser.value;

    if (post == null) {
      return PermissionPolicy.canWriteComment(user);
    }

    switch (post.boardType) {
      case BoardType.owner:
        return PermissionPolicy.canWriteOwnerBoardComment(user);
      case BoardType.free:
      case BoardType.used:
        return PermissionPolicy.canWriteComment(user);
    }
  }

  String _commentBlockedMessageForCurrentPost() {
    if (c.isBlockedAuthorPost) {
      return '차단한 사용자의 글입니다.';
    }

    final post = c.post.value;
    final user = authC?.currentUser.value;

    if (post == null) {
      return PermissionPolicy.writeCommentBlockedMessage(
        user: user,
        boardType: BoardType.free,
      );
    }

    return PermissionPolicy.writeCommentBlockedMessage(
      user: user,
      boardType: post.boardType,
    );
  }

  String _commentLockedHintForCurrentPost() {
    if (c.isBlockedAuthorPost) {
      return '차단한 사용자의 글입니다.';
    }

    final post = c.post.value;

    if (post?.boardType == BoardType.owner) {
      return '사업자 인증 후 댓글 입력이 가능합니다.';
    }

    return '본인인증 후 댓글 입력이 가능합니다.';
  }

  bool _isCurrentAuthPostAuthor(Post post) {
    final userId = authC?.currentUser.value?.userId.trim();
    if (userId == null || userId.isEmpty) return false;

    return post.authorId == userId;
  }

  Future<bool> _ensureParticipation({
    required String message,
  }) {
    return AuthActionGuard.ensureParticipationAllowed(
      title: '로그인이 필요한 기능입니다',
      message: message,
    );
  }

  void _goMyStoreTab() {
    Get.offAllNamed(
      AppRoutes.root,
      arguments: const {
        'initialIndex': 3,
      },
    );
  }

  void _goBackFromBlockedPost() {
    Get.back(result: true);
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
    if (!_canWriteCommentForCurrentPost()) {
      _showSnack(_commentBlockedMessageForCurrentPost());
      return;
    }

    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    if (_isSubmittingLocal.value) return;
    if (commentC.isSubmitting.value) return;
    if (!_commentBootDone) return;

    final allowed = await _ensureParticipation(
      message: '로그인 후 댓글을 이용할 수 있어요.',
    );
    if (!allowed) return;

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
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
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
    if (c.isBlockedAuthorPost) {
      _showSnack('차단한 사용자의 글입니다.');
      return;
    }

    if (_isCurrentOwnerPostLocked()) {
      _showSnack('사업자 인증 후 댓글을 확인할 수 있습니다.');
      return;
    }

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
    final allowed = await _ensureParticipation(
      message: '로그인 후 댓글 수정을 이용할 수 있어요.',
    );
    if (!allowed) return;

    await _openThread(
      commentId: commentId,
      editingCommentId: commentId,
    );
  }

  Future<void> _onDelete(Comment comment) async {
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

    await _settleKeyboard();

    try {
      await commentC.delete(comment.id);
      c.applyUpdatedCommentCount(commentC.activeCommentCount);
      _showSnack('댓글을 삭제했어요.');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onReport(Comment comment) async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 신고를 이용할 수 있어요.',
    );
    if (!allowed) return;

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
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onReportPost() async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 신고를 이용할 수 있어요.',
    );
    if (!allowed) return;

    final reason = await _showReasonPicker(title: '게시글 신고');
    if (reason == null) return;

    await _settleKeyboard();

    try {
      await c.reportThisPost(reason);
      _showSnack('게시글을 신고했어요.');
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onBlockPostAuthor() async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 차단을 이용할 수 있어요.',
    );
    if (!allowed) return;

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
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onDeletePost() async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 게시글 삭제를 이용할 수 있어요.',
    );
    if (!allowed) return;

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
    final allowed = await _ensureParticipation(
      message: '로그인 후 게시글 수정을 이용할 수 있어요.',
    );
    if (!allowed) return;

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
    final allowed = await _ensureParticipation(
      message: '로그인 후 거래완료 처리를 이용할 수 있어요.',
    );
    if (!allowed) return;

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
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onToggleLike() async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 좋아요를 이용할 수 있어요.',
    );
    if (!allowed) return;

    try {
      await c.toggleLike();
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onCommentLike(Comment comment) async {
    final allowed = await _ensureParticipation(
      message: '로그인 후 좋아요를 이용할 수 있어요.',
    );
    if (!allowed) return;

    try {
      await commentC.toggleLike(comment.id);
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _onCommentInputTap() async {
    if (c.isBlockedAuthorPost) {
      _showSnack('차단한 사용자의 글입니다.');
      return;
    }

    if (!_commentBootDone) return;
    if (_isSubmittingLocal.value) return;

    if (!_canWriteCommentForCurrentPost()) {
      _showSnack(_commentBlockedMessageForCurrentPost());
      return;
    }

    final allowed = await _ensureParticipation(
      message: '로그인 후 댓글을 이용할 수 있어요.',
    );
    if (!allowed) return;

    _commentFocusNode.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom(animated: false);
    });
  }

  Future<void> _onLockedCommentInputTap() async {
    if (c.isBlockedAuthorPost) {
      _showSnack('차단한 사용자의 글입니다.');
      return;
    }

    if (!_commentBootDone) return;
    if (_isSubmittingLocal.value) return;

    _dismissKeyboard();
    _showSnack(_commentBlockedMessageForCurrentPost());
  }

  Future<void> _handlePostMoreAction(_PostMoreAction action) async {
    switch (action) {
      case _PostMoreAction.report:
        await _onReportPost();
        return;
      case _PostMoreAction.block:
        await _onBlockPostAuthor();
        return;
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;

    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final safeBottom = MediaQuery.paddingOf(context).bottom;

    final bottomMargin = bottomInset > 0 ? bottomInset + 68 : safeBottom + 12;

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
        backgroundColor: kYupgagaeSnackBg,
        margin: EdgeInsets.fromLTRB(16, 0, 16, bottomMargin),
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
              color: sold ? const Color(0xFFA56E5F) : const Color(0xFF111111),
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
      PopupMenuButton<_PostMoreAction>(
        tooltip: '더보기',
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        position: PopupMenuPosition.under,
        onSelected: _handlePostMoreAction,
        icon: const Icon(
          Icons.more_vert_rounded,
          color: Color(0xFF111111),
        ),
        itemBuilder: (context) {
          return const [
            PopupMenuItem<_PostMoreAction>(
              value: _PostMoreAction.report,
              child: Row(
                children: [
                  Icon(
                    Icons.crisis_alert_rounded,
                    size: 20,
                    color: Color(0xFF111111),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '신고하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111111),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem<_PostMoreAction>(
              value: _PostMoreAction.block,
              child: Row(
                children: [
                  Icon(
                    Icons.person_off_rounded,
                    size: 20,
                    color: Color(0xFFE5484D),
                  ),
                  SizedBox(width: 10),
                  Text(
                    '작성자 차단하기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE5484D),
                    ),
                  ),
                ],
              ),
            ),
          ];
        },
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
          if (c.isBlockedAuthorPost) {
            return const SizedBox.shrink();
          }

          final post = c.post.value;
          if (post == null) return const SizedBox.shrink();

          if (_isOwnerPostLocked(post)) {
            return const SizedBox.shrink();
          }

          final isAuthor = _isCurrentAuthPostAuthor(post);

          return Row(
            mainAxisSize: MainAxisSize.min,
            children: isAuthor ? _buildOwnerActions(post) : _buildGuestActions(),
          );
        }),
      ],
    );
  }

  Widget _buildBlockedAuthorBody() {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.person_off_rounded,
                  size: 27,
                  color: Color(0xFFE5484D),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '차단한 사용자의 글입니다',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '이 사용자의 게시글과 댓글은\n내 화면에 표시되지 않습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _goBackFromBlockedPost,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF111111),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '목록으로 돌아가기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLockedOwnerBody() {
    return SafeArea(
      top: false,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6EEEA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 27,
                  color: Color(0xFFA56E5F),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                '사업자 인증 후 볼 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF111111),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '사장님게시판의 본문, 이미지, 댓글은\n사업자 인증을 완료한 사용자만 확인할 수 있습니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF6B7280),
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _goMyStoreTab,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFA56E5F),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    '인증하러 가기',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: TextButton(
                  onPressed: () => Get.back(result: false),
                  child: const Text(
                    '목록으로 돌아가기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUnlockedDetailBody() {
    return SafeArea(
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
                    onCommentTap: _onCommentInputTap,
                    onReplyTap: _onReplyTap,
                    onEditTap: _onEditTap,
                    activeReplyId: null,
                    activeEditingId: null,
                    onDelete: _onDelete,
                    onReport: _onReport,
                    onLikeTap: _onToggleLike,
                    onCommentLikeTap: _onCommentLike,
                  ),
                  if (!_commentBootDone)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SizedBox.shrink(),
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

              final canWrite = _canWriteCommentForCurrentPost();

              return _KeyboardInsetFollower(
                child: _BottomCommentBar(
                  controller: _commentCtrl,
                  focusNode: _commentFocusNode,
                  isSubmitting: _isSubmittingLocal,
                  isCommentReady: _commentBootDone,
                  canWriteComment: canWrite,
                  lockedHintText: _commentLockedHintForCurrentPost(),
                  onLockedTap: _onLockedCommentInputTap,
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

    return Obx(() {
      final blocked = c.isBlockedAuthorPost;
      final post = c.post.value;
      final locked = !blocked && post != null && _isOwnerPostLocked(post);

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _dismissKeyboard,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          appBar: _buildAppBar(),
          body: blocked
              ? _buildBlockedAuthorBody()
              : locked
                  ? _buildLockedOwnerBody()
                  : _buildUnlockedDetailBody(),
        ),
      );
    });
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
  final bool canWriteComment;
  final String lockedHintText;
  final Future<void> Function() onLockedTap;
  final Future<void> Function() onSubmit;

  const _BottomCommentBar({
    required this.controller,
    required this.focusNode,
    required this.isSubmitting,
    required this.isCommentReady,
    required this.canWriteComment,
    required this.lockedHintText,
    required this.onLockedTap,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final hintText = canWriteComment ? '댓글을 입력하세요.' : lockedHintText;

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
                      readOnly: !canWriteComment,
                      enableInteractiveSelection: canWriteComment,
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
                      onTap: () {
                        if (canWriteComment) return;
                        onLockedTap();
                      },
                      onSubmitted: (_) {
                        if (!isCommentReady) return;
                        if (!canWriteComment) {
                          onLockedTap();
                          return;
                        }
                        onSubmit();
                      },
                      decoration: InputDecoration(
                        hintText: hintText,
                        hintStyle: TextStyle(
                          color: canWriteComment
                              ? kCommentHint
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
                        color: canWriteComment
                            ? kCommentText
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
                  final enabled =
                      !isSubmitting.value && isCommentReady && canWriteComment;

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
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:yupgagae/core/auth/auth_controller.dart';
import 'package:yupgagae/core/auth/permission_policy.dart';
import 'package:yupgagae/core/ui/app_toast.dart';
import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/domain/post_repository.dart';
import 'package:yupgagae/features/community/view/open_post_detail.dart';

class AdminReportedPostsScreen extends StatefulWidget {
  const AdminReportedPostsScreen({super.key});

  @override
  State<AdminReportedPostsScreen> createState() =>
      _AdminReportedPostsScreenState();
}

class _AdminReportedPostsScreenState extends State<AdminReportedPostsScreen> {
  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kPrimarySoft = Color(0xFFF6EEEA);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  bool _isLoading = true;
  bool _isActionRunning = false;
  String? _error;
  List<Post> _reportedPosts = <Post>[];

  AuthController? _findAuthControllerOrNull() {
    if (!Get.isRegistered<AuthController>()) return null;
    return Get.find<AuthController>();
  }

  PostRepository? _findPostRepositoryOrNull() {
    if (!Get.isRegistered<PostRepository>()) return null;
    return Get.find<PostRepository>();
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _load();
    });
  }

  Future<void> _load() async {
    final repo = _findPostRepositoryOrNull();

    if (repo == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = '게시글 저장소를 찾을 수 없습니다.';
        _reportedPosts = <Post>[];
      });
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final reported = await repo.fetchReportedPosts();

      if (!mounted) return;

      setState(() {
        _reportedPosts = reported;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _reportedPosts = <Post>[];
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _openPost(Post post) async {
    try {
      final result = await openPostDetail<bool>(post.id);
      if (result == true) {
        await _load();
      }
    } catch (e) {
      AppToast.show('$e', title: '게시글 열기 실패', isError: true);
    }
  }

  Future<void> _hidePostByAdmin(Post post) async {
    if (_isActionRunning) return;
    if (post.isRemovedByAdmin) {
      AppToast.show('이미 관리자 제거 처리된 게시글입니다.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '관리자 숨김 처리',
      message: '이 게시글을 관리자 숨김 처리할까요?\n\n'
          '주요 신고 사유: ${post.displayHiddenReason}\n\n'
          '관리자 숨김 처리된 글은 일반 피드/상세에서 가려지고, 관리자 목록에는 계속 남습니다.',
      confirmText: '숨김',
      isDanger: true,
    );

    if (!confirmed) return;

    final repo = _findPostRepositoryOrNull();
    if (repo == null) {
      AppToast.show('게시글 저장소를 찾을 수 없습니다.', isError: true);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isActionRunning = true;
        });
      }

      await repo.hidePostByAdmin(postId: post.id);
      await _load();

      AppToast.show('관리자 숨김 처리했습니다.');
    } catch (e) {
      AppToast.show('$e', title: '관리자 숨김 실패', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isActionRunning = false;
      });
    }
  }

  Future<void> _unhidePostByAdmin(Post post) async {
    if (_isActionRunning) return;
    if (post.isRemovedByAdmin) {
      AppToast.show('관리자 제거 처리된 게시글은 숨김 해제할 수 없습니다.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '관리자 숨김 해제',
      message: post.isReportThresholdReached
          ? '관리자 숨김만 해제합니다.\n\n'
              '단, 이 글은 자동 블라인드 상태라 일반 유저에게는 계속 가려집니다.\n\n'
              '주요 신고 사유: ${post.displayHiddenReason}'
          : '관리자 숨김을 해제하고 일반 노출 가능 상태로 되돌립니다.\n\n'
              '주요 신고 사유: ${post.displayHiddenReason}',
      confirmText: '해제',
      isDanger: false,
    );

    if (!confirmed) return;

    final repo = _findPostRepositoryOrNull();
    if (repo == null) {
      AppToast.show('게시글 저장소를 찾을 수 없습니다.', isError: true);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isActionRunning = true;
        });
      }

      await repo.unhidePostByAdmin(postId: post.id);
      await _load();

      AppToast.show('관리자 숨김을 해제했습니다.');
    } catch (e) {
      AppToast.show('$e', title: '관리자 숨김 해제 실패', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isActionRunning = false;
      });
    }
  }

  Future<void> _clearPostReportThresholdByAdmin(Post post) async {
    if (_isActionRunning) return;
    if (post.isRemovedByAdmin) {
      AppToast.show('관리자 제거 처리된 게시글은 자동 블라인드를 해제할 수 없습니다.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '자동 블라인드 해제',
      message: post.isHiddenByAdmin
          ? '자동 블라인드만 해제합니다.\n\n'
              '단, 이 글은 관리자 숨김 상태라 일반 유저에게는 계속 가려집니다.\n\n'
              '주요 신고 사유: ${post.displayHiddenReason}'
          : '신고 기록은 유지하고 자동 블라인드 상태만 해제합니다.\n'
              '문제없는 글이라고 판단했을 때만 진행하세요.\n\n'
              '주요 신고 사유: ${post.displayHiddenReason}',
      confirmText: '해제',
      isDanger: false,
    );

    if (!confirmed) return;

    final repo = _findPostRepositoryOrNull();
    if (repo == null) {
      AppToast.show('게시글 저장소를 찾을 수 없습니다.', isError: true);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isActionRunning = true;
        });
      }

      await repo.clearPostReportThresholdByAdmin(postId: post.id);
      await _load();

      AppToast.show('자동 블라인드를 해제했습니다.');
    } catch (e) {
      AppToast.show('$e', title: '자동 블라인드 해제 실패', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isActionRunning = false;
      });
    }
  }

  Future<void> _removePostByAdmin(Post post) async {
    if (_isActionRunning) return;
    if (post.isRemovedByAdmin) {
      AppToast.show('이미 관리자 제거 처리된 게시글입니다.', isError: true);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: '게시글 관리자 제거',
      message: '이 게시글을 관리자 제거 처리할까요?\n\n'
          '제거 사유: ${post.displayRemovedReason}\n\n'
          '일반 유저에게는 보이지 않고, 관리자 목록과 admin_actions 기록에는 남습니다.\n'
          '명백한 위반, 개인정보 노출, 심각한 운영정책 위반일 때만 사용하세요.',
      confirmText: '제거',
      isDanger: true,
    );

    if (!confirmed) return;

    final repo = _findPostRepositoryOrNull();
    if (repo == null) {
      AppToast.show('게시글 저장소를 찾을 수 없습니다.', isError: true);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isActionRunning = true;
        });
      }

      await repo.removePostByAdmin(postId: post.id);
      await _load();

      AppToast.show('게시글을 관리자 제거 처리했습니다.');
    } catch (e) {
      AppToast.show('$e', title: '관리자 제거 실패', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isActionRunning = false;
      });
    }
  }

  Future<void> _sanctionPostAuthor(Post post) async {
    if (_isActionRunning) return;

    final authorId = post.authorId.trim();
    final authorLabel =
        post.authorLabel.trim().isEmpty ? '익명' : post.authorLabel.trim();

    if (authorId.isEmpty) {
      AppToast.show('제재할 작성자를 찾을 수 없습니다.', isError: true);
      return;
    }

    final input = await _showSanctionSheet(
      targetLabel: authorLabel,
      targetTypeLabel: '게시글 작성자',
      defaultReason: post.displayHiddenReason,
    );

    if (input == null) return;

    final repo = _findPostRepositoryOrNull();
    if (repo == null) {
      AppToast.show('게시글 저장소를 찾을 수 없습니다.', isError: true);
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isActionRunning = true;
        });
      }

      await repo.sanctionUserByAdmin(
        userId: authorId,
        sanctionType: input.type,
        reason: input.reason,
      );

      await _load();

      AppToast.show('${input.type.label} 처리했습니다.');
    } catch (e) {
      AppToast.show('$e', title: '작성자 제재 실패', isError: true);
    } finally {
      if (!mounted) return;
      setState(() {
        _isActionRunning = false;
      });
    }
  }

  Future<_AdminSanctionInput?> _showSanctionSheet({
    required String targetLabel,
    required String targetTypeLabel,
    required String defaultReason,
  }) async {
    final result = await showModalBottomSheet<_AdminSanctionInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _AdminSanctionSheet(
          targetLabel: targetLabel,
          targetTypeLabel: targetTypeLabel,
          defaultReason: defaultReason,
        );
      },
    );

    return result;
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
    required String confirmText,
    required bool isDanger,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          title: Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: _kTextStrong,
              letterSpacing: -0.3,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: _kTextNormal,
              height: 1.5,
              letterSpacing: -0.15,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                '취소',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF8A817C),
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                confirmText,
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color: isDanger ? const Color(0xFFE11D48) : _kPrimary,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  String _boardLabel(Post post) {
    switch (post.boardType) {
      case BoardType.free:
        return '자유게시판';
      case BoardType.owner:
        return '사장님게시판';
      case BoardType.used:
        switch (post.usedType) {
          case UsedPostType.store:
            return '가게양도';
          case UsedPostType.item:
            return '중고거래';
          case null:
            return '거래글';
        }
    }
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);

    if (diff.inMinutes < 1) return '방금';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  }

  String _nullableTimeLabel(DateTime? dt) {
    if (dt == null) return '시간 기록 없음';
    return _timeLabel(dt);
  }

  @override
  Widget build(BuildContext context) {
    final auth = _findAuthControllerOrNull();

    if (auth == null) {
      return const _AdminReportedPostsAccessDeniedScreen(
        message: '계정 정보를 확인할 수 없습니다.',
      );
    }

    return Obx(() {
      final initialized = auth.isInitialized.value;
      final user = auth.currentUser.value;

      if (!initialized) {
        return const Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      }

      if (!PermissionPolicy.canAccessAdmin(user)) {
        return const _AdminReportedPostsAccessDeniedScreen(
          message: '관리자 권한이 있는 계정만 접근할 수 있습니다.',
        );
      }

      return Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              elevation: 0,
              centerTitle: true,
              title: const Text(
                '신고된 게시글',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: _kTextStrong,
                  letterSpacing: -0.3,
                ),
              ),
              leading: IconButton(
                onPressed: Get.back,
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 19,
                  color: _kTextStrong,
                ),
              ),
              actions: [
                IconButton(
                  onPressed: _isLoading ? null : _load,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: _kTextStrong,
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: RefreshIndicator(
                color: _kPrimary,
                onRefresh: _load,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
                  children: [
                    const _AdminReportedPostsHeader(),
                    const SizedBox(height: 14),
                    _AdminReportedPostsSummary(
                      count: _reportedPosts.length,
                      totalReportCount: _reportedPosts.fold<int>(
                        0,
                        (sum, post) => sum + post.reportCount,
                      ),
                      thresholdHiddenCount: _reportedPosts.where((post) {
                        return post.isReportThresholdReached;
                      }).length,
                      adminHiddenCount: _reportedPosts.where((post) {
                        return post.isHiddenByAdmin;
                      }).length,
                      adminRemovedCount: _reportedPosts.where((post) {
                        return post.isRemovedByAdmin;
                      }).length,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 12),
                    if (_isLoading)
                      const _AdminReportedPostsLoading()
                    else if (_error != null)
                      _AdminReportedPostsMessage(
                        icon: Icons.error_outline_rounded,
                        message: '신고 게시글을 불러오지 못했습니다.\n$_error',
                      )
                    else if (_reportedPosts.isEmpty)
                      const _AdminReportedPostsMessage(
                        icon: Icons.check_circle_outline_rounded,
                        message: '현재 신고된 게시글이 없습니다.',
                      )
                    else
                      for (int i = 0; i < _reportedPosts.length; i++) ...[
                        _AdminReportedPostCard(
                          post: _reportedPosts[i],
                          boardLabel: _boardLabel(_reportedPosts[i]),
                          timeLabel: _timeLabel(_reportedPosts[i].createdAt),
                          adminHiddenTimeLabel: _nullableTimeLabel(
                            _reportedPosts[i].adminHiddenAt,
                          ),
                          adminRemovedTimeLabel: _nullableTimeLabel(
                            _reportedPosts[i].adminRemovedAt,
                          ),
                          isActionRunning: _isActionRunning,
                          onTap: () => _openPost(_reportedPosts[i]),
                          onHideByAdmin: () =>
                              _hidePostByAdmin(_reportedPosts[i]),
                          onUnhideByAdmin: () =>
                              _unhidePostByAdmin(_reportedPosts[i]),
                          onClearThreshold: () =>
                              _clearPostReportThresholdByAdmin(
                            _reportedPosts[i],
                          ),
                          onRemoveByAdmin: () =>
                              _removePostByAdmin(_reportedPosts[i]),
                          onSanctionAuthor: () =>
                              _sanctionPostAuthor(_reportedPosts[i]),
                        ),
                        if (i != _reportedPosts.length - 1)
                          const SizedBox(height: 10),
                      ],
                  ],
                ),
              ),
            ),
          ),
          if (_isActionRunning)
            const Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(
                  color: Color(0x11000000),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2.2),
                  ),
                ),
              ),
            ),
        ],
      );
    });
  }
}

class _AdminReportedPostsHeader extends StatelessWidget {
  const _AdminReportedPostsHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EEEA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE7E3)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.report_problem_outlined,
            size: 20,
            color: Color(0xFFA56E5F),
          ),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              '신고 접수 수와 사유별 누적 수를 확인합니다.\n자동 블라인드/관리자 숨김/관리자 제거 글도 관리자 목록에는 계속 표시됩니다.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4B5563),
                height: 1.45,
                letterSpacing: -0.15,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminReportedPostsSummary extends StatelessWidget {
  final int count;
  final int totalReportCount;
  final int thresholdHiddenCount;
  final int adminHiddenCount;
  final int adminRemovedCount;
  final bool isLoading;

  const _AdminReportedPostsSummary({
    required this.count,
    required this.totalReportCount,
    required this.thresholdHiddenCount,
    required this.adminHiddenCount,
    required this.adminRemovedCount,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final text = isLoading
        ? '불러오는 중'
        : '게시글 $count개 · 접수 $totalReportCount건 · 자동 $thresholdHiddenCount개 · 숨김 $adminHiddenCount개 · 제거 $adminRemovedCount개';

    return Row(
      children: [
        const Text(
          '목록',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w900,
            color: Color(0xFF8A817C),
            letterSpacing: -0.15,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA56E5F),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminReportedPostCard extends StatelessWidget {
  final Post post;
  final String boardLabel;
  final String timeLabel;
  final String adminHiddenTimeLabel;
  final String adminRemovedTimeLabel;
  final bool isActionRunning;
  final VoidCallback onTap;
  final VoidCallback onHideByAdmin;
  final VoidCallback onUnhideByAdmin;
  final VoidCallback onClearThreshold;
  final VoidCallback onRemoveByAdmin;
  final VoidCallback onSanctionAuthor;

  const _AdminReportedPostCard({
    required this.post,
    required this.boardLabel,
    required this.timeLabel,
    required this.adminHiddenTimeLabel,
    required this.adminRemovedTimeLabel,
    required this.isActionRunning,
    required this.onTap,
    required this.onHideByAdmin,
    required this.onUnhideByAdmin,
    required this.onClearThreshold,
    required this.onRemoveByAdmin,
    required this.onSanctionAuthor,
  });

  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  String get _bodyPreview {
    final body = post.body.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (body.isEmpty) return '본문 없음';
    if (body.length <= 80) return body;
    return '${body.substring(0, 80)}...';
  }

  Map<String, int> get _reasonCounts {
    if (post.reportReasonCounts.isNotEmpty) {
      final normalized = <String, int>{};

      post.reportReasonCounts.forEach((rawReason, rawCount) {
        final reason = rawReason.trim();
        if (reason.isEmpty) return;
        if (rawCount <= 0) return;

        normalized[reason] = (normalized[reason] ?? 0) + rawCount;
      });

      if (normalized.isNotEmpty) return normalized;
    }

    final fallback = <String, int>{};

    for (final raw in post.reportReasons) {
      final reason = raw.trim();
      if (reason.isEmpty) continue;

      fallback[reason] = (fallback[reason] ?? 0) + 1;
    }

    return fallback;
  }

  String get _reasonSummary {
    final counts = _reasonCounts;

    if (counts.isEmpty) {
      if (post.reportCount > 0) {
        return '사유 기록 없음 · 기존 신고 ${post.reportCount}건';
      }

      return '사유 기록 없음';
    }

    final entries = counts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        if (countCompare != 0) return countCompare;

        return a.key.compareTo(b.key);
      });

    return entries.map((e) => '${e.key} ${e.value}건').join(' · ');
  }

  Color get _borderColor {
    if (post.isRemovedByAdmin) return const Color(0xFF111827);
    if (post.isHiddenByAdmin) return const Color(0xFF7C3AED);
    if (post.isReportThresholdReached) return const Color(0xFFE11D48);
    return _kBorder;
  }

  @override
  Widget build(BuildContext context) {
    final isThresholdHidden = post.isReportThresholdReached;
    final isAdminHidden = post.isHiddenByAdmin;
    final isAdminRemoved = post.isRemovedByAdmin;
    final reasonCounts = _reasonCounts;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _AdminReportBadge(
                    text: '접수 ${post.reportCount}건',
                    backgroundColor: const Color(0xFFFFF1F2),
                    foregroundColor: const Color(0xFFE11D48),
                  ),
                  _AdminReportBadge(
                    text: '신고자 ${post.reportedUserIds.length}명',
                    backgroundColor: const Color(0xFFFFF7ED),
                    foregroundColor: const Color(0xFFEA580C),
                  ),
                  _AdminReportBadge(
                    text: boardLabel,
                    backgroundColor: const Color(0xFFF6EEEA),
                    foregroundColor: _kPrimary,
                  ),
                  if (isThresholdHidden)
                    const _AdminReportBadge(
                      text: '자동 블라인드',
                      backgroundColor: Color(0xFFF3F4F6),
                      foregroundColor: Color(0xFF6B7280),
                    ),
                  if (isAdminHidden)
                    const _AdminReportBadge(
                      text: '관리자 숨김',
                      backgroundColor: Color(0xFFF5F3FF),
                      foregroundColor: Color(0xFF7C3AED),
                    ),
                  if (isAdminRemoved)
                    const _AdminReportBadge(
                      text: '관리자 제거',
                      backgroundColor: Color(0xFFF3F4F6),
                      foregroundColor: Color(0xFF111827),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                post.title.trim().isEmpty ? '제목 없음' : post.title.trim(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: _kTextStrong,
                  height: 1.35,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _bodyPreview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextNormal,
                  height: 1.45,
                  letterSpacing: -0.1,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F3F5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '신고 사유',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                        color: _kTextSoft,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _reasonSummary,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: reasonCounts.isEmpty
                            ? const Color(0xFF9CA3AF)
                            : _kTextNormal,
                        height: 1.45,
                        letterSpacing: -0.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '주요 신고 사유: ${post.displayHiddenReason}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFA56E5F),
                        height: 1.4,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdminHidden) ...[
                const SizedBox(height: 8),
                _AdminStateBox(
                  title: '관리자 숨김 처리',
                  message:
                      '주요 신고 사유: ${post.displayHiddenReason} · $adminHiddenTimeLabel',
                  backgroundColor: const Color(0xFFF5F3FF),
                  borderColor: const Color(0xFFEDE9FE),
                  titleColor: const Color(0xFF7C3AED),
                ),
              ],
              if (isAdminRemoved) ...[
                const SizedBox(height: 8),
                _AdminStateBox(
                  title: '관리자 제거 처리',
                  message:
                      '제거 사유: ${post.displayRemovedReason} · $adminRemovedTimeLabel',
                  backgroundColor: const Color(0xFFF3F4F6),
                  borderColor: const Color(0xFFE5E7EB),
                  titleColor: const Color(0xFF111827),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${post.authorLabel} · $timeLabel',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextSoft,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFB0B8C1),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _AdminPostActionArea(
                isActionRunning: isActionRunning,
                isThresholdHidden: isThresholdHidden,
                isAdminHidden: isAdminHidden,
                isAdminRemoved: isAdminRemoved,
                onHideByAdmin: onHideByAdmin,
                onUnhideByAdmin: onUnhideByAdmin,
                onClearThreshold: onClearThreshold,
                onRemoveByAdmin: onRemoveByAdmin,
                onSanctionAuthor: onSanctionAuthor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminStateBox extends StatelessWidget {
  final String title;
  final String message;
  final Color backgroundColor;
  final Color borderColor;
  final Color titleColor;

  const _AdminStateBox({
    required this.title,
    required this.message,
    required this.backgroundColor,
    required this.borderColor,
    required this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              color: titleColor,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            message,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: _AdminReportedPostsScreenState._kTextNormal,
              height: 1.45,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPostActionArea extends StatelessWidget {
  final bool isActionRunning;
  final bool isThresholdHidden;
  final bool isAdminHidden;
  final bool isAdminRemoved;
  final VoidCallback onHideByAdmin;
  final VoidCallback onUnhideByAdmin;
  final VoidCallback onClearThreshold;
  final VoidCallback onRemoveByAdmin;
  final VoidCallback onSanctionAuthor;

  const _AdminPostActionArea({
    required this.isActionRunning,
    required this.isThresholdHidden,
    required this.isAdminHidden,
    required this.isAdminRemoved,
    required this.onHideByAdmin,
    required this.onUnhideByAdmin,
    required this.onClearThreshold,
    required this.onRemoveByAdmin,
    required this.onSanctionAuthor,
  });

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[];

    if (!isAdminRemoved) {
      if (isAdminHidden) {
        buttons.add(
          _AdminActionButton(
            text: '관리자 숨김 해제',
            icon: Icons.visibility_outlined,
            foregroundColor: const Color(0xFFA56E5F),
            backgroundColor: const Color(0xFFF6EEEA),
            borderColor: const Color(0xFFEDE7E3),
            onPressed: isActionRunning ? null : onUnhideByAdmin,
          ),
        );
      } else {
        buttons.add(
          _AdminActionButton(
            text: '관리자 숨김',
            icon: Icons.visibility_off_outlined,
            foregroundColor: const Color(0xFFE11D48),
            backgroundColor: const Color(0xFFFFF1F2),
            borderColor: const Color(0xFFFFCCD5),
            onPressed: isActionRunning ? null : onHideByAdmin,
          ),
        );
      }

      if (isThresholdHidden) {
        buttons.add(
          _AdminActionButton(
            text: '자동 블라인드 해제',
            icon: Icons.lock_open_rounded,
            foregroundColor: const Color(0xFF2563EB),
            backgroundColor: const Color(0xFFEFF6FF),
            borderColor: const Color(0xFFDBEAFE),
            onPressed: isActionRunning ? null : onClearThreshold,
          ),
        );
      }

      buttons.add(
        _AdminActionButton(
          text: '관리자 제거',
          icon: Icons.delete_forever_outlined,
          foregroundColor: const Color(0xFF111827),
          backgroundColor: const Color(0xFFF3F4F6),
          borderColor: const Color(0xFFE5E7EB),
          onPressed: isActionRunning ? null : onRemoveByAdmin,
        ),
      );
    }

    buttons.add(
      _AdminActionButton(
        text: '작성자 제재',
        icon: Icons.gavel_rounded,
        foregroundColor: const Color(0xFFE11D48),
        backgroundColor: const Color(0xFFFFF1F2),
        borderColor: const Color(0xFFFFCCD5),
        onPressed: isActionRunning ? null : onSanctionAuthor,
      ),
    );

    if (isAdminRemoved) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _AdminRemovedNotice(),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: buttons,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }
}

class _AdminRemovedNotice extends StatelessWidget {
  const _AdminRemovedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 15,
            color: Color(0xFF6B7280),
          ),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              '관리자 제거 처리된 게시글입니다. 추가 조치는 Firebase Console 또는 admin_actions 기록에서 확인하세요.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF6B7280),
                height: 1.4,
                letterSpacing: -0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback? onPressed;

  const _AdminActionButton({
    required this.text,
    required this.icon,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;

    return Material(
      color: disabled ? const Color(0xFFF3F4F6) : backgroundColor,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: disabled ? const Color(0xFFE5E7EB) : borderColor,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: disabled ? const Color(0xFF9CA3AF) : foregroundColor,
              ),
              const SizedBox(width: 5),
              Text(
                text,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: disabled ? const Color(0xFF9CA3AF) : foregroundColor,
                  letterSpacing: -0.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminReportBadge extends StatelessWidget {
  final String text;
  final Color backgroundColor;
  final Color foregroundColor;

  const _AdminReportBadge({
    required this.text,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
          color: foregroundColor,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _AdminReportedPostsLoading extends StatelessWidget {
  const _AdminReportedPostsLoading();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: CircularProgressIndicator(strokeWidth: 2.2),
      ),
    );
  }
}

class _AdminReportedPostsMessage extends StatelessWidget {
  final IconData icon;
  final String message;

  const _AdminReportedPostsMessage({
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEDE7E3)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 34,
            color: const Color(0xFFA56E5F),
          ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B5563),
              height: 1.5,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminSanctionInput {
  final AdminUserSanctionType type;
  final String reason;

  const _AdminSanctionInput({
    required this.type,
    required this.reason,
  });
}

class _AdminSanctionSheet extends StatefulWidget {
  final String targetLabel;
  final String targetTypeLabel;
  final String defaultReason;

  const _AdminSanctionSheet({
    required this.targetLabel,
    required this.targetTypeLabel,
    required this.defaultReason,
  });

  @override
  State<_AdminSanctionSheet> createState() => _AdminSanctionSheetState();
}

class _AdminSanctionSheetState extends State<_AdminSanctionSheet> {
  static const Color _kPrimary = Color(0xFFA56E5F);
  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);
  static const Color _kTextSoft = Color(0xFF8A817C);
  static const Color _kBorder = Color(0xFFEDE7E3);

  late final TextEditingController _reasonController;
  AdminUserSanctionType _selectedType = AdminUserSanctionType.warned;

  @override
  void initState() {
    super.initState();

    _reasonController = TextEditingController(
      text: widget.defaultReason.trim(),
    );
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _reasonController.text.trim();

    if (reason.isEmpty) {
      AppToast.show('제재 사유를 입력하세요.', isError: true);
      return;
    }

    Navigator.of(context).pop(
      _AdminSanctionInput(
        type: _selectedType,
        reason: reason,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  '작성자 제재',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: _kTextStrong,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${widget.targetTypeLabel} · ${widget.targetLabel}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _kTextSoft,
                    height: 1.35,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  '제재 유형',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _kTextStrong,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AdminUserSanctionType.values.map((type) {
                    final selected = _selectedType == type;

                    return _AdminSanctionChoiceChip(
                      label: type.label,
                      selected: selected,
                      isDestructive: type.isDestructive,
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                        });
                      },
                    );
                  }).toList(growable: false),
                ),
                const SizedBox(height: 16),
                const Text(
                  '제재 사유',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: _kTextStrong,
                    letterSpacing: -0.15,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _reasonController,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 60,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: '예: 욕설, 개인정보 노출, 반복 신고',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB0B8C1),
                    ),
                    counterStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _kTextSoft,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    contentPadding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: _kPrimary,
                        width: 1.2,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextNormal,
                    height: 1.4,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '처리 후 유저 문서와 제재 이력에 기록됩니다.\n정지 기간 중에는 글쓰기, 댓글, 좋아요, 신고가 제한됩니다.',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _kTextSoft,
                    height: 1.45,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _AdminSanctionBottomButton(
                        text: '취소',
                        foregroundColor: _kTextSoft,
                        backgroundColor: const Color(0xFFF3F4F6),
                        borderColor: const Color(0xFFE5E7EB),
                        onTap: () => Navigator.of(context).pop(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AdminSanctionBottomButton(
                        text: _selectedType.label,
                        foregroundColor: _selectedType.isDestructive
                            ? const Color(0xFFE11D48)
                            : _kPrimary,
                        backgroundColor: _selectedType.isDestructive
                            ? const Color(0xFFFFF1F2)
                            : const Color(0xFFF6EEEA),
                        borderColor: _selectedType.isDestructive
                            ? const Color(0xFFFFCCD5)
                            : _kBorder,
                        onTap: _submit,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSanctionChoiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool isDestructive;
  final VoidCallback onTap;

  const _AdminSanctionChoiceChip({
    required this.label,
    required this.selected,
    required this.isDestructive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foregroundColor =
        isDestructive ? const Color(0xFFE11D48) : const Color(0xFFA56E5F);

    return Material(
      color: selected
          ? (isDestructive ? const Color(0xFFFFF1F2) : const Color(0xFFF6EEEA))
          : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? foregroundColor : const Color(0xFFE5E7EB),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              color: selected ? foregroundColor : const Color(0xFF6B7280),
              letterSpacing: -0.1,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminSanctionBottomButton extends StatelessWidget {
  final String text;
  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
  final VoidCallback onTap;

  const _AdminSanctionBottomButton({
    required this.text,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashFactory: NoSplash.splashFactory,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: foregroundColor,
              letterSpacing: -0.15,
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminReportedPostsAccessDeniedScreen extends StatelessWidget {
  final String message;

  const _AdminReportedPostsAccessDeniedScreen({
    required this.message,
  });

  static const Color _kTextStrong = Color(0xFF25211F);
  static const Color _kTextNormal = Color(0xFF4B5563);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          '신고된 게시글',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            color: _kTextStrong,
            letterSpacing: -0.3,
          ),
        ),
        leading: IconButton(
          onPressed: Get.back,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: _kTextStrong,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: _kTextNormal,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
import 'dart:io';

import 'package:flutter/material.dart';

import 'package:yupgagae/features/community/domain/post.dart';
import 'package:yupgagae/features/community/view/widgets/author_meta_line.dart';

class PostDetailContentSection extends StatefulWidget {
  final Post post;
  final String timeLabel;
  final bool liked;
  final Color likeColor;
  final VoidCallback onLikeTap;
  final VoidCallback onCommentTap;

  const PostDetailContentSection({
    super.key,
    required this.post,
    required this.timeLabel,
    required this.liked,
    required this.likeColor,
    required this.onLikeTap,
    required this.onCommentTap,
  });

  @override
  State<PostDetailContentSection> createState() =>
      _PostDetailContentSectionState();
}

class _PostDetailContentSectionState extends State<PostDetailContentSection> {
  List<String> _lastPrecachedPaths = const [];
  bool _didSchedulePrecache = false;

  List<String> get _safeImagePaths {
    return widget.post.imagePaths
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _schedulePrecache();
  }

  @override
  void didUpdateWidget(covariant PostDetailContentSection oldWidget) {
    super.didUpdateWidget(oldWidget);

    final before = oldWidget.post.imagePaths.map((e) => e.trim()).toList();
    final after = widget.post.imagePaths.map((e) => e.trim()).toList();

    if (!_sameStringList(before, after)) {
      _didSchedulePrecache = false;
      _schedulePrecache();
    }
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _schedulePrecache() {
    if (_didSchedulePrecache) return;
    _didSchedulePrecache = true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      // 첫 프레임 안정화 후 프리캐시 시작
      await Future<void>.delayed(const Duration(milliseconds: 220));
      if (!mounted) return;

      await _precachePostImages();
    });
  }

  Future<void> _precachePostImages() async {
    if (!mounted) return;

    final paths = _safeImagePaths;
    if (paths.isEmpty) return;
    if (_sameStringList(paths, _lastPrecachedPaths)) return;

    _lastPrecachedPaths = List<String>.from(paths);

    for (var i = 0; i < paths.length; i++) {
      if (!mounted) return;

      final safePath = paths[i].trim();
      if (safePath.isEmpty) continue;

      final file = File(safePath);
      if (!file.existsSync()) continue;

      final provider = ResizeImage(
        FileImage(file),
        width: 1200,
      );

      try {
        if (i == 0) {
          // 첫 이미지는 화면 진입 체감에 영향이 커서 우선 준비
          await precacheImage(provider, context);
        } else {
          // 나머지는 한 박자씩 나눠서 준비
          await Future<void>.delayed(const Duration(milliseconds: 24));
          await precacheImage(provider, context);
        }
      } catch (_) {
        // 프리캐시 실패는 렌더 단계 errorBuilder에서 처리
      }
    }
  }

  String _usedPrefix() {
    if (widget.post.boardType != BoardType.used ||
        widget.post.usedType == null) {
      return '';
    }

    switch (widget.post.usedType!) {
      case UsedPostType.store:
        return '[가게양도]';
      case UsedPostType.item:
        return '[중고거래]';
    }
  }

  InlineSpan _buildStyledTitle(String baseTitle) {
    final spans = <InlineSpan>[];

    final usedPrefix = _usedPrefix();
    if (usedPrefix.isNotEmpty) {
      spans.add(
        TextSpan(
          text: '$usedPrefix ',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            height: 1.34,
            letterSpacing: -0.2,
            color: Color(0xFFA56E5F),
          ),
        ),
      );
    }

    spans.add(
      TextSpan(
        text: baseTitle,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          height: 1.34,
          letterSpacing: -0.2,
          color: Color(0xFF111111),
        ),
      ),
    );

    return TextSpan(children: spans);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.post.title.trim().isEmpty
        ? '(제목 없음)'
        : widget.post.title.trim();
    final body = widget.post.body.trim();
    final imagePaths = _safeImagePaths;

    return RepaintBoundary(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthorMetaLine(
              industryId: widget.post.industryId,
              locationLabel: widget.post.locationLabel,
              nicknameLabel: widget.post.authorLabel,
              timeLabel: widget.timeLabel,
              isOwnerVerified: widget.post.isOwnerVerified,
            ),
            const SizedBox(height: 14),
            Text.rich(
              _buildStyledTitle(title),
            ),
            const SizedBox(height: 16),
            if (imagePaths.isNotEmpty) ...[
              _PostImagesStacked(paths: imagePaths),
              const SizedBox(height: 18),
            ],
            if (body.isNotEmpty)
              Text(
                body,
                style: const TextStyle(
                  fontSize: 15.5,
                  height: 1.74,
                  color: Color(0xFF1F2937),
                  fontWeight: FontWeight.w500,
                ),
              ),
            const SizedBox(height: 20),
            const Divider(height: 1, color: Color(0xFFF3F4F6)),
            const SizedBox(height: 12),
            Row(
              children: [
                _ActionTextButton(
                  icon: widget.liked ? Icons.favorite : Icons.favorite_border,
                  label: '좋아요 ${widget.post.likeCount}',
                  color: widget.likeColor,
                  onTap: widget.onLikeTap,
                ),
                const SizedBox(width: 14),
                _ActionTextButton(
                  icon: Icons.mode_comment_outlined,
                  label: '댓글 ${widget.post.commentCount}',
                  color: const Color(0xFF6B7280),
                  onTap: widget.onCommentTap,
                ),
                const Spacer(),
                const Icon(
                  Icons.remove_red_eye_outlined,
                  size: 16,
                  color: Color(0xFF9CA3AF),
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.post.viewCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PostImagesStacked extends StatelessWidget {
  final List<String> paths;

  const _PostImagesStacked({
    required this.paths,
  });

  @override
  Widget build(BuildContext context) {
    if (paths.isEmpty) return const SizedBox.shrink();

    return Column(
      children: List.generate(paths.length, (i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == paths.length - 1 ? 0 : 10),
          child: _PostImageCard(path: paths[i]),
        );
      }),
    );
  }
}

class _PostImageCard extends StatelessWidget {
  final String path;

  const _PostImageCard({
    required this.path,
  });

  ImageProvider _buildProvider(File file) {
    return ResizeImage(
      FileImage(file),
      width: 1200,
    );
  }

  @override
  Widget build(BuildContext context) {
    final safePath = path.trim();

    if (safePath.isEmpty) {
      return const _PostImageErrorBox();
    }

    final file = File(safePath);
    if (!file.existsSync()) {
      return const _PostImageErrorBox();
    }

    final provider = _buildProvider(file);

    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: AspectRatio(
          aspectRatio: 16 / 10,
          child: ColoredBox(
            color: const Color(0xFFF3F4F6),
            child: Image(
              image: provider,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.low,
              gaplessPlayback: true,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded || frame != null) {
                  return child;
                }

                return const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (_, __, ___) {
                return const _PostImageErrorBox();
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PostImageErrorBox extends StatelessWidget {
  const _PostImageErrorBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_not_supported_outlined,
        color: Color(0xFF9CA3AF),
      ),
    );
  }
}

class _ActionTextButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _ActionTextButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 17, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
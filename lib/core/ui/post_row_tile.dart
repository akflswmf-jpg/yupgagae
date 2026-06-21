import 'package:flutter/material.dart';

import 'package:yupgagae/features/community/domain/post.dart';

class PostRowTile extends StatelessWidget {
  final Post post;
  final bool liked;
  final VoidCallback onTap;
  final Future<void> Function() onLike;

  /// 사장님게시판 미인증 사용자용.
  /// true면 사진 여부 등 본문/이미지 힌트를 숨긴다.
  final bool obscureOwnerContent;

  const PostRowTile({
    super.key,
    required this.post,
    required this.liked,
    required this.onTap,
    required this.onLike,
    this.obscureOwnerContent = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = post.imagePaths.isNotEmpty && !obscureOwnerContent;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title.trim().isEmpty ? '(제목 없음)' : post.title.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _MetaText('조회 ${post.viewCount}'),
                      const SizedBox(width: 10),
                      _MetaText('좋아요 ${post.likeCount}'),
                      const SizedBox(width: 10),
                      _MetaText('댓글 ${post.commentCount}'),
                      const SizedBox(width: 10),
                      _MetaText(post.authorLabel.trim().isEmpty
                          ? '익명'
                          : post.authorLabel.trim()),
                      if (hasPhoto) ...[
                        const SizedBox(width: 10),
                        const _MetaText('📷'),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () async {
                await onLike();
              },
              icon: Icon(liked ? Icons.favorite : Icons.favorite_border),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final String text;

  const _MetaText(this.text);

  @override
  Widget build(BuildContext context) {
    return Flexible(
      fit: FlexFit.loose,
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
    );
  }
}
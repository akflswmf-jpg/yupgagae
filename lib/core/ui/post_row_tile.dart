import 'package:flutter/material.dart';

import 'package:yupgagae/features/community/domain/post.dart';

class PostRowTile extends StatelessWidget {
  final Post post;
  final bool liked;
  final VoidCallback onTap;
  final Future<void> Function() onLike;

  const PostRowTile({
    super.key,
    required this.post,
    required this.liked,
    required this.onTap,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = post.imagePaths.isNotEmpty;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ✅ 메인 텍스트 영역
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 제목
                  Text(
                    post.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // 한 줄 메타: 조회/좋아요/댓글/닉네임/사진여부
                  Row(
                    children: [
                      _MetaText('조회 ${post.viewCount}'),
                      const SizedBox(width: 10),
                      _MetaText('좋아요 ${post.likeCount}'),
                      const SizedBox(width: 10),
                      _MetaText('댓글 ${post.commentCount}'),
                      const SizedBox(width: 10),
                      _MetaText('익명'),
                      const SizedBox(width: 10),
                      if (hasPhoto) const _MetaText('📷'),
                    ],
                  ),
                ],
              ),
            ),

            // 좋아요 버튼
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
    return Text(
      text,
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }
}
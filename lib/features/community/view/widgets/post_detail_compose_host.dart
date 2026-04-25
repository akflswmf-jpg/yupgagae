import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'package:yupgagae/features/community/controller/comment_controller.dart';
import 'package:yupgagae/features/community/view/widgets/post_detail_compose_section.dart';

class PostDetailComposeHost extends StatelessWidget {
  final CommentController commentC;
  final double safeBottom;
  final TextEditingController textController;
  final FocusNode focusNode;
  final List<TextInputFormatter> inputFormatters;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;

  const PostDetailComposeHost({
    super.key,
    required this.commentC,
    required this.safeBottom,
    required this.textController,
    required this.focusNode,
    required this.inputFormatters,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      return PostDetailComposeSection(
        safeBottom: safeBottom,

        // 현재 댓글 입력 구조는 상세 하단 입력바 중심이라
        // CommentController에 activeEditingId / activeReplyTo 상태를 두지 않는다.
        editingId: null,
        replyTo: null,

        onCancelComposeMode: onCancel,
        textController: textController,
        focusNode: focusNode,
        inputFormatters: inputFormatters,
        submitting: commentC.isSubmitting.value,
        onSubmitComment: onSubmit,
      );
    });
  }
}
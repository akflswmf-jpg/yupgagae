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
        editingId: commentC.activeEditingId,
        replyTo: commentC.activeReplyTo,
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
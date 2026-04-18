import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:yupgagae/features/revenue/view/revenue_theme_tokens.dart';

class PostDetailComposeSection extends StatelessWidget {
  final double safeBottom;
  final String? editingId;
  final String? replyTo;
  final VoidCallback onCancelComposeMode;
  final TextEditingController textController;
  final FocusNode focusNode;
  final List<TextInputFormatter> inputFormatters;
  final bool submitting;
  final VoidCallback onSubmitComment;

  const PostDetailComposeSection({
    super.key,
    required this.safeBottom,
    required this.editingId,
    required this.replyTo,
    required this.onCancelComposeMode,
    required this.textController,
    required this.focusNode,
    required this.inputFormatters,
    required this.submitting,
    required this.onSubmitComment,
  });

  bool get _isComposeMode => editingId != null || replyTo != null;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return RepaintBoundary(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.only(bottom: keyboardInset),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(
              top: BorderSide(color: Color(0xFFF1F3F5)),
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12,
              10,
              12,
              math.max(10, safeBottom),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeOutCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1,
                    child: child,
                  ),
                );
              },
              child: submitting
                  ? const _SubmittingPanel(key: ValueKey('submitting'))
                  : _ComposePanel(
                      key: const ValueKey('compose'),
                      isComposeMode: _isComposeMode,
                      editingId: editingId,
                      replyTo: replyTo,
                      onCancelComposeMode: onCancelComposeMode,
                      textController: textController,
                      focusNode: focusNode,
                      inputFormatters: inputFormatters,
                      onSubmitComment: onSubmitComment,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposePanel extends StatelessWidget {
  final bool isComposeMode;
  final String? editingId;
  final String? replyTo;
  final VoidCallback onCancelComposeMode;
  final TextEditingController textController;
  final FocusNode focusNode;
  final List<TextInputFormatter> inputFormatters;
  final VoidCallback onSubmitComment;

  const _ComposePanel({
    super.key,
    required this.isComposeMode,
    required this.editingId,
    required this.replyTo,
    required this.onCancelComposeMode,
    required this.textController,
    required this.focusNode,
    required this.inputFormatters,
    required this.onSubmitComment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isComposeMode)
          _ComposeModeBanner(
            editingId: editingId,
            onCancelComposeMode: onCancelComposeMode,
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: _ComposeInputBox(
                textController: textController,
                focusNode: focusNode,
                inputFormatters: inputFormatters,
                editingId: editingId,
                replyTo: replyTo,
              ),
            ),
            const SizedBox(width: 8),
            _SubmitButton(
              onSubmitComment: onSubmitComment,
            ),
          ],
        ),
      ],
    );
  }
}

class _ComposeModeBanner extends StatelessWidget {
  final String? editingId;
  final VoidCallback onCancelComposeMode;

  const _ComposeModeBanner({
    required this.editingId,
    required this.onCancelComposeMode,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          Icon(
            editingId != null
                ? Icons.edit_outlined
                : Icons.subdirectory_arrow_right_rounded,
            size: 16,
            color: const Color(0xFF6B7280),
          ),
          const SizedBox(width: 6),
          Text(
            editingId != null ? '댓글 수정 중' : '답글 작성 중',
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: onCancelComposeMode,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              '취소',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposeInputBox extends StatelessWidget {
  final TextEditingController textController;
  final FocusNode focusNode;
  final List<TextInputFormatter> inputFormatters;
  final String? editingId;
  final String? replyTo;

  const _ComposeInputBox({
    required this.textController,
    required this.focusNode,
    required this.inputFormatters,
    required this.editingId,
    required this.replyTo,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: TextField(
        controller: textController,
        focusNode: focusNode,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.newline,
        inputFormatters: inputFormatters,
        scrollPadding: EdgeInsets.zero,
        enableSuggestions: true,
        autocorrect: true,
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        style: const TextStyle(
          fontSize: 14.5,
          color: Color(0xFF111111),
          height: 1.45,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.fromLTRB(
            14,
            12,
            14,
            12,
          ),
          hintText: editingId != null
              ? '내용을 수정하세요.'
              : (replyTo == null ? '댓글을 입력하세요.' : '답글을 입력하세요.'),
          hintStyle: const TextStyle(
            color: Color(0xFF9CA3AF),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final VoidCallback onSubmitComment;

  const _SubmitButton({
    required this.onSubmitComment,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FilledButton(
        onPressed: onSubmitComment,
        style: FilledButton.styleFrom(
          backgroundColor: kRevenuePrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Icon(
          Icons.send_rounded,
          size: 20,
        ),
      ),
    );
  }
}

class _SubmittingPanel extends StatelessWidget {
  const _SubmittingPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE5E7EB),
        ),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(kRevenuePrimary),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '댓글을 등록하고 있어요...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          SizedBox(width: 8),
          Text(
            '잠시만요',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}